@echo off
setlocal
set "ROOT=%~dp0"
set "LOVE_EXE=C:\Program Files\LOVE\love.exe"
if not exist "%LOVE_EXE%" set "LOVE_EXE=C:\Program Files (x86)\LOVE\love.exe"
set "LOVE_OUT=%ROOT%zombie-round.love"
set "ZIP_OUT=%ROOT%zombie-round.zip"
set "EXE_OUT=%ROOT%zombie-round.exe"

if not exist "%LOVE_EXE%" (
    echo Love2D was not found at the default install path.
    echo Install Love2D from https://love2d.org/ and try again.
    exit /b 1
)

if exist "%ZIP_OUT%" del /f /q "%ZIP_OUT%"
if exist "%LOVE_OUT%" del /f /q "%LOVE_OUT%"
if exist "%EXE_OUT%" del /f /q "%EXE_OUT%"

powershell -NoLogo -NoProfile -Command "$items = Get-ChildItem -Path '%ROOT%' -Force | Where-Object { $_.Name -notin @('.git','.gitignore','build-love.bat','run-game.bat','zombie-round.zip','zombie-round.love','zombie-round.exe') }; if ($items.Count -gt 0) { Compress-Archive -Path $items.FullName -DestinationPath '%ZIP_OUT%' -Force } else { Write-Error 'No files to package.'; exit 1 }"

if exist "%ZIP_OUT%" (
    ren "%ZIP_OUT%" "zombie-round.love"
)

if exist "%LOVE_OUT%" (
    copy /b "%LOVE_EXE%" + "%LOVE_OUT%" "%EXE_OUT%" >nul
    if exist "%EXE_OUT%" (
        echo Created %LOVE_OUT%
        echo Created %EXE_OUT%
    ) else (
        echo Failed to create .exe wrapper.
        exit /b 1
    )
) else (
    echo Failed to create .love package.
    exit /b 1
)
