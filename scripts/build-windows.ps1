# Build and package script for MDVu Windows Release (.zip, .msi, Scoop, WinGet, Chocolatey)
param(
    [string]$Configuration = "release"
)

$ErrorActionPreference = "Stop"

Write-Host "==> Building MDVu Windows ($Configuration)..." -ForegroundColor Cyan

if ($Configuration -eq "release") {
    cargo build --release -p mdvu-windows --bin mdvu
} else {
    cargo build -p mdvu-windows --bin mdvu
}

$DistDir = "dist/windows"
Get-Process -Name "mdvu" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
if (Test-Path $DistDir) {
    Get-ChildItem -Path $DistDir -Exclude @("*.WebView2", "WebView2Loader.dll") | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

$ExeCandidates = @(
    "target/$Configuration/mdvu.exe",
    "target/x86_64-pc-windows-msvc/$Configuration/mdvu.exe",
    "target/x86_64-pc-windows-gnu/$Configuration/mdvu.exe",
    "target/release/mdvu.exe",
    "target/debug/mdvu.exe"
)

$ExeSource = $ExeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($ExeSource) {
    Copy-Item $ExeSource (Join-Path $DistDir "mdvu.exe") -Force
    $ExeSize = (Get-Item (Join-Path $DistDir "mdvu.exe")).Length
    Write-Host "  [OK] Copied $ExeSource -> mdvu.exe ($([math]::Round($ExeSize / 1MB, 2)) MB standalone)" -ForegroundColor Green
} else {
    throw "Binary mdvu.exe not found in target directories"
}

# Copy WebView2Loader.dll (required by GNU/MinGW targets, helpful for MSVC)
$LoaderDll = Get-ChildItem -Path "target" -Recurse -Filter "WebView2Loader.dll" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -like "*x64*WebView2Loader.dll" } |
    Select-Object -First 1
if ($LoaderDll) {
    Copy-Item $LoaderDll.FullName (Join-Path $DistDir "WebView2Loader.dll") -Force
    Write-Host "  [OK] Copied $($LoaderDll.Name) -> WebView2Loader.dll" -ForegroundColor Green
}

Copy-Item "README.md" (Join-Path $DistDir "README.txt") -Force
Copy-Item "LICENSE" (Join-Path $DistDir "LICENSE.txt") -Force

$Version = (Get-Content "version.txt").Trim()

# ---------------------------------------------------------------------------
# 1. Create Portable ZIP Archive
# ---------------------------------------------------------------------------
$ZipPath = "dist/mdvu-$Version-windows-x86_64.zip"
Write-Host "==> Creating portable release archive: $ZipPath" -ForegroundColor Cyan

$ArchiveItems = Get-ChildItem -Path $DistDir -Exclude "*.WebView2" | Select-Object -ExpandProperty FullName
Compress-Archive -Path $ArchiveItems -DestinationPath $ZipPath -Force

$ZipHash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash.ToLower()
Set-Content -Path "$ZipPath.sha256" -Value "$ZipHash  $(Split-Path $ZipPath -Leaf)"

# ---------------------------------------------------------------------------
# 2. Build Windows MSI Installer (WiX Toolset v3)
# ---------------------------------------------------------------------------
$MsiPath = "dist/mdvu-$Version-windows-x86_64.msi"
Write-Host "==> Building Windows MSI installer: $MsiPath" -ForegroundColor Cyan

function Find-WixBinDir {
    $cmd = Get-Command "candle.exe" -ErrorAction SilentlyContinue
    if ($cmd) {
        return Split-Path $cmd.Source -Parent
    }
    $progFiles = @(
        ${env:ProgramFiles(x86)},
        $env:ProgramFiles
    ) | Where-Object { $_ }
    foreach ($pf in $progFiles) {
        $found = Get-ChildItem -Path $pf -Directory -Filter "WiX Toolset*" -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            Select-Object -First 1
        if ($found -and (Test-Path (Join-Path $found.FullName "bin\candle.exe"))) {
            return (Join-Path $found.FullName "bin")
        }
    }
    $localWixDir = "target/wix314"
    if (Test-Path (Join-Path $localWixDir "candle.exe")) {
        return (Resolve-Path $localWixDir).Path
    }
    Write-Host "  [..] WiX Toolset not found in PATH; downloading portable wix314-binaries..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $localWixDir | Out-Null
    $wixZip = "target/wix314-binaries.zip"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://github.com/wixtoolset/wix3/releases/download/wix3141rtm/wix314-binaries.zip" -OutFile $wixZip -UseBasicParsing
    Expand-Archive -Path $wixZip -DestinationPath $localWixDir -Force
    return (Resolve-Path $localWixDir).Path
}

