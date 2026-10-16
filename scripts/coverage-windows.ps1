<# Run native unit coverage, then include an instrumented WebView2 session.
   Prerequisites: cargo install cargo-llvm-cov --locked; rustup component add llvm-tools-preview.
   Run in an interactive Windows user session. Performance reports use the separate release runner. #>
param([string]$Output = 'target/coverage')
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$Output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)
New-Item -ItemType Directory -Force $Output | Out-Null
& cargo llvm-cov --workspace --lcov --output-path (Join-Path $Output 'windows-unit.lcov')
if ($LASTEXITCODE -ne 0) { throw 'Native coverage tests failed' }
$Saved = @{}
try {
    # Decode cargo's escaped environment without executing shell output; also works on Windows PowerShell 5.
    $Environment = @(& cargo llvm-cov show-env --pwsh)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot obtain coverage environment' }
    foreach ($Line in $Environment) {
        if ($Line -notmatch '^\$env:(\w+)="(.*)"$') { throw "Unexpected cargo coverage environment: $Line" }
        $Name = $Matches[1]; $Encoded = $Matches[2]
        $Value = [regex]::Replace($Encoded, '`u\{([0-9a-fA-F]+)\}', { param($m) [char]::ConvertFromUtf32([Convert]::ToInt32($m.Groups[1].Value,16)) })
        $Saved[$Name] = [Environment]::GetEnvironmentVariable($Name)
        [Environment]::SetEnvironmentVariable($Name,$Value)
    }
    $Messages = @(& cargo build -p mdvu-windows --bin mdvu --message-format=json-render-diagnostics)
    if ($LASTEXITCODE -ne 0) { throw 'Instrumented GUI build failed' }
    $Binary = $Messages | ForEach-Object { $_ | ConvertFrom-Json } |
        Where-Object { $_.reason -eq 'compiler-artifact' -and $_.target.name -eq 'mdvu' -and $_.executable } |
        Select-Object -Last 1 -ExpandProperty executable
    if (-not $Binary) { throw 'Cargo did not return the instrumented executable' }
    & "$PSScriptRoot/test-windows-system.ps1" -Exe $Binary -FixtureFilter test-onescreen.md -BenchmarkRuns 1 -SampleSeconds 1 -Output (Join-Path $Output 'gui')
    & cargo llvm-cov report --lcov --output-path (Join-Path $Output 'windows.lcov')
    if ($LASTEXITCODE -ne 0) { throw 'Native GUI coverage export failed' }
} finally {
    foreach ($Name in $Saved.Keys) { [Environment]::SetEnvironmentVariable($Name,$Saved[$Name]) }
}
