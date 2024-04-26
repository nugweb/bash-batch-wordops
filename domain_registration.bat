@echo off
setlocal enabledelayedexpansion

REM Default IP addresses
set "defaultWinIP=172.24.75.45"
set "defaultWSLIP=127.0.0.1"
set "hostsWinPath=%windir%\System32\drivers\etc\hosts"
set "hostsWSLPath=/etc/hosts"

REM Check for minimum arguments
if "%1"=="" goto usage
if "%2"=="" goto usage

REM Command variables
set "action=%1"
set "domain=%2"
set "winIP=%3"
set "wslIP=%4"

if "%winIP%"=="" set "winIP=%defaultWinIP%"
if "%wslIP%"=="" set "wslIP=%defaultWSLIP%"

REM Add domain
if /I "%action%"=="add" goto addDomain
REM Delete domain
if /I "%action%"=="delete" goto deleteDomain

:usage
echo Usage:
echo   %0 add [domain] [Windows IP] [WSL IP]
echo   %0 delete [domain]
goto end

:addDomain
echo Adding entries to Windows hosts file...
findstr /I /C:"%domain%" %hostsWinPath% >nul 2>&1 || (
    echo %winIP% %domain%>> %hostsWinPath%
    echo ::1 %domain%>> %hostsWinPath%
)
echo Adding entries to Ubuntu WSL hosts file...
wsl sudo sh -c "grep -q '%domain%' %hostsWSLPath% || echo '%wslIP% %domain%' >> %hostsWSLPath%"
wsl sudo sh -c "grep -q '%domain%' %hostsWSLPath% || echo '::1 %domain% localhost' >> %hostsWSLPath%"
goto end

:deleteDomain
echo Removing entries from Windows hosts file...
for /f "delims=" %%i in ('type %hostsWinPath% ^| findstr /I /V "%domain%"') do (
    set "line=%%i"
    echo !line!>> %hostsWinPath%.new
)
move /Y %hostsWinPath%.new %hostsWinPath% >nul
echo Removing entries from Ubuntu WSL hosts file...
wsl sudo sed -i '/%domain%/d' %hostsWSLPath%
goto end

:end
endlocal
