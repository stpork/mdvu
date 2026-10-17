<# Native end-to-end runner. Execute in an interactive Windows user session.
   Installation is opt-in; the runner closes only the processes it starts. #>
param(
    [string]$Exe = "dist/windows/mdvu.exe",
    [string]$Msi,
    [string]$FixtureFilter = '*.md',
    [switch]$Install,
    [switch]$SkipUI,
    [int]$SampleSeconds = 12,
    [int]$BenchmarkRuns = 10,
    [string]$Output = "test-results/windows"
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$Output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)
New-Item -ItemType Directory -Force $Output | Out-Null
$Fixtures = @(Get-ChildItem 'tests/fixtures' -Recurse -File -Filter $FixtureFilter | Sort-Object FullName)
$Failures = [Collections.Generic.List[string]]::new()
$Results = [ordered]@{started=(Get-Date).ToString('o'); computer=$env:COMPUTERNAME; user=$env:USERNAME; os=(Get-CimInstance Win32_OperatingSystem).Caption; cpu=(Get-CimInstance Win32_Processor | Select-Object -First 1 -ExpandProperty Name); logicalCPUs=[Environment]::ProcessorCount; session=(Get-Process -Id $PID).SessionId; tests=@(); benchmarks=@(); metrics=@()}
$OldBrowserArguments = $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS
# Keep the RDP client being covered on the Mac from throttling native UI measurements.
$env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = ($OldBrowserArguments + ' --disable-backgrounding-occluded-windows --disable-renderer-backgrounding --disable-background-timer-throttling --disable-features=CalculateNativeWinOcclusion').Trim()
Start-Transcript -Path (Join-Path $Output 'run.log') -Force | Out-Null
function Save-Results {
    $Results.failures = @($Failures)
    $Results.finished = (Get-Date).ToString('o')
    $Results | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $Output 'results.json') -Encoding UTF8
}
function Assert-Test([string]$Name, [bool]$Passed) {
    $Results.tests += [ordered]@{name=$Name; passed=$Passed}
    if (-not $Passed) { $Failures.Add($Name) }
    Write-Host "$Name : $Passed"
}
function Invoke-CLI([string[]]$Arguments, [int]$Timeout = 60) {
    $Info = [Diagnostics.ProcessStartInfo]::new()
    $Info.FileName = $script:Binary
    $Info.Arguments = (($Arguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }) -join ' ')
    $Info.UseShellExecute = $false
    $Info.RedirectStandardOutput = $true
    $Info.RedirectStandardError = $true
    $Info.StandardOutputEncoding = [Text.Encoding]::UTF8
    $Info.StandardErrorEncoding = [Text.Encoding]::UTF8
    $Info.CreateNoWindow = $true
    $Process = [Diagnostics.Process]::new(); $Process.StartInfo = $Info
    $Watch = [Diagnostics.Stopwatch]::StartNew()
    [void]$Process.Start()
    $Stdout = $Process.StandardOutput.ReadToEndAsync(); $Stderr = $Process.StandardError.ReadToEndAsync()
    if (-not $Process.WaitForExit($Timeout * 1000)) { $Process.Kill(); throw 'CLI timeout' }
    $Watch.Stop()
    $Result = [PSCustomObject]@{code=$Process.ExitCode; stdout=$Stdout.Result; stderr=$Stderr.Result; elapsedMs=$Watch.Elapsed.TotalMilliseconds; cpuMs=$Process.TotalProcessorTime.TotalMilliseconds; peakWorkingSet=$Process.PeakWorkingSet64}
    $Process.Dispose(); return $Result
}
function Get-ProcessTree([int]$RootId) {
    $All = @(Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId,Name)
    $Ids = [Collections.Generic.HashSet[int]]::new(); [void]$Ids.Add($RootId)
    do {
        $Added = $false
        foreach ($Entry in $All) { if ($Ids.Contains([int]$Entry.ParentProcessId) -and $Ids.Add([int]$Entry.ProcessId)) { $Added=$true } }
    } while ($Added)
    return @(Get-Process -Id @($Ids) -ErrorAction SilentlyContinue)
}
try {
    if ($Install) {
        if (-not $Msi) { throw '-Install requires -Msi' }
        $Msi = (Resolve-Path $Msi).Path
        $Log = Join-Path $Output 'msi-install.log'
        $Info = [Diagnostics.ProcessStartInfo]::new()
        $Info.FileName = 'msiexec.exe'
        $Info.Arguments = "/i `"$Msi`" /qn /norestart /l*v `"$Log`""
        $Info.UseShellExecute = $false
        $Proc = [Diagnostics.Process]::new(); $Proc.StartInfo = $Info
        try {
            [void]$Proc.Start()
            if (-not $Proc.WaitForExit(180000)) { $Proc.Kill(); throw 'MSI install timed out' }
            Assert-Test 'MSI install exit' ($Proc.ExitCode -in @(0,3010))
        } finally { $Proc.Dispose() }
        $Exe = Join-Path $env:ProgramFiles 'MDVu/mdvu.exe'
        Assert-Test 'MSI OpenWith association' ($null -ne (Get-ItemProperty 'HKLM:\SOFTWARE\Classes\.md\OpenWithProgids' -Name 'MDVu.MarkdownDocument' -ErrorAction SilentlyContinue))
    }
    $script:Binary = (Resolve-Path $Exe).Path
    $Results.binary = $script:Binary
    $Results.sha256 = (Get-FileHash $script:Binary -Algorithm SHA256).Hash
    $Results.binaryBytes = (Get-Item $script:Binary).Length
    $Results.webviewVersions = @(Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft\EdgeWebView\Application" -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    $Temp = Join-Path $Output 'inputs'
    New-Item -ItemType Directory -Force $Temp | Out-Null
    $Source = Join-Path $Temp 'options.md'
    [IO.File]::WriteAllText($Source, "---`r`ndialect: obsidian`r`n---`r`n[[Architecture Overview]]`n" + [char]0 + "`n# After`n``````mermaid`ngraph TD`nA-->B`n``````")
    $Rendered = Invoke-CLI -Arguments @($Source,'--stdout','--no-mermaid')
    Assert-Test 'CLI auto dialect, CRLF, NUL' ($Rendered.code -eq 0 -and $Rendered.stdout.Contains('Architecture%20Overview.md') -and $Rendered.stdout.Contains('<h1>After</h1>'))
    $Article = ($Rendered.stdout -split '<article>',2)[1] -split '</article>',2
    Assert-Test 'CLI no diagrams' (-not $Article[0].Contains('diagram-pending'))
    $TOC = Invoke-CLI -Arguments @($Source,'--toc')
    Assert-Test 'CLI TOC JSON' ($TOC.code -eq 0 -and @($TOC.stdout | ConvertFrom-Json).Count -gt 0)
    $Missing = Invoke-CLI -Arguments @((Join-Path $Temp 'missing.md'),'--stdout')
    Assert-Test 'CLI missing input exits nonzero' ($Missing.code -ne 0)
    $env:MDVU_BENCHMARK_RUNS = $BenchmarkRuns.ToString()
    foreach ($Fixture in $Fixtures) {
        $Bench = Invoke-CLI -Arguments @('--benchmark',$Fixture.FullName)
        $Results.benchmarks += [ordered]@{fixture=$Fixture.Name; bytes=$Fixture.Length; output=$Bench.stdout.Trim(); elapsedMs=$Bench.elapsedMs; cpuMs=$Bench.cpuMs; peakWorkingSet=$Bench.peakWorkingSet; exit=$Bench.code}
        Assert-Test "Benchmark $($Fixture.Name)" ($Bench.code -eq 0)
    }
    if (-not $SkipUI) {
        if ((Get-Process -Id $PID).SessionId -eq 0) { throw 'UI and screenshots require an interactive session; use start-windows-interactive-test.ps1 from SSH.' }
        try {
            & "$PSScriptRoot/test-windows-gui.ps1" -Exe $script:Binary
            Assert-Test 'Native WebView2: >2MB, local images, CSP, TOC' $true
        } catch { Assert-Test 'Native WebView2: >2MB, local images, CSP, TOC' $false; Write-Warning $_ }
        Add-Type -AssemblyName System.Drawing
        Add-Type @'
using System; using System.Runtime.InteropServices;
public static class MdvuCapture {
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
}
'@
        $UISource = [IO.File]::ReadAllText((Resolve-Path 'tests/ui/check-fixture.js').Path)
        $ExpectedErrors = [IO.File]::ReadAllText((Resolve-Path 'tests/ui/expected-diagram-errors.json').Path) | ConvertFrom-Json
        foreach ($Fixture in $Fixtures) {
            $Profile = Join-Path $Temp ('webview-' + [Guid]::NewGuid())
            $OldMetrics = $env:MDVU_METRICS_FILE
            $OldCache = $env:MDVU_CACHE_DIR
            $env:MDVU_CACHE_DIR = Join-Path $Profile 'diagram-cache'
            $OldUIScript = $env:MDVU_UI_SCRIPT; $OldUIResult = $env:MDVU_UI_RESULT_FILE
            New-Item -ItemType Directory -Force $Profile | Out-Null
            $FixtureKey = $Fixture.FullName.Substring((Resolve-Path 'tests/fixtures').Path.Length+1).Replace('\','/')
            # Assign arrays directly: a PowerShell if-expression unwraps empty/singleton results.
            $Expected = @()
            if ($null -ne $ExpectedErrors.$FixtureKey) { $Expected = @($ExpectedErrors.$FixtureKey) }
            $ExpectedJSON = ConvertTo-Json -InputObject $Expected -Depth 6 -Compress
            if (-not $ExpectedJSON.StartsWith('[')) { throw 'Expected diagram errors must serialize as a JSON array' }
            $CheckScript = Join-Path $Profile 'check.js'
            $IdleProbe = if ($Fixture.Name -eq 'test-heavy.md') { 'true' } else { 'false' }
            [IO.File]::WriteAllText($CheckScript, ('window.__mdvuAuditIdleProbe=' + $IdleProbe + ';window.__mdvuExpectedDiagramErrors=' + $ExpectedJSON + ';' + [Environment]::NewLine + $UISource))
            $env:MDVU_UI_SCRIPT = $CheckScript
            $UIResult = Join-Path $Output ($Fixture.BaseName+'-ui.json')
            Remove-Item $UIResult -ErrorAction SilentlyContinue
            $env:MDVU_UI_RESULT_FILE = $UIResult
            $Telemetry = Join-Path $Output ($Fixture.BaseName+'-ready.json')
            Remove-Item $Telemetry -ErrorAction SilentlyContinue
            $env:MDVU_METRICS_FILE = $Telemetry
            $OldProfile = $env:WEBVIEW2_USER_DATA_FOLDER
            $env:WEBVIEW2_USER_DATA_FOLDER = $Profile
            $Process = $null
            try {
                $Clock = [Diagnostics.Stopwatch]::StartNew()
                $Process = Start-Process $script:Binary -RedirectStandardError (Join-Path $Output ($Fixture.BaseName+'-stderr.log')) -ArgumentList @('"'+$Fixture.FullName+'"','--theme','light') -PassThru
                $Samples = @(); $FirstWindowMs = $null
                do {
                    $Process.Refresh()
                    if ($Process.HasExited) { throw "GUI exited on $($Fixture.Name)" }
                    if ($null -eq $FirstWindowMs -and $Process.MainWindowHandle -ne [IntPtr]::Zero) { $FirstWindowMs=$Clock.Elapsed.TotalMilliseconds }
                    $Tree = @(Get-ProcessTree $Process.Id)
                    $Samples += [PSCustomObject]@{elapsedMs=$Clock.Elapsed.TotalMilliseconds; processCount=$Tree.Count; privateBytes=($Tree | Measure-Object PrivateMemorySize64 -Sum).Sum; workingSet=($Tree | Measure-Object WorkingSet64 -Sum).Sum; cpuMs=($Tree | ForEach-Object {$_.TotalProcessorTime.TotalMilliseconds} | Measure-Object -Sum).Sum; appPrivateBytes=$Process.PrivateMemorySize64; appWorkingSet=$Process.WorkingSet64}
                    Start-Sleep -Milliseconds 500
                } while ($Clock.Elapsed.TotalSeconds -lt $SampleSeconds -or (-not (Test-Path $UIResult) -and $Clock.Elapsed.TotalSeconds -lt 100))
                $Samples | Export-Csv (Join-Path $Output ($Fixture.BaseName+'-process-tree.csv')) -NoTypeInformation
                $Ready = if (Test-Path $Telemetry) { Get-Content $Telemetry -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
                $UI = if (Test-Path $UIResult) { Get-Content $UIResult -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
                if ($null -eq $UI) { throw 'UI report missing: check the interactive desktop and renderer before continuing' }
                Assert-Test "UI checks $($Fixture.Name)" ($null -ne $UI -and $UI.passed)
                $Results.metrics += [ordered]@{fixture=$Fixture.FullName.Substring((Resolve-Path 'tests/fixtures').Path.Length+1); ui=$UI; firstWindowMs=$FirstWindowMs; documentReady=$Ready; samples=$Samples; note='Working sets sum shared pages; private bytes are the better total. First window is not first content.'}
                [void][MdvuCapture]::SetForegroundWindow($Process.MainWindowHandle)
                $Rect = [MdvuCapture+RECT]::new()
                if ([MdvuCapture]::GetWindowRect($Process.MainWindowHandle,[ref]$Rect) -and $Rect.Right -gt $Rect.Left) {
                    $Bitmap = [Drawing.Bitmap]::new($Rect.Right-$Rect.Left,$Rect.Bottom-$Rect.Top)
                    $Graphics = [Drawing.Graphics]::FromImage($Bitmap)
                    try {
                        $Graphics.CopyFromScreen($Rect.Left,$Rect.Top,0,0,$Bitmap.Size)
                        $Bitmap.Save((Join-Path $Output ($Fixture.BaseName+'.png')))
                    } finally { $Graphics.Dispose(); $Bitmap.Dispose() }
                }
                Assert-Test "GUI fixture $($Fixture.Name)" ($null -ne $FirstWindowMs -and $null -ne $Ready)
                Save-Results
            } catch {
                $Failures.Add("$($Fixture.Name): $($_.Exception.Message)"); Write-Warning $_
                if (-not (Test-Path $UIResult)) { break }
            } finally {
                if ($Process -and -not $Process.HasExited) { [void]$Process.CloseMainWindow(); if (-not $Process.WaitForExit(5000)) { $Process.Kill() } }
                $env:WEBVIEW2_USER_DATA_FOLDER = $OldProfile
                $env:MDVU_METRICS_FILE = $OldMetrics
                $env:MDVU_CACHE_DIR = $OldCache
                $env:MDVU_UI_SCRIPT = $OldUIScript; $env:MDVU_UI_RESULT_FILE = $OldUIResult
                Remove-Item $Profile -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
} catch { $Failures.Add($_.Exception.Message); Write-Warning $_ }
finally { $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = $OldBrowserArguments; Remove-Item Env:MDVU_BENCHMARK_RUNS -ErrorAction SilentlyContinue; Save-Results; Stop-Transcript | Out-Null }
if ($Failures.Count) { throw "Windows validation failed: $($Failures -join '; ')" }
