# Load environment variables from .env file and set them in current PowerShell session
# Usage: . .\scripts\load-env.ps1

$envFile = Join-Path $PSScriptRoot "..\\.env"

if (-not (Test-Path $envFile)) {
    Write-Warning ".env file not found at $envFile"
    Write-Host "Create a .env file with your credentials:" -ForegroundColor Yellow
    Write-Host "GITHUB_USERNAME=your-username" -ForegroundColor Gray
    Write-Host "GITHUB_TOKEN=ghp_your_token_here" -ForegroundColor Gray
    exit 1
}

Write-Host "Loading environment variables from .env..." -ForegroundColor Green

Get-Content $envFile | ForEach-Object {
    if ($_ -match '^([^#][^=]+)=(.+)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        Set-Item -Path "env:$name" -Value $value
        Write-Host "  $name = $value" -ForegroundColor Gray
    }
}

Write-Host "Environment variables loaded successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "You can now run:" -ForegroundColor Cyan
Write-Host "  .\scripts\deploy.ps1" -ForegroundColor White
