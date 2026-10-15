# Build and package script for MDVu Windows Release
param(
    [string]$Configuration = "release"
)

$ErrorActionPreference = "Stop"

Write-Host "==> Building MDVu Windows ($Configuration)..." -ForegroundColor Cyan

cargo build --release -p mdvu-windows -p mdvu-cli

$DistDir = "dist/windows"
if (Test-Path $DistDir) {
    Remove-Item -Recurse -Force $DistDir
}
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

$ExeSource = "target/release/mdvu-windows.exe"
$CliSource = "target/release/mdvu-cli.exe"

if (Test-Path $ExeSource) {
    Copy-Item $ExeSource (Join-Path $DistDir "mdvu.exe")
    Write-Host "  [OK] Copied mdvu.exe" -ForegroundColor Green
} else {
    Write-Error "Binary not found at $ExeSource"
}

if (Test-Path $CliSource) {
    Copy-Item $CliSource (Join-Path $DistDir "mdvu-cli.exe")
    Write-Host "  [OK] Copied mdvu-cli.exe" -ForegroundColor Green
}

Copy-Item "README.md" (Join-Path $DistDir "README.txt")
Copy-Item "LICENSE" (Join-Path $DistDir "LICENSE.txt")

$Version = (Get-Content "version.txt").Trim()
$ZipPath = "dist/mdvu-$Version-windows-x86_64.zip"
Write-Host "==> Creating release archive: $ZipPath" -ForegroundColor Cyan

Compress-Archive -Path "$DistDir/*" -DestinationPath $ZipPath -Force

$Hash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash.ToLower()
Set-Content -Path "$ZipPath.sha256" -Value "$Hash  $(Split-Path $ZipPath -Leaf)"

Write-Host "==> Build complete!" -ForegroundColor Green
Write-Host "    Archive: $ZipPath"
Write-Host "    SHA-256: $Hash"
