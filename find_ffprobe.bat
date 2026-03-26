@echo off
REM Script para encontrar ffprobe.exe en Windows

REM Ubicaciones comunes
set "paths=C:\ffmpeg\bin\ffprobe.exe"
set "paths=%paths%;C:\Program Files\ffmpeg\bin\ffprobe.exe"
set "paths=%paths%;C:\Program Files (x86)\ffmpeg\bin\ffprobe.exe"
set "paths=%paths%;C:\ProgramData\chocolatey\lib\ffmpeg\tools\bin\ffprobe.exe"
set "paths=%paths%;C:\ProgramData\chocolatey\bin\ffprobe.exe"

REM Buscar en cada ruta
for %%P in (%paths%) do (
    if exist "%%P" (
        echo %%P
        exit /b 0
    )
)

REM Si no encontró, intentar with where command
where ffprobe.exe >nul 2>&1
if %errorlevel% equ 0 (
    for /f "delims=" %%P in ('where ffprobe.exe 2^>nul') do (
        echo %%P
        exit /b 0
    )
)

REM No encontrado
exit /b 1
