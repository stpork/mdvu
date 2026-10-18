<# Destructive integration test for a disposable/clean Windows test installation.
   All tests both scopes; User must run without elevation, Machine with elevation. #>
param(
    [Parameter(Mandatory=$true)][string]$Msi,
    [ValidateSet('All','Machine','User')][string]$Scope = 'All',
    [string]$Output = 'test-results/installer-windows'
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$Msi = (Resolve-Path $Msi).Path
$Output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)
New-Item -ItemType Directory -Force $Output | Out-Null
$Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$IsAdmin = ([Security.Principal.WindowsPrincipal]::new($Identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($Scope -eq 'All') {
    if (-not $IsAdmin) { throw 'Run -Scope All in an elevated PowerShell; -Scope User requires no elevation.' }
    & $PSCommandPath -Msi $Msi -Scope Machine -Output $Output
    # A limited interactive task uses the signed-in user's non-elevated token.
    # The child asserts that token before starting MSI, rather than assuming it.
    $Name = 'MDVu-Installer-Test-' + [Guid]::NewGuid().ToString('N')
    $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Msi `"$Msi`" -Scope User -Output `"$Output`""
    $Action = New-ScheduledTaskAction -Execute (Get-Process -Id $PID).Path -Argument $Arguments -WorkingDirectory (Get-Location).Path
    $Principal = New-ScheduledTaskPrincipal -UserId $Identity.Name -LogonType Interactive -RunLevel Limited
    try {
        Register-ScheduledTask -TaskName $Name -Action $Action -Principal $Principal -Settings (New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5)) | Out-Null
        $Started = Get-Date
        Start-ScheduledTask $Name
        $Deadline = $Started.AddMinutes(5)
        do {
            Start-Sleep -Milliseconds 500
            $Task = Get-ScheduledTask $Name
            $Info = Get-ScheduledTaskInfo $Name
        } while (($Task.State -eq 'Running' -or $Info.LastRunTime -lt $Started.AddSeconds(-1)) -and (Get-Date) -lt $Deadline)
        if ($Task.State -eq 'Running') { Stop-ScheduledTask $Name; throw 'Non-admin MSI test timed out' }
        if ($Info.LastTaskResult -ne 0) { throw "Non-admin MSI test failed: $($Info.LastTaskResult); inspect $Output/User.log" }
        $Report = Get-Content (Join-Path $Output 'User.json') -Raw | ConvertFrom-Json
        if (-not $Report.passed -or $Report.elevated) { throw 'Non-admin MSI verification did not pass' }
        Write-Host 'MSI: machine/admin and user/non-admin install, Finish, shortcut, launch and uninstall passed.'
    } finally { Unregister-ScheduledTask $Name -Confirm:$false -ErrorAction SilentlyContinue }
    return
}
if ($IsAdmin -ne ($Scope -eq 'Machine')) { throw "Wrong token for $Scope test (elevated=$IsAdmin)" }

Start-Transcript -Path (Join-Path $Output "$Scope.log") -Force | Out-Null
$Report = [ordered]@{scope=$Scope; elevated=$IsAdmin; passed=$false; tests=@()}
function Assert-Test([string]$Name, [bool]$Passed) {
    $Report.tests += [ordered]@{name=$Name; passed=$Passed}
    Write-Host "$Name : $Passed"
    if (-not $Passed) { throw $Name }
}
function Invoke-Msi([string]$Arguments) {
    $Process = Start-Process msiexec.exe -ArgumentList $Arguments -PassThru
    try {
        if (-not $Process.WaitForExit(120000)) { $Process.Kill(); throw 'MSI operation timed out' }
        if ($Process.ExitCode -notin @(0,3010)) { throw "MSI failed: $($Process.ExitCode) ($Arguments)" }
    } finally { $Process.Dispose() }
}
if (-not ('MdvuInstallerUI' -as [type])) { Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class MdvuInstallerUI {
    delegate bool EnumProc(IntPtr window, IntPtr parameter);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr parameter);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr window, StringBuilder text, int count);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] static extern bool IsWindowEnabled(IntPtr window);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeout(IntPtr window, uint message, IntPtr wParam, IntPtr lParam, uint flags, uint timeout, out IntPtr result);
    public static IntPtr Window(int process) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((window, unused) => { uint id; GetWindowThreadProcessId(window, out id);
            if (id == process && IsWindowVisible(window)) { found = window; return false; } return true; }, IntPtr.Zero);
        return found;
    }
    public static IntPtr Control(IntPtr parent, string caption) {
        IntPtr found = IntPtr.Zero;
        EnumChildWindows(parent, (window, unused) => { var text = new StringBuilder(1024); GetWindowText(window, text, text.Capacity);
            if (IsWindowVisible(window) && IsWindowEnabled(window) && text.ToString().Replace("&", "") == caption) { found = window; return false; } return true; }, IntPtr.Zero);
        return found;
    }
    public static bool Checked(IntPtr control) {
        IntPtr result; SendMessageTimeout(control, 0xF0, IntPtr.Zero, IntPtr.Zero, 2, 5000, out result); return result != IntPtr.Zero;
    }
    public static void Click(IntPtr control) {
        IntPtr result; if (control == IntPtr.Zero || SendMessageTimeout(control, 0xF5, IntPtr.Zero, IntPtr.Zero, 2, 5000, out result) == IntPtr.Zero) throw new Exception("Installer control did not respond");
    }
}
'@ }
function Wait-Control([Diagnostics.Process]$Process, [string]$Caption) {
    $Deadline = (Get-Date).AddSeconds(90)
    do {
        if ($Process.HasExited) { throw "Installer exited before '$Caption': $($Process.ExitCode)" }
        $Window = [MdvuInstallerUI]::Window($Process.Id)
        $Control = [MdvuInstallerUI]::Control($Window, $Caption)
        if ($Control -ne [IntPtr]::Zero) { return $Control }
        Start-Sleep -Milliseconds 100
    } while ((Get-Date) -lt $Deadline)
    throw "Installer did not show '$Caption'"
}

$Machine = $Scope -eq 'Machine'
$Folder = if ($Machine) { Join-Path $env:ProgramFiles 'MDVu' } else { Join-Path $env:LOCALAPPDATA 'Programs/MDVu' }
$Programs = [Environment]::GetFolderPath($(if ($Machine) { 'CommonPrograms' } else { 'Programs' }))
$Shortcut = Join-Path $Programs 'MDVu/MDVu.lnk'
$Exe = Join-Path $Folder 'mdvu.exe'
$Hive = if ($Machine) { 'HKLM:' } else { 'HKCU:' }
$ProductCode = $null
$Process = $null
$InstallStarted = $false
try {
    Assert-Test 'Clean test installation' (-not (Test-Path $Exe) -and -not (Test-Path $Shortcut))
    $Installer = New-Object -ComObject WindowsInstaller.Installer
    $Database = $Installer.OpenDatabase($Msi, 0)
    try {
        $View = $Database.OpenView("SELECT ``Value`` FROM ``Property`` WHERE ``Property`` = 'ProductCode'")
        $View.Execute(); $ProductCode = $View.Fetch().StringData(1); $View.Close()
        $View = $Database.OpenView("SELECT ``Argument`` FROM ``ControlEvent`` WHERE ``Dialog_`` = 'ExitDialog' AND ``Control_`` = 'Finish' AND ``Event`` = 'EndDialog'")
        $View.Execute(); $Record = $View.Fetch()
        Assert-Test 'Packaged MSI wires Finish to close' ($null -ne $Record -and $Record.StringData(1) -eq 'Return')
        $View.Close()
    } finally { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Database); [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Installer) }
    $Log = Join-Path $Output "$Scope-install.log"
    # Start in the opposite scope so the UI must update its already-costed target.
    $InitialScope = if ($Machine) { ' MSIINSTALLPERUSER=1' } else { '' }
    $Process = Start-Process msiexec.exe -ArgumentList "/i `"$Msi`" /norestart /l*v `"$Log`"$InitialScope" -PassThru
    $License = Wait-Control $Process 'I accept the terms in the License Agreement'
    [MdvuInstallerUI]::Click($License)
    $Checkbox = Wait-Control $Process 'Install for current user only (no administrator privileges needed)'
    if ([MdvuInstallerUI]::Checked($Checkbox) -ne (-not $Machine)) { [MdvuInstallerUI]::Click($Checkbox) }
    Assert-Test 'Installer selected requested scope' ([MdvuInstallerUI]::Checked($Checkbox) -eq (-not $Machine))
    $InstallStarted = $true
    [MdvuInstallerUI]::Click((Wait-Control $Process 'Install'))
    $Finish = Wait-Control $Process 'Finish'
    Assert-Test 'Successful installation shows Finish' (Test-Path $Exe)
    [MdvuInstallerUI]::Click($Finish)
    Assert-Test 'Finish closes installer' ($Process.WaitForExit(10000))
    Assert-Test 'Interactive MSI exit code' ($Process.ExitCode -in @(0,3010))
    Assert-Test 'Installed WebView2 loader' (Test-Path (Join-Path $Folder 'WebView2Loader.dll'))
    Assert-Test 'Installed binary matches release' ((Get-FileHash $Exe).Hash -eq (Get-FileHash 'dist/windows/mdvu.exe').Hash)
    Assert-Test 'Start Menu shortcut exists' (Test-Path $Shortcut)
    $Shell = New-Object -ComObject WScript.Shell
    $Link = $Shell.CreateShortcut($Shortcut)
    Assert-Test 'Shortcut points to installed executable' ($Link.TargetPath -eq $Exe)
    Assert-Test 'Shortcut working directory' ($Link.WorkingDirectory.TrimEnd('\') -eq $Folder.TrimEnd('\'))
    $Command = (Get-Item "$Hive\Software\Classes\MDVu.MarkdownDocument\shell\open\command").GetValue('')
    Assert-Test 'File association uses installed executable' ($Command -eq ('"' + $Exe + '" "%1"'))
    $Info = [Diagnostics.ProcessStartInfo]::new()
    $Info.FileName = $Exe; $Info.Arguments = '--version'; $Info.UseShellExecute = $false; $Info.RedirectStandardOutput = $true
    $CLI = [Diagnostics.Process]::Start($Info)
    try {
        $Text = $CLI.StandardOutput.ReadToEndAsync()
        Assert-Test 'Installed CLI runs' ($CLI.WaitForExit(10000) -and $CLI.ExitCode -eq 0 -and $Text.Result.Contains((Get-Content version.txt -Raw).Trim()))
    } finally { if (-not $CLI.HasExited) { $CLI.Kill() }; $CLI.Dispose() }
    $Launched = Start-Process $Shortcut -PassThru
    try {
        $Deadline = (Get-Date).AddSeconds(20)
        do { Start-Sleep -Milliseconds 100; $Launched.Refresh() } while (-not $Launched.HasExited -and $Launched.MainWindowHandle -eq [IntPtr]::Zero -and (Get-Date) -lt $Deadline)
        Assert-Test 'Start Menu shortcut opens native window' (-not $Launched.HasExited -and $Launched.MainWindowHandle -ne [IntPtr]::Zero)
    } finally { if (-not $Launched.HasExited) { $Launched.Kill(); $Launched.WaitForExit() }; $Launched.Dispose() }
    # Exercise a real render from the installed directory, including loader lookup.
    & "$PSScriptRoot/test-windows-gui.ps1" -Exe $Exe
    Invoke-Msi "/x $ProductCode /qn /norestart /l*v `"$(Join-Path $Output "$Scope-uninstall.log")`""
    $InstallStarted = $false
    Assert-Test 'Uninstall removes executable and shortcut' (-not (Test-Path $Exe) -and -not (Test-Path $Shortcut))
    Assert-Test 'Uninstall removes file association' (-not (Test-Path "$Hive\Software\Classes\MDVu.MarkdownDocument\shell\open\command"))
    $Report.passed = $true
} catch {
    $Report.error = $_.ToString()
    throw
} finally {
    if ($Process) { if (-not $Process.HasExited) { $Process.Kill() }; $Process.Dispose() }
    if ($InstallStarted -and $ProductCode) { Invoke-Msi "/x $ProductCode /qn /norestart /l*v `"$(Join-Path $Output "$Scope-cleanup.log")`"" }
    $Report | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Output "$Scope.json") -Encoding UTF8
    Stop-Transcript | Out-Null
}
