param([string]$Exe = "dist/windows/mdvu.exe")
$ErrorActionPreference = "Stop"
$Exe = (Resolve-Path $Exe).Path
$TestDir = Join-Path ([IO.Path]::GetTempPath()) ("mdvu GUI # " + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $TestDir | Out-Null
try {
    Copy-Item "tests/fixtures/diagram.png" (Join-Path $TestDir "image.png")
    $Diagrams = @'
```mermaid
graph TD; A-->B
```

```plantuml
@startuml
Alice -> Bob: Hello
@enduml
```

'@
    $Markdown = "# Target Heading`n`n<img id='smoke-img' src='image.png'>`n<img src='data:,bad' onerror='window.auditExecuted=true'>`n`n" + $Diagrams + ("sample paragraph`n`n" * 150000)
    $InputFile = Join-Path $TestDir "large note.md"
    [IO.File]::WriteAllText($InputFile, $Markdown)
    $env:MDVU_GUI_SMOKE = "1"
    $ErrorLog = Join-Path $TestDir "stderr.log"
    $Info = [Diagnostics.ProcessStartInfo]::new()
    $Info.FileName = $Exe
    $Info.Arguments = '"' + $InputFile + '"'
    $Info.UseShellExecute = $false
    $Info.RedirectStandardOutput = $true
    $Info.RedirectStandardError = $true
    $Info.StandardOutputEncoding = [Text.Encoding]::UTF8
    $Info.StandardErrorEncoding = [Text.Encoding]::UTF8
    $Process = [Diagnostics.Process]::new()
    $Process.StartInfo = $Info
    try {
        [void]$Process.Start()
        $Stdout = $Process.StandardOutput.ReadToEndAsync()
        $Stderr = $Process.StandardError.ReadToEndAsync()
        if (-not $Process.WaitForExit(60000)) { $Process.Kill(); throw "WebView2 GUI smoke test timed out" }
        $Text = $Stdout.Result
        [IO.File]::WriteAllText($ErrorLog, $Stderr.Result)
        if ($Process.ExitCode -ne 0) { throw "WebView2 GUI smoke test failed: $($Process.ExitCode) $($Stderr.Result)" }
        $Match = [regex]::Match($Text, 'GUI smoke: (\{[^\r\n]+\})')
        if (-not $Match.Success) { throw "WebView2 smoke diagnostic missing: $Text $($Stderr.Result)" }
        $Checks = $Match.Groups[1].Value | ConvertFrom-Json
        foreach ($Name in @('ready','safe','large','image','toc','diagrams','isolated')) {
            if ($Checks.$Name -ne $true) { throw "WebView2 smoke check failed: $Name; $($Match.Groups[1].Value)" }
        }
        Write-Host $Match.Value
    } finally { $Process.Dispose() }
} finally {
    Remove-Item Env:MDVU_GUI_SMOKE -ErrorAction SilentlyContinue
    Remove-Item $TestDir -Recurse -Force
}
