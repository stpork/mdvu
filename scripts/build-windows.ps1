# Build and package script for MDVu Windows Release
param(
    [string]$Configuration = "release"
)

$ErrorActionPreference = "Stop"

Write-Host "==> Building MDVu Windows ($Configuration)..." -ForegroundColor Cyan

$CargoFlags = if ($Configuration -eq "release") { @("--release") } else { @() }
cargo build @CargoFlags -p mdvu-windows -p mdvu-cli

$DistDir = "dist/windows"
if (Test-Path $DistDir) {
    Remove-Item -Recurse -Force $DistDir
}
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

$ExeCandidates = @(
    "target/$Configuration/mdvu-windows.exe",
    "target/x86_64-pc-windows-msvc/$Configuration/mdvu-windows.exe",
    "target/release/mdvu-windows.exe",
    "target/debug/mdvu-windows.exe"
)
$CliCandidates = @(
    "target/$Configuration/mdvu-cli.exe",
    "target/x86_64-pc-windows-msvc/$Configuration/mdvu-cli.exe",
    "target/release/mdvu-cli.exe",
    "target/debug/mdvu-cli.exe"
)

$ExeSource = $ExeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
$CliSource = $CliCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($ExeSource) {
    Copy-Item $ExeSource (Join-Path $DistDir "mdvu.exe")
    Write-Host "  [OK] Copied $ExeSource -> mdvu.exe" -ForegroundColor Green
} else {
    Write-Warning "Binary mdvu-windows.exe not found in target directories"
}

if ($CliSource) {
    Copy-Item $CliSource (Join-Path $DistDir "mdvu-cli.exe")
    Write-Host "  [OK] Copied $CliSource -> mdvu-cli.exe" -ForegroundColor Green
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
