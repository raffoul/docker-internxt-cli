#!/bin/bash
set -e
echo "Starting local build workflow"

# Get Internxt CLI version
. scripts/internxt-cli.sh

# Build for local architecture only (no push)
echo "Building image locally: internxt-cli:${INTERNXT_CLI_VERSION}"
docker build \
    --build-arg INTERNXT_CLI_VERSION=${INTERNXT_CLI_VERSION} \
    -t internxt-cli:${INTERNXT_CLI_VERSION} \
    -t internxt-cli:latest \
    --pull .

echo ""
echo "Build completed successfully!"
echo "Images created:"
echo "  - internxt-cli:${INTERNXT_CLI_VERSION}"
echo "  - internxt-cli:latest"
