<#
.SYNOPSIS
    MDVu Windows Build & Packaging Script

.DESCRIPTION
    Builds, tests, and packages MDVu for Windows.
    Provides standard build workflows for native Windows development.

.PARAMETER Command
    The build action to run: app, release, debug, test, package, clean, or help.

.EXAMPLE
    .\build.ps1
    Builds and packages optimized Windows release archive into dist/.

.EXAMPLE
    .\build.ps1 test
    Runs all Rust workspace tests.
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("app", "release", "debug", "test", "package", "clean", "help")]
    [string]$Command = "app"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ScriptDir

function Show-Usage {
    Write-Host @"
Usage: .\build.ps1 [command]

Commands:
  app        Build and package MDVu for Windows into dist/ (default)
  release    Build optimized release binary (mdvu.exe)
  debug      Build unoptimized debug binary
  test       Run Rust workspace tests
  package    Package existing binary into dist/ ZIP archive with SHA-256
  clean      Remove build artifacts and dist/ directory
  help       Show this help message
"@
}

switch ($Command) {
    "help" {
        Show-Usage
        exit 0
    }
    "test" {
        Write-Host "==> Running tests..." -ForegroundColor Cyan
        cargo test --workspace
        exit $LASTEXITCODE
    }
    "debug" {
        Write-Host "==> Building debug binaries..." -ForegroundColor Cyan
        cargo build -p mdvu-windows --bin mdvu
        exit $LASTEXITCODE
    }
    "release" {
        Write-Host "==> Building optimized release binaries..." -ForegroundColor Cyan
        cargo build --release -p mdvu-windows --bin mdvu
        exit $LASTEXITCODE
    }
    "clean" {
        Write-Host "==> Cleaning build artifacts..." -ForegroundColor Cyan
        cargo clean
        if (Test-Path "dist") { Remove-Item -Recurse -Force "dist" }
        exit 0
    }
    "package" {
        & "$ScriptDir\scripts\build-windows.ps1"
        exit $LASTEXITCODE
    }
    "app" {
        & "$ScriptDir\scripts\build-windows.ps1"
        exit $LASTEXITCODE
    }
}
