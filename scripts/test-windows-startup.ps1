# Check the real, document-free native window, including its non-client frame.
param(
    [string]$Exe = 'dist/windows/mdvu.exe',
    [string]$Output = 'test-results/windows-startup',
    [switch]$CaptureScreenshot
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path $Exe).Path
$Output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)
New-Item -ItemType Directory -Force $Output | Out-Null
if (-not ('MdvuStartupFrame' -as [type])) { Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class MdvuStartupFrame {
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
 [StructLayout(LayoutKind.Sequential)] public struct TITLEBARINFO {
  public uint cbSize; public RECT rect;
  [MarshalAs(UnmanagedType.ByValArray, SizeConst=6)] public uint[] states;
 }
 [DllImport("user32.dll")] public static extern bool GetTitleBarInfo(IntPtr window, ref TITLEBARINFO info);
 [DllImport("user32.dll", EntryPoint="GetWindowLongW")] public static extern uint GetStyle(IntPtr window, int index);
 [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr window, uint attribute, out int value, int size);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out RECT rect);
 [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindow callback, IntPtr data);
 delegate bool EnumWindow(IntPtr window, IntPtr data);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
 [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
 [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);
 [DllImport("user32.dll")] public static extern IntPtr SendMessageW(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);
 [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr window);
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr window);
 [DllImport("user32.dll")] public static extern IntPtr GetSystemMenu(IntPtr window, bool revert);
 [DllImport("user32.dll")] public static extern uint GetMenuState(IntPtr menu, uint item, uint flags);
 public static IntPtr FindCaptionWindow(int process) {
  IntPtr found = IntPtr.Zero;
  EnumWindows((window, data) => {
   uint owner; GetWindowThreadProcessId(window, out owner);
   if (owner == process && IsWindowVisible(window) && (GetStyle(window,-16) & 0xC00000) == 0xC00000) {
    found = window; return false;
   }
   return true;
  }, IntPtr.Zero);
  return found;
 }
}
'@
}
$OldProfile = $env:WEBVIEW2_USER_DATA_FOLDER
$OldUIScript = $env:MDVU_UI_SCRIPT
$OldUIResult = $env:MDVU_UI_RESULT_FILE
$Report = @()
# A private copy proves that the runtime does not create <exe>.WebView2 beside a portable EXE.
$Portable = Join-Path $Output 'portable'
New-Item -ItemType Directory -Force $Portable | Out-Null
$TestExe = Join-Path $Portable 'mdvu.exe'
Copy-Item $Exe $TestExe -Force
$Loader = Join-Path (Split-Path $Exe -Parent) 'WebView2Loader.dll'
if (Test-Path $Loader) { Copy-Item $Loader $Portable -Force }
try {
 Remove-Item Env:WEBVIEW2_USER_DATA_FOLDER,Env:MDVU_UI_SCRIPT,Env:MDVU_UI_RESULT_FILE -ErrorAction SilentlyContinue
 foreach ($Theme in @('system','light','dark')) {
  $Window = [IntPtr]::Zero
  $Process = Start-Process $TestExe -ArgumentList @('--theme',$Theme) -PassThru
  try {
   $Watch = [Diagnostics.Stopwatch]::StartNew()
   do {
    Start-Sleep -Milliseconds 100; $Process.Refresh()
    $Window = [MdvuStartupFrame]::FindCaptionWindow($Process.Id)
   } while (-not $Process.HasExited -and $Window -eq [IntPtr]::Zero -and $Watch.Elapsed.TotalSeconds -lt 15)
   if ($Process.HasExited -or $Window -eq [IntPtr]::Zero) { throw "No startup window: $Theme" }
   $ProfilePath = Join-Path $env:LOCALAPPDATA 'MDVu\WebView2\EBWebView'
   # The responsive native frame appears before WebView2's first environment is
   # ready. A fresh CI account can take several seconds to create its profile.
   while (-not (Test-Path $ProfilePath) -and -not $Process.HasExited -and $Watch.Elapsed.TotalSeconds -lt 30) {
    Start-Sleep -Milliseconds 100; $Process.Refresh()
   }
   Start-Sleep -Milliseconds 1200
   $Frame = [MdvuStartupFrame+TITLEBARINFO]::new()
   $Frame.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($Frame)
   $Frame.states = [uint32[]]::new(6)
   if (-not [MdvuStartupFrame]::GetTitleBarInfo($Window,[ref]$Frame)) { throw 'GetTitleBarInfo failed' }
   $Style = [MdvuStartupFrame]::GetStyle($Window,-16)
   # WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX.
   if (($Style -band 0xCF0000) -ne 0xCF0000) { throw "Missing native caption styles: $Theme ($Style)" }
   foreach ($Index in @(2,3,5)) {
    # STATE_SYSTEM_INVISIBLE | STATE_SYSTEM_OFFSCREEN | STATE_SYSTEM_UNAVAILABLE.
    if (($Frame.states[$Index] -band 0x18001) -ne 0) { throw "Caption button $Index unavailable: $Theme" }
   }
   # Exercise the real subclass chain, not just the presence of caption styles.
   # WM_NCLBUTTONDBLCLK / HTCAPTION must reach DefWindowProc via Tao.
   $OriginalRect = [MdvuStartupFrame+RECT]::new()
   if (-not [MdvuStartupFrame]::GetWindowRect($Window,[ref]$OriginalRect)) { throw 'GetWindowRect failed' }
   $CaptionX = [int](($Frame.rect.Left + $Frame.rect.Right) / 2)
   $CaptionY = [int](($Frame.rect.Top + $Frame.rect.Bottom) / 2)
   $CaptionPoint = [IntPtr](($CaptionX -band 0xFFFF) -bor (($CaptionY -band 0xFFFF) -shl 16))
   $Hit = [MdvuStartupFrame]::SendMessageW($Window,0x84,[IntPtr]::Zero,$CaptionPoint)
   if ($Hit.ToInt64() -ne 2) { throw "Title bar is not a native drag region: $Theme" }
   [void][MdvuStartupFrame]::SendMessageW($Window,0xA3,[IntPtr]2,$CaptionPoint)
   if (-not [MdvuStartupFrame]::IsZoomed($Window)) { throw "Title bar double-click did not maximize: $Theme" }
   [void][MdvuStartupFrame]::SendMessageW($Window,0xA3,[IntPtr]2,$CaptionPoint)
   if ([MdvuStartupFrame]::IsZoomed($Window)) { throw "Title bar double-click did not restore: $Theme" }
   $RestoredRect = [MdvuStartupFrame+RECT]::new()
   if (-not [MdvuStartupFrame]::GetWindowRect($Window,[ref]$RestoredRect)) { throw 'GetWindowRect failed after restore' }
   if ($OriginalRect.Left -ne $RestoredRect.Left -or $OriginalRect.Top -ne $RestoredRect.Top -or
       $OriginalRect.Right -ne $RestoredRect.Right -or $OriginalRect.Bottom -ne $RestoredRect.Bottom) {
    throw "Maximize/restore changed the normal window bounds: $Theme"
   }
   $SystemMenu = [MdvuStartupFrame]::GetSystemMenu($Window,$false)
   foreach ($Command in @(0xF010,0xF000,0xF020,0xF030,0xF060)) { # Move, Size, Minimize, Maximize, Close
    $MenuState = [MdvuStartupFrame]::GetMenuState($SystemMenu,$Command,0)
    if ($MenuState -eq [uint32]::MaxValue -or ($MenuState -band 3) -ne 0) { throw "System window command unavailable: $Theme ($Command)" }
   }
   [void][MdvuStartupFrame]::SendMessageW($Window,0x112,[IntPtr]0xF020,[IntPtr]::Zero)
   if (-not [MdvuStartupFrame]::IsIconic($Window)) { throw "System minimize failed: $Theme" }
   [void][MdvuStartupFrame]::SendMessageW($Window,0x112,[IntPtr]0xF120,[IntPtr]::Zero)
   if ([MdvuStartupFrame]::IsIconic($Window)) { throw "System restore failed: $Theme" }
   $Dark = 0
   $DwmResult = [MdvuStartupFrame]::DwmGetWindowAttribute($Window,20,[ref]$Dark,4)
   $ExpectedDark = switch ($Theme) {
    'light' { 0 }
    'dark' { 1 }
    default { [int]((Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -ErrorAction SilentlyContinue).AppsUseLightTheme -eq 0) }
   }
   if ($DwmResult -eq 0 -and $Dark -ne $ExpectedDark) { throw "Native caption theme mismatch: $Theme ($Dark != $ExpectedDark)" }
   if (Test-Path ($TestExe+'.WebView2')) { throw 'WebView2 profile created beside the executable' }
   if (-not (Test-Path $ProfilePath)) { throw 'WebView2 profile missing from LocalAppData' }
   if ($CaptureScreenshot) {
    Add-Type -AssemblyName System.Drawing
    $Rect = [MdvuStartupFrame+RECT]::new()
    if ([MdvuStartupFrame]::GetWindowRect($Window,[ref]$Rect)) {
     $Image = [Drawing.Bitmap]::new($Rect.Right-$Rect.Left,$Rect.Bottom-$Rect.Top)
     $Graphics = [Drawing.Graphics]::FromImage($Image)
     try { $Graphics.CopyFromScreen($Rect.Left,$Rect.Top,0,0,$Image.Size); $Image.Save((Join-Path $Output ($Theme+'.png'))) }
     finally { $Graphics.Dispose(); $Image.Dispose() }
    }
   }
   $Report += @{theme=$Theme;darkCaption=$Dark;dwmResult=$DwmResult;styles=$Style;buttonStates=$Frame.states;nativeCaptionHitTest=$true;doubleClickMaximizeRestore=$true;systemMenuCommands=$true;minimizeRestore=$true;passed=$true}
  } finally {
   $Process.Refresh()
   if (-not $Process.HasExited) {
    if ($Window -ne [IntPtr]::Zero) { [void][MdvuStartupFrame]::PostMessageW($Window,0x10,[IntPtr]::Zero,[IntPtr]::Zero) }
    if (-not $Process.WaitForExit(5000)) { $Process.Kill(); $Process.WaitForExit() }
   }
   $Process.Dispose()
  }
 }
} finally {
 $env:WEBVIEW2_USER_DATA_FOLDER = $OldProfile
 $env:MDVU_UI_SCRIPT = $OldUIScript
 $env:MDVU_UI_RESULT_FILE = $OldUIResult
 Remove-Item $Portable -Recurse -Force
 ConvertTo-Json -InputObject $Report -Depth 5 | Set-Content (Join-Path $Output 'results.json') -Encoding UTF8
}
