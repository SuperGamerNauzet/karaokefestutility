@echo off
setlocal EnableExtensions EnableDelayedExpansion

title KaraokeFest Utility - Instalador

REM ============================================================
REM CARPETA DEL PROYECTO
REM ============================================================

set "BASE=%~dp0"
if "%BASE:~-1%"=="\" set "BASE=%BASE:~0,-1%"

echo.
echo ============================================================
echo       KARAOKEFEST UTILITY - INSTALADOR
echo ============================================================
echo.
echo Carpeta detectada:
echo %BASE%
echo.

REM ============================================================
REM COMPROBAR ARCHIVOS NECESARIOS
REM ============================================================

set "ERROR=0"

if not exist "%BASE%\instalar.bat" (
    echo [ERROR] Falta instalar.bat
    set "ERROR=1"
)

if not exist "%BASE%\desinstalar.bat" (
    echo [ERROR] Falta desinstalar.bat
    set "ERROR=1"
)

if not exist "%BASE%\servidor.py" (
    echo [ERROR] Falta servidor.py
    set "ERROR=1"
)

if "%ERROR%"=="1" (
    echo.
    echo ============================================================
    echo ERROR: Faltan archivos necesarios.
    echo ============================================================
    echo.
    echo Debes tener estos tres archivos juntos:
    echo.
    echo   instalar.bat
    echo   desinstalar.bat
    echo   servidor.py
    echo.
    pause
    exit /b 1
)

echo [OK] instalar.bat encontrado.
echo [OK] desinstalar.bat encontrado.
echo [OK] servidor.py encontrado.
echo.

REM ============================================================
REM CARPETAS
REM ============================================================

set "PYTHON_DIR=%BASE%\python"
set "PAQUETES_DIR=%BASE%\paquetes"
set "FFMPEG_DIR=%BASE%\ffmpeg"

if not exist "%PYTHON_DIR%" mkdir "%PYTHON_DIR%"
if not exist "%PAQUETES_DIR%" mkdir "%PAQUETES_DIR%"
if not exist "%FFMPEG_DIR%" mkdir "%FFMPEG_DIR%"

REM ============================================================
REM DESCARGAS TEMPORALES
REM ============================================================

set "TEMP_DIR=%TEMP%\KaraokeFestUtility"

if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%" >nul 2>&1
mkdir "%TEMP_DIR%"

REM ============================================================
REM PYTHON PORTABLE
REM ============================================================

echo.
echo ============================================================
echo INSTALANDO PYTHON PORTABLE
echo ============================================================
echo.

set "PYTHON_ZIP=%TEMP_DIR%\python.zip"

echo Descargando Python Portable...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.14.7/python-3.14.7-embed-amd64.zip' -OutFile '%PYTHON_ZIP%'"

if not exist "%PYTHON_ZIP%" (
    echo.
    echo [ERROR] No se pudo descargar Python Portable.
    pause
    exit /b 1
)

echo [OK] Python descargado.
echo.

echo Extrayendo Python...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"Expand-Archive -LiteralPath '%PYTHON_ZIP%' -DestinationPath '%PYTHON_DIR%' -Force"

if not exist "%PYTHON_DIR%\python.exe" (
    echo.
    echo [ERROR] No se encontro python.exe.
    pause
    exit /b 1
)

echo [OK] Python Portable instalado.
echo.

REM ============================================================
REM CONFIGURAR PYTHON EMBEBIDO
REM ============================================================

echo Configurando Python Portable...

set "PTH_FILE="

for %%F in ("%PYTHON_DIR%\python*._pth") do (
    set "PTH_FILE=%%~fF"
)

if not defined PTH_FILE (
    echo.
    echo [ERROR] No se encontro el archivo _pth de Python.
    pause
    exit /b 1
)

(
    echo python314.zip
    echo .
    echo %PAQUETES_DIR%
    echo import site
) > "%PTH_FILE%"

echo [OK] Python configurado.
echo.

REM ============================================================
REM INSTALAR PIP
REM ============================================================

echo.
echo ============================================================
echo INSTALANDO PIP
echo ============================================================
echo.

set "GETPIP=%TEMP_DIR%\get-pip.py"

echo Descargando get-pip.py...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri 'https://bootstrap.pypa.io/get-pip.py' -OutFile '%GETPIP%'"

if not exist "%GETPIP%" (
    echo.
    echo [ERROR] No se pudo descargar get-pip.py.
    pause
    exit /b 1
)

echo Instalando pip...

"%PYTHON_DIR%\python.exe" "%GETPIP%" --no-warn-script-location

if errorlevel 1 (
    echo.
    echo [ERROR] No se pudo instalar pip.
    pause
    exit /b 1
)

echo [OK] pip instalado.
echo.

REM ============================================================
REM PAQUETES PYTHON
REM ============================================================

