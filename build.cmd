@echo off
rem MDVu Windows Build Script Wrapper
setlocal
cd /d "%~dp0"

if "%1"=="help" goto :usage
if "%1"=="-h" goto :usage
if "%1"=="--help" goto :usage

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
exit /b %ERRORLEVEL%

:usage
echo Usage: build.cmd [app ^| release ^| debug ^| test ^| package ^| clean]
echo.
echo Commands:
echo   app        Build and package MDVu for Windows (default)
echo   release    Build optimized release binaries
echo   debug      Build unoptimized debug binaries
echo   test       Run Rust workspace tests
echo   package    Create distribution zip and sha256
echo   clean      Remove build artifacts and dist folder
exit /b 0
