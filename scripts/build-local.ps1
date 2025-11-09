# Build local Docker image for Internxt CLI
Write-Host "Starting local build workflow" -ForegroundColor Green

# Get Internxt CLI version from npm registry
Write-Host "Getting Internxt CLI version..." -ForegroundColor Yellow
$response = Invoke-RestMethod -Uri "https://registry.npmjs.org/@internxt/cli/latest"
$INTERNXT_CLI_VERSION = $response.version

if ([string]::IsNullOrEmpty($INTERNXT_CLI_VERSION)) {
    Write-Error "Error: INTERNXT_CLI_VERSION not detected"
    exit 1
}

Write-Host "Detected version: $INTERNXT_CLI_VERSION" -ForegroundColor Cyan

# Build for local architecture only (no push)
Write-Host "Building image locally: internxt-cli:$INTERNXT_CLI_VERSION" -ForegroundColor Yellow

docker build `
    --build-arg INTERNXT_CLI_VERSION=$INTERNXT_CLI_VERSION `
    -t internxt-cli:$INTERNXT_CLI_VERSION `
    -t internxt-cli:latest `
    --pull .

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Build completed successfully!" -ForegroundColor Green
    Write-Host "Images created:" -ForegroundColor Cyan
    Write-Host "  - internxt-cli:$INTERNXT_CLI_VERSION" -ForegroundColor White
    Write-Host "  - internxt-cli:latest" -ForegroundColor White
} else {
    Write-Error "Build failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