echo.
echo ============================================================
echo INSTALANDO PAQUETES
echo ============================================================
echo.

echo Instalando Flask...
"%PYTHON_DIR%\python.exe" -m pip install Flask --target "%PAQUETES_DIR%" --upgrade

if errorlevel 1 (
    echo.
    echo [ERROR] Fallo instalando Flask.
    pause
    exit /b 1
)

echo.
echo Instalando Flask-CORS...
"%PYTHON_DIR%\python.exe" -m pip install flask-cors --target "%PAQUETES_DIR%" --upgrade

if errorlevel 1 (
    echo.
    echo [ERROR] Fallo instalando flask-cors.
    pause
    exit /b 1
)

echo.
echo Instalando yt-dlp...
"%PYTHON_DIR%\python.exe" -m pip install yt-dlp --target "%PAQUETES_DIR%" --upgrade

if errorlevel 1 (
    echo.
    echo [ERROR] Fallo instalando yt-dlp.
    pause
    exit /b 1
)

echo.
echo [OK] Paquetes instalados.
echo.

REM ============================================================
REM FFMPEG
REM ============================================================

echo.
echo ============================================================
echo INSTALANDO FFMPEG
echo ============================================================
echo.

set "FFMPEG_ZIP=%TEMP_DIR%\ffmpeg.zip"
set "FFMPEG_EXTRACT=%TEMP_DIR%\ffmpeg_extract"

echo Descargando FFmpeg...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile '%FFMPEG_ZIP%'"

if not exist "%FFMPEG_ZIP%" (
    echo.
    echo [ERROR] No se pudo descargar FFmpeg.
    pause
    exit /b 1
)

echo Extrayendo FFmpeg...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"Expand-Archive -LiteralPath '%FFMPEG_ZIP%' -DestinationPath '%FFMPEG_EXTRACT%' -Force"

if not exist "%FFMPEG_EXTRACT%" (
    echo.
    echo [ERROR] No se pudo extraer FFmpeg.
    pause
    exit /b 1
)

echo Copiando FFmpeg...

for /r "%FFMPEG_EXTRACT%" %%F in (ffmpeg.exe) do (
    if not exist "%FFMPEG_DIR%\ffmpeg.exe" copy /y "%%F" "%FFMPEG_DIR%\ffmpeg.exe" >nul
)

for /r "%FFMPEG_EXTRACT%" %%F in (ffprobe.exe) do (
    if not exist "%FFMPEG_DIR%\ffprobe.exe" copy /y "%%F" "%FFMPEG_DIR%\ffprobe.exe" >nul
)

for /r "%FFMPEG_EXTRACT%" %%F in (ffplay.exe) do (
    if not exist "%FFMPEG_DIR%\ffplay.exe" copy /y "%%F" "%FFMPEG_DIR%\ffplay.exe" >nul
)

if not exist "%FFMPEG_DIR%\ffmpeg.exe" (
    echo.
    echo [ERROR] No se encontro ffmpeg.exe.
    pause
    exit /b 1
)

if not exist "%FFMPEG_DIR%\ffprobe.exe" (
    echo.
    echo [ERROR] No se encontro ffprobe.exe.
    pause
    exit /b 1
)

echo [OK] FFmpeg instalado.
echo [OK] FFprobe instalado.
echo.

REM ============================================================
REM LIMPIAR TEMPORAL
REM ============================================================

if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%" >nul 2>&1

REM ============================================================
REM COMPROBACION FINAL
REM ============================================================

echo.
echo ============================================================
echo COMPROBACION FINAL
echo ============================================================
echo.

if exist "%PYTHON_DIR%\python.exe" (
    echo [OK] Python Portable
) else (
    echo [ERROR] Python Portable
)

if exist "%PAQUETES_DIR%\flask" (
    echo [OK] Flask
) else (
    echo [ERROR] Flask
)

if exist "%PAQUETES_DIR%\flask_cors" (
    echo [OK] Flask-CORS
) else (
    echo [ERROR] Flask-CORS
)

if exist "%PAQUETES_DIR%\yt_dlp" (
    echo [OK] yt-dlp
) else (
    echo [ERROR] yt-dlp
)

if exist "%FFMPEG_DIR%\ffmpeg.exe" (
    echo [OK] FFmpeg
) else (
    echo [ERROR] FFmpeg
)

if exist "%FFMPEG_DIR%\ffprobe.exe" (
    echo [OK] FFprobe
) else (
    echo [ERROR] FFprobe
)

echo.
echo ============================================================
echo INSTALACION TERMINADA
echo ============================================================
echo.
echo Todo se ha instalado dentro de:
echo.
echo %BASE%
echo.
echo Ahora puedes hacer doble clic en:
echo.
echo   servidor.py
echo.
echo para iniciar el servidor.
echo.

pause
exit /b 0
