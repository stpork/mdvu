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
    # Hosted runners may disable UAC, leaving even a "Limited" administrator
    # token elevated. Use a disposable standard account and stage public test
    # inputs outside the invoking user's private profile instead.
    $Name = 'MDVuTest-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
    $Stage = Join-Path $env:ProgramData $Name
    $Password = [Guid]::NewGuid().ToString('N') + 'aA1!'
    $User = New-LocalUser -Name $Name -Password (ConvertTo-SecureString $Password -AsPlainText -Force) -AccountExpires (Get-Date).AddHours(1) -Description 'Temporary MDVu MSI regression account'
    $UserOutput = Join-Path $Stage 'test-results'
    try {
        Add-LocalGroupMember -SID 'S-1-5-32-545' -Member $User
        New-Item -ItemType Directory -Force $Stage | Out-Null
        & icacls.exe $Stage /grant "*$($User.SID.Value):(OI)(CI)F" | Out-Null
        if ($LASTEXITCODE) { throw 'Cannot grant test account access to its staging directory' }
        foreach ($File in @('scripts/test-windows-installer.ps1','scripts/test-windows-gui.ps1','tests/fixtures/diagram.png','dist/windows/mdvu.exe','version.txt')) {
            $Target = Join-Path $Stage $File
            New-Item -ItemType Directory -Force (Split-Path $Target -Parent) | Out-Null
            Copy-Item $File $Target
        }
        Copy-Item $Msi (Join-Path $Stage 'package.msi')
        # A caller may use a private, per-user fixed WebView2 runtime (e.g. Scoop).
        # Stage that explicit dependency so both accounts exercise the same engine.
        if ($env:WEBVIEW2_BROWSER_EXECUTABLE_FOLDER) {
            $Runtime = New-Item -ItemType Directory (Join-Path $Stage 'webview2')
            Get-ChildItem -LiteralPath $env:WEBVIEW2_BROWSER_EXECUTABLE_FOLDER | Copy-Item -Destination $Runtime.FullName -Recurse
        }
        # CreateProcessWithLogon loads the standard user's profile and avoids
        # Task Scheduler's separate "Log on as a batch job" security policy.
        @'
$ErrorActionPreference = 'Stop'
# Secondary logon inherits the caller's environment even with LoadUserProfile.
# Resolve this fresh account's profile by its token SID before expanding paths.
$Sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$env:USERPROFILE = Get-ItemPropertyValue "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$Sid" -Name ProfileImagePath
$env:LOCALAPPDATA = Join-Path $env:USERPROFILE 'AppData\Local'
$env:APPDATA = Join-Path $env:USERPROFILE 'AppData\Roaming'
$env:TEMP = Join-Path $env:LOCALAPPDATA 'Temp'
$env:TMP = $env:TEMP
Remove-Item Env:WEBVIEW2_USER_DATA_FOLDER,Env:MDVU_CACHE_DIR,Env:MDVU_UI_SCRIPT,Env:MDVU_UI_RESULT_FILE -ErrorAction SilentlyContinue
if (Test-Path "$PSScriptRoot/webview2/msedgewebview2.exe") { $env:WEBVIEW2_BROWSER_EXECUTABLE_FOLDER = "$PSScriptRoot/webview2" }
New-Item -ItemType Directory -Force $env:TEMP | Out-Null
& "$PSScriptRoot/scripts/test-windows-installer.ps1" -Msi "$PSScriptRoot/package.msi" -Scope User -Output "$PSScriptRoot/test-results"
'@ | Set-Content (Join-Path $Stage 'user-test.ps1')
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Stage/user-test.ps1`""
        $Credential = [Management.Automation.PSCredential]::new("$env:COMPUTERNAME\$Name", (ConvertTo-SecureString $Password -AsPlainText -Force))
        New-Item -ItemType Directory -Force $UserOutput | Out-Null
        $Child = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $Arguments -Credential $Credential -LoadUserProfile -WorkingDirectory $Stage -RedirectStandardOutput "$UserOutput/launcher.log" -RedirectStandardError "$UserOutput/launcher-error.log" -PassThru
        try {
            if (-not $Child.WaitForExit(180000)) { $Child.Kill(); throw 'Non-admin MSI test timed out' }
        } finally { $Child.Dispose() }
        if (-not (Test-Path "$UserOutput/User.json")) { throw "Standard-user test did not produce a report: $(Get-Content "$UserOutput/launcher-error.log" -Raw)" }
        $ChildReport = Get-Content (Join-Path $UserOutput 'User.json') -Raw | ConvertFrom-Json
        if (-not $ChildReport.passed -or $ChildReport.elevated) { throw 'Non-admin MSI verification did not pass' }
        Write-Host 'MSI: machine/admin and user/non-admin install, Finish, shortcut, launch and uninstall passed.'
    } finally {
        if (Test-Path $UserOutput) { Copy-Item (Join-Path $UserOutput '*') $Output -Force }
        Get-CimInstance Win32_UserProfile -Filter "SID='$($User.SID.Value)'" | Remove-CimInstance
        Remove-LocalUser -Name $Name
        Remove-Item $Stage -Recurse -Force -ErrorAction SilentlyContinue
    }
    return
}

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
$Report.installFolder = $Folder
$Report.shortcut = $Shortcut
$Hive = if ($Machine) { 'HKLM:' } else { 'HKCU:' }
$ScopeProperties = if ($Machine) { 'ALLUSERS=1 MSIINSTALLPERUSER=""' } else { 'ALLUSERS="" MSIINSTALLPERUSER=1' }
$ProductCode = $null
$Process = $null
$InstallStarted = $false
try {
    Assert-Test 'Installer token matches scope' ($IsAdmin -eq $Machine)
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
        Assert-Test 'Product is not already registered' ($Installer.ProductState($ProductCode) -eq -1)
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
    Invoke-Msi "/x $ProductCode $ScopeProperties /qn /norestart /l*v `"$(Join-Path $Output "$Scope-uninstall.log")`""
    $InstallStarted = $false
    $Installer = New-Object -ComObject WindowsInstaller.Installer
    try { Assert-Test 'Uninstall removes product registration' ($Installer.ProductState($ProductCode) -eq -1) } finally { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($Installer) }
    Assert-Test 'Uninstall removes executable and shortcut' (-not (Test-Path $Exe) -and -not (Test-Path $Shortcut))
    Assert-Test 'Uninstall removes file association' (-not (Test-Path "$Hive\Software\Classes\MDVu.MarkdownDocument\shell\open\command"))
    $Report.passed = $true
} catch {
    $Report.error = $_.ToString()
    throw
} finally {
    if ($Process) { if (-not $Process.HasExited) { $Process.Kill() }; $Process.Dispose() }
    if ($InstallStarted -and $ProductCode) { Invoke-Msi "/x $ProductCode $ScopeProperties /qn /norestart /l*v `"$(Join-Path $Output "$Scope-cleanup.log")`"" }
    $Report | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Output "$Scope.json") -Encoding UTF8
    Stop-Transcript | Out-Null
}
