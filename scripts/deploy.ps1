# Deploy multi-architecture Docker images to GitHub Container Registry (ghcr.io)
param(
    [Parameter(Mandatory=$false)]
    [string]$GithubUsername = $env:GITHUB_USERNAME,
    
    [Parameter(Mandatory=$false)]
    [string]$GithubToken = $env:GITHUB_TOKEN,
    
    [Parameter(Mandatory=$false)]
    [string]$ImageName = "internxt-cli",
    
    [Parameter(Mandatory=$false)]
    [switch]$Test
)

Write-Host "Starting multi-architecture build and deployment workflow" -ForegroundColor Green
Write-Host "Target: GitHub Container Registry (ghcr.io)" -ForegroundColor Cyan

# Load .env file if exists
$envFile = Join-Path $PSScriptRoot "..\\.env"
if (Test-Path $envFile) {
    Write-Host "Loading credentials from .env file..." -ForegroundColor Gray
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^=]+)=(.+)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            if ([string]::IsNullOrEmpty((Get-Variable -Name "env:$name" -ValueOnly -ErrorAction SilentlyContinue))) {
                Set-Item -Path "env:$name" -Value $value
            }
        }
    }
    if ([string]::IsNullOrEmpty($GithubUsername)) { $GithubUsername = $env:GITHUB_USERNAME }
    if ([string]::IsNullOrEmpty($GithubToken)) { $GithubToken = $env:GITHUB_TOKEN }
}

# Check if GitHub username is provided
if ([string]::IsNullOrEmpty($GithubUsername)) {
    Write-Host "Please provide your GitHub username:" -ForegroundColor Yellow
    $GithubUsername = Read-Host "GitHub Username"
}

$GithubUsername = $GithubUsername.ToLower()

# Login to GitHub Container Registry
Write-Host "Logging in to ghcr.io as $GithubUsername..." -ForegroundColor Yellow

if ([string]::IsNullOrEmpty($GithubToken)) {
    Write-Host "You need a GitHub Personal Access Token (PAT) with 'write:packages' scope" -ForegroundColor Yellow
    Write-Host "Create one at: https://github.com/settings/tokens/new?scopes=write:packages" -ForegroundColor Gray
    docker login ghcr.io -u $GithubUsername
} else {
    Write-Host "Using token from environment..." -ForegroundColor Gray
    $GithubToken | docker login ghcr.io -u $GithubUsername --password-stdin
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "GitHub Container Registry login failed"
    exit 1
}

# Get Internxt CLI version from npm registry
Write-Host "Getting Internxt CLI version..." -ForegroundColor Yellow
$response = Invoke-RestMethod -Uri "https://registry.npmjs.org/@internxt/cli/latest"
$INTERNXT_CLI_VERSION = $response.version

if ([string]::IsNullOrEmpty($INTERNXT_CLI_VERSION)) {
    Write-Error "Error: INTERNXT_CLI_VERSION not detected"
    exit 1
}

Write-Host "Detected version: $INTERNXT_CLI_VERSION" -ForegroundColor Cyan

# Initialize buildx (create and use multi-platform builder)
Write-Host "Initializing Docker buildx..." -ForegroundColor Yellow

# Try to create builder (may already exist)
docker buildx create --name mybuilder --bootstrap --use 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Builder 'mybuilder' already exists, using it..." -ForegroundColor Gray
    docker buildx use mybuilder
}

# Get current branch name
try {
    $BRANCH_NAME = git rev-parse --abbrev-ref HEAD
} catch {
    $BRANCH_NAME = "unknown"
}

Write-Host "Current branch: $BRANCH_NAME" -ForegroundColor Cyan

# Define platforms
$PLATFORMS = "linux/amd64,linux/arm64,linux/ppc64le,linux/s390x"

# Build and push images
if ($Test) {
    # Test/branch build
    $IMAGE_TAG = "ghcr.io/${GithubUsername}/${ImageName}-test:${BRANCH_NAME}-${INTERNXT_CLI_VERSION}"
    Write-Host "Building and pushing TEST image: $IMAGE_TAG" -ForegroundColor Yellow
    Write-Host "Platforms: $PLATFORMS" -ForegroundColor Gray
    
    docker buildx build `
        --build-arg INTERNXT_CLI_VERSION=$INTERNXT_CLI_VERSION `
        --platform $PLATFORMS `
        -t $IMAGE_TAG `
        --pull `
        --push .
} else {
    # Production build (main/master branch)
    $IMAGE_BASE = "ghcr.io/${GithubUsername}/${ImageName}"
    $IMAGE_TAG_VERSION = "${IMAGE_BASE}:${INTERNXT_CLI_VERSION}"
    $IMAGE_TAG_LATEST = "${IMAGE_BASE}:latest"
    
    Write-Host "Building and pushing PRODUCTION images:" -ForegroundColor Yellow
    Write-Host "  - $IMAGE_TAG_VERSION" -ForegroundColor White
    Write-Host "  - $IMAGE_TAG_LATEST" -ForegroundColor White
    Write-Host "Platforms: $PLATFORMS" -ForegroundColor Gray
    
    docker buildx build `
        --build-arg INTERNXT_CLI_VERSION=$INTERNXT_CLI_VERSION `
        --platform $PLATFORMS `
        -t $IMAGE_TAG_VERSION `
        -t $IMAGE_TAG_LATEST `
        --pull `
        --push .
}

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Images have been pushed to GitHub Container Registry for the following architectures:" -ForegroundColor Cyan
    Write-Host "  - linux/amd64 (x86_64)" -ForegroundColor White
    Write-Host "  - linux/arm64 (ARM 64-bit)" -ForegroundColor White
    Write-Host "  - linux/ppc64le (PowerPC 64-bit)" -ForegroundColor White
    Write-Host "  - linux/s390x (IBM Z)" -ForegroundColor White
    Write-Host ""
    Write-Host "You can pull the image on any platform with:" -ForegroundColor Yellow
    if ($Test) {
        Write-Host "  docker pull $IMAGE_TAG" -ForegroundColor White
    } else {
        Write-Host "  docker pull $IMAGE_TAG_LATEST" -ForegroundColor White
        Write-Host "  docker pull $IMAGE_TAG_VERSION" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "View your packages at: https://github.com/$GithubUsername?tab=packages" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To make the image public, go to package settings and change visibility" -ForegroundColor Yellow
} else {
    Write-Error "Deployment failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
