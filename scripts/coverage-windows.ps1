<# Run native unit coverage, then include an instrumented WebView2 session.
   Prerequisites: cargo install cargo-llvm-cov --locked; rustup component add llvm-tools-preview.
   Run in an interactive Windows user session. Performance reports use the separate release runner. #>
param([string]$Output = 'target/coverage', [switch]$TimerOnly)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$Output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)
New-Item -ItemType Directory -Force $Output | Out-Null
$Saved = @{}
try {
    # show-env defaults to target/, while test defaults to target/llvm-cov-target/.
    # Keep profiles and Cargo artifacts together, away from normal debug builds.
    $CoverageTarget = Join-Path (Get-Location).Path 'target/llvm-cov-target'
    foreach ($Name in @('CARGO_LLVM_COV_TARGET_DIR','CARGO_TARGET_DIR')) {
        $Saved[$Name] = [Environment]::GetEnvironmentVariable($Name)
        [Environment]::SetEnvironmentVariable($Name,$CoverageTarget)
    }
    & cargo llvm-cov --workspace --lcov --output-path (Join-Path $Output 'windows-unit.lcov')
    if ($LASTEXITCODE -ne 0) { throw 'Native coverage tests failed' }
    # Prepare before show-env: invoking llvm-cov run inside its exported wrapper
    # environment would recursively wrap rustc on Windows.
    & cargo llvm-cov run --no-report -p mdvu-windows --bin mdvu -- --help
    if ($LASTEXITCODE -ne 0) { throw 'Instrumented GUI preparation failed' }
    # Decode cargo's escaped environment without executing shell output; also works on Windows PowerShell 5.
    $Environment = @(& cargo llvm-cov show-env --pwsh)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot obtain coverage environment' }
    foreach ($Line in $Environment) {
        if ($Line -notmatch '^\$env:(\w+)="(.*)"$') { throw "Unexpected cargo coverage environment: $Line" }
        $Name = $Matches[1]; $Encoded = $Matches[2]
        $Value = [regex]::Replace($Encoded, '`u\{([0-9a-fA-F]+)\}', { param($m) [char]::ConvertFromUtf32([Convert]::ToInt32($m.Groups[1].Value,16)) })
        if (-not $Saved.ContainsKey($Name)) { $Saved[$Name] = [Environment]::GetEnvironmentVariable($Name) }
        [Environment]::SetEnvironmentVariable($Name,$Value)
    }
    $Messages = @(& cargo build -p mdvu-windows --bin mdvu --message-format=json-render-diagnostics)
    if ($LASTEXITCODE -ne 0) { throw 'Instrumented GUI build failed' }
    $Binary = $Messages | ForEach-Object { $_ | ConvertFrom-Json } |
        Where-Object { $_.reason -eq 'compiler-artifact' -and $_.target.name -eq 'mdvu' -and $_.executable } |
        Select-Object -Last 1 -ExpandProperty executable
    if (-not $Binary) { throw 'Cargo did not return the instrumented executable' }
    & "$PSScriptRoot/test-windows-system.ps1" -Exe $Binary -TimerOnly:$TimerOnly -FixtureFilter test-onescreen.md -BenchmarkRuns 1 -SampleSeconds 1 -Output (Join-Path $Output 'gui')
    if (-not (Get-ChildItem $CoverageTarget -Filter '*.profraw' -File)) { throw 'Native execution produced no coverage profiles' }
    & cargo llvm-cov report --lcov --output-path (Join-Path $Output 'windows.lcov')
    if ($LASTEXITCODE -ne 0) { throw 'Native GUI coverage export failed' }
    if (-not (Select-String -Path (Join-Path $Output 'windows.lcov') -Pattern '^FNDA:[1-9][0-9]*,.*run_gui' -Quiet)) {
        throw 'GUI executed but its coverage counters are missing; refusing a unit-only report'
    }
} finally {
    foreach ($Name in $Saved.Keys) { [Environment]::SetEnvironmentVariable($Name,$Saved[$Name]) }
}
