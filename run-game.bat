@echo off
setlocal

set "LOVE_EXE="
if exist "C:\Program Files\LOVE\love.exe" set "LOVE_EXE=C:\Program Files\LOVE\love.exe"
if exist "C:\Program Files (x86)\LOVE\love.exe" set "LOVE_EXE=C:\Program Files (x86)\LOVE\love.exe"

if not defined LOVE_EXE (
    where love >nul 2>nul
    if not errorlevel 1 (
        for /f "delims=" %%I in ('where love') do set "LOVE_EXE=%%I"
    )
)

if not defined LOVE_EXE (
    echo Love2D was not found.
    echo Install it from https://love2d.org/
    echo then run this script again or add the install folder to PATH.
    pause
    exit /b 1
)

"%LOVE_EXE%" "%~dp0"