$WixBin = Find-WixBinDir
$CandleExe = Join-Path $WixBin "candle.exe"
$LightExe = Join-Path $WixBin "light.exe"
$WixObj = "target/mdvu.wixobj"

& $CandleExe -nologo -arch x64 "-dVersion=$Version" "-dDistDir=$DistDir" -out $WixObj "packaging/windows/mdvu.wxs"
if ($LASTEXITCODE -ne 0) {
    throw "WiX candle.exe failed with exit code $LASTEXITCODE"
}

& $LightExe -nologo -ext WixUIExtension -spdb -sval -out $MsiPath $WixObj
if ($LASTEXITCODE -ne 0) {
    throw "WiX light.exe failed with exit code $LASTEXITCODE"
}

$MsiHash = (Get-FileHash -Path $MsiPath -Algorithm SHA256).Hash.ToLower()
Set-Content -Path "$MsiPath.sha256" -Value "$MsiHash  $(Split-Path $MsiPath -Leaf)"

# ---------------------------------------------------------------------------
# 3. Generate Windows Package Manager Manifests (Scoop, WinGet, Chocolatey)
# ---------------------------------------------------------------------------
if (Test-Path "packaging/scoop/mdvu.json.template") {
    $ScoopContent = (Get-Content "packaging/scoop/mdvu.json.template" -Raw) `
        -replace "VERSION_PLACEHOLDER", $Version `
        -replace "SHA256_PLACEHOLDER", $ZipHash
    Set-Content -Path "dist/mdvu.json" -Value $ScoopContent -Encoding UTF8
}

if (Test-Path "packaging/winget/stpork.mdvu.yaml.template") {
    $WingetContent = (Get-Content "packaging/winget/stpork.mdvu.yaml.template" -Raw) `
        -replace "VERSION_PLACEHOLDER", $Version `
        -replace "MSI_SHA256_PLACEHOLDER", $MsiHash.ToUpper() `
        -replace "ZIP_SHA256_PLACEHOLDER", $ZipHash.ToUpper()
    Set-Content -Path "dist/stpork.mdvu.yaml" -Value $WingetContent -Encoding UTF8
}

if (Test-Path "packaging/chocolatey/mdvu.nuspec.template") {
    New-Item -ItemType Directory -Force -Path "dist/chocolatey/tools" | Out-Null
    $NuspecContent = (Get-Content "packaging/chocolatey/mdvu.nuspec.template" -Raw) `
        -replace "VERSION_PLACEHOLDER", $Version
    Set-Content -Path "dist/chocolatey/mdvu.nuspec" -Value $NuspecContent -Encoding UTF8

    if (Test-Path "packaging/chocolatey/tools/chocolateyinstall.ps1.template") {
        $ChocoInstall = (Get-Content "packaging/chocolatey/tools/chocolateyinstall.ps1.template" -Raw) `
            -replace "VERSION_PLACEHOLDER", $Version `
            -replace "MSI_SHA256_PLACEHOLDER", $MsiHash
        Set-Content -Path "dist/chocolatey/tools/chocolateyinstall.ps1" -Value $ChocoInstall -Encoding UTF8
    }
}

Write-Host ""
Write-Host "==> Windows Release Build Complete (v$Version)!" -ForegroundColor Green
Write-Host "    ZIP Archive : $ZipPath ($ZipHash)"
Write-Host "    MSI Package : $MsiPath ($MsiHash)"
Write-Host "    Scoop       : dist/mdvu.json"
Write-Host "    WinGet      : dist/stpork.mdvu.yaml"
Write-Host "    Chocolatey  : dist/chocolatey/mdvu.nuspec"
