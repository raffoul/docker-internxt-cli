# Docker Internxt CLI Project

## Architecture Overview

This project wraps the official `@internxt/cli` npm package in a Docker container to provide WebDAV server functionality with automatic credential management. The container runs the Internxt CLI and monitors the WebDAV server health, auto-relogging when tokens expire.

**Key components:**
- `Dockerfile`: Node.js LTS base with npm-installed `@internxt/cli`
- `/scripts/dockerfile/`: Build-time scripts (dependencies, setup)
- `/scripts/dockerfile/files/`: Runtime scripts copied to container's `/scripts/`
- `/config`: Symlinked to `/root/.internxt-cli` for persistent auth tokens

## Critical Workflows

### Building Multi-Architecture Images

Build script: `scripts/start.sh`
```bash
# Initialize Docker buildx first
scripts/docker_initialize.sh

# Fetch latest @internxt/cli version
. scripts/internxt-cli.sh  # Sets INTERNXT_CLI_VERSION env var

# Build for linux/amd64,linux/arm64,linux/ppc64le,linux/s390x
# Main/master branch → tags: latest, ${INTERNXT_CLI_VERSION}
# Other branches → tags: ${BRANCH_NAME}-${INTERNXT_CLI_VERSION}
```

### Container Execution Modes

1. **Manual WebDAV** (`/scripts/webdav.sh`): Starts WebDAV server, monitors via PROPFIND requests every `WEBDAV_CHECK_INTERVAL` seconds. Exits if 3 consecutive health checks fail. Returns exit code 10 for 401 (auth expired), exit code 1 for other failures.

2. **Auto-Login WebDAV** (`/scripts/webdav_with_login.sh`): Wraps `webdav.sh` in loop. On exit code 10, runs `/scripts/login.sh` using env vars (`INTERNXT_USERNAME`, `INTERNXT_PASSWORD`, `INTERNXT_SECRET` for TOTP) and restarts WebDAV server.

## Project-Specific Conventions

### Script Organization Pattern
- **Build-time scripts** (run during `docker build`): `scripts/dockerfile/*.sh`
- **Runtime scripts** (available in running container): `scripts/dockerfile/files/*.sh` → copied to `/scripts/`
- All build scripts sourced by `scripts/dockerfile/build.sh` in sequence

### Exit Code Convention
- Exit 10: Auth token expired (401) - **recoverable** by auto-login
- Exit 1: Any other error - **non-recoverable**

This pattern enables `webdav_with_login.sh` to distinguish between auth failures vs. infrastructure failures.

### Configuration Reading Pattern
WebDAV scripts read `/config/config.webdav.inxt` JSON using `jq`:
```bash
PORT=$(jq -r '.port // empty' "$CONFIG_FILE")
PROTOCOL=$(jq -r '.protocol // empty' "$CONFIG_FILE")
```
Defaults: `PORT=3005`, `PROTOCOL=https`

### Health Check Implementation
Monitor uses combined HTTP + WebDAV status validation:
```bash
curl -s -k -w "%{http_code}" -X PROPFIND -H "Depth: 1" "$URL"
# Extract HTTP status from last 3 chars
# Extract WebDAV status from XML body via xmllint xpath
```
Both must return 2XX for healthy status.

## Key Dependencies

Runtime: `jq`, `libxml2-utils` (xmllint), `oathtool` (TOTP generation), `curl`
Installed via `scripts/dockerfile/apt-get.sh`

## Environment Variables

- `INTERNXT_CLI_VERSION`: Set by `scripts/internxt-cli.sh` (fetches latest from npm registry)
- `WEBDAV_CHECK_INTERVAL`/`WEBDAV_CHECK_TIMEOUT`: Health check timing (defaults: 60s/30s)
- `TZ`: Container timezone (default: Europe/Berlin)
- Credentials: `INTERNXT_USERNAME`, `INTERNXT_PASSWORD`, `INTERNXT_SECRET` (optional TOTP)

## Build Process Flow

1. `scripts/start.sh` → Initialize buildx + fetch CLI version
2. Docker build executes `scripts/dockerfile/build.sh`:
   - Install apt packages (`apt-get.sh`)
   - Configure timezone (`tzdata.sh`)
   - Install @internxt/cli via npm (`internxt-cli.sh`)
   - Copy runtime scripts from `/build/files/` to `/scripts/`
   - Clean up build artifacts (`cleanup.sh`)

## Jenkins CI/CD (disabled)

`disabled.Jenkinsfile` polls npm registry every 30min for new `@internxt/cli` versions via URLTrigger plugin. On change: builds multi-arch images, generates SBOM with Trivy, uploads to DependencyTrack.

**Note**: Jenkins features require agent labeled 'docker' with `DOCKER_USERNAME`, `DOCKER_API_PASSWORD` credentials.
