# Invoke over SSH. The named account must already have an interactive desktop session.
param([string]$User = "$env:USERDOMAIN\$env:USERNAME", [string]$Exe = "dist/windows/mdvu.exe")
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Runner = Join-Path $PSScriptRoot 'test-windows-system.ps1'
$Name = 'MDVu-Test-' + [Guid]::NewGuid().ToString('N')
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -File `"$Runner`" -Exe `"$Exe`"" -WorkingDirectory $Root
$Principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Limited
$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 15)
try {
    Register-ScheduledTask -TaskName $Name -Action $Action -Principal $Principal -Settings $Settings | Out-Null
    $Started = Get-Date
    Start-ScheduledTask $Name
    $Deadline = (Get-Date).AddMinutes(15)
    do {
        Start-Sleep -Seconds 2
        $State = (Get-ScheduledTask $Name).State
        $Info = Get-ScheduledTaskInfo $Name
    } while (($State -eq 'Running' -or $Info.LastRunTime -lt $Started.AddSeconds(-1)) -and (Get-Date) -lt $Deadline)
    if ($State -eq 'Running') { Stop-ScheduledTask $Name; throw 'Interactive test timed out' }
    if ($Info.LastTaskResult -ne 0) { throw "Interactive test failed: $($Info.LastTaskResult). Inspect test-results/windows/run.log" }
} finally { Unregister-ScheduledTask $Name -Confirm:$false -ErrorAction SilentlyContinue }
