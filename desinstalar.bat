@echo off
setlocal EnableExtensions

title KaraokeFest Utility - Desinstalador

set "BASE=%~dp0"
if "%BASE:~-1%"=="\" set "BASE=%BASE:~0,-1%"

echo.
echo ============================================================
echo       KARAOKEFEST UTILITY - DESINSTALADOR
echo ============================================================
echo.
echo Carpeta detectada:
echo %BASE%
echo.

if not exist "%BASE%\servidor.py" (
    echo [ERROR] No se encontro servidor.py.
    echo.
    echo Este no parece ser el directorio de KaraokeFest Utility.
    echo.
    pause
    exit /b 1
)

echo Se eliminaran UNICAMENTE:
echo.
echo   %BASE%\python
echo   %BASE%\paquetes
echo   %BASE%\ffmpeg
echo.
echo Los siguientes archivos NO se eliminaran:
echo.
echo   servidor.py
echo   instalar.bat
echo   desinstalar.bat
echo.

choice /C SN /N /M "Continuar con la desinstalacion? [S/N]: "

if errorlevel 2 (
    echo.
    echo Desinstalacion cancelada.
    pause
    exit /b 0
)

echo.
echo Eliminando Python Portable...

if exist "%BASE%\python" (
    rmdir /s /q "%BASE%\python"
)

echo Eliminando paquetes...

if exist "%BASE%\paquetes" (
    rmdir /s /q "%BASE%\paquetes"
)

echo Eliminando FFmpeg...

if exist "%BASE%\ffmpeg" (
    rmdir /s /q "%BASE%\ffmpeg"
)

echo.
echo ============================================================
echo DESINSTALACION TERMINADA
echo ============================================================
echo.
echo Se han eliminado solamente los componentes instalados
echo por KaraokeFest Utility.
echo.
echo servidor.py, instalar.bat y desinstalar.bat se mantienen.
echo.

pause
exit /b 0
