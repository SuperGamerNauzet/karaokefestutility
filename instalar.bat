@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Instalador - KaraokeFest Utility

echo.
echo ============================================================
echo          KARAOKEFEST UTILITY - INSTALADOR
echo ============================================================
echo.
echo Este instalador NO necesita permisos de administrador.
echo.
echo Selecciona la carpeta donde quieres instalar
echo KaraokeFest Utility.
echo.
pause

:: ============================================================
:: COMPROBAR POWERSHELL
:: ============================================================

where powershell.exe >nul 2>&1

if errorlevel 1 (
    echo.
    echo ERROR: No se encontro PowerShell.
    echo.
    pause
    exit /b 1
)

:: ============================================================
:: CREAR ARCHIVO TEMPORAL PARA EL SELECTOR
:: ============================================================

set "SELECCION=%TEMP%\karaokefest_seleccion_%RANDOM%.txt"

if exist "%SELECCION%" del /f /q "%SELECCION%" >nul 2>&1

:: ============================================================
:: SELECTOR DE CARPETA
:: ============================================================

echo.
echo Abriendo selector de carpeta...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"Add-Type -AssemblyName System.Windows.Forms; ^
$dialog = New-Object System.Windows.Forms.FolderBrowserDialog; ^
$dialog.Description = 'Selecciona la carpeta donde instalar KaraokeFest Utility'; ^
$dialog.ShowNewFolderButton = $true; ^
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { ^
    [System.IO.File]::WriteAllText('%SELECCION%', $dialog.SelectedPath) ^
}"

if not exist "%SELECCION%" (
    echo.
    echo No se selecciono ninguna carpeta.
    echo Instalacion cancelada.
    echo.
    pause
    exit /b 0
)

set /p "BASE=<%SELECCION%"

del /f /q "%SELECCION%" >nul 2>&1

if "%BASE%"=="" (
    echo.
    echo No se selecciono ninguna carpeta.
    echo.
    pause
    exit /b 1
)

:: ============================================================
:: CARPETA FINAL
:: ============================================================

set "DESTINO=%BASE%\karaokefestutility"

echo.
echo ============================================================
echo Carpeta seleccionada:
echo.
echo %BASE%
echo.
echo La instalacion se realizara en:
echo.
echo %DESTINO%
echo ============================================================
echo.

if exist "%DESTINO%" (
    echo ATENCION:
    echo La carpeta ya existe.
    echo.
    choice /C SN /N /M "Quieres continuar y reutilizarla? [S/N]: "

    if errorlevel 2 (
        echo.
        echo Instalacion cancelada.
        pause
        exit /b 0
    )
)

:: ============================================================
:: COMPROBAR SERVIDOR.PY
:: ============================================================

if not exist "%~dp0servidor.py" (
    echo.
    echo ERROR:
    echo No se encontro servidor.py junto a instalar.bat.
    echo.
    echo Coloca:
    echo.
    echo     instalar.bat
    echo     desinstalar.bat
    echo     servidor.py
    echo.
    echo en la misma carpeta.
    echo.
    pause
    exit /b 1
)

:: ============================================================
:: CREAR CARPETAS
:: ============================================================

echo.
echo [1/7] Creando carpetas...

mkdir "%DESTINO%" >nul 2>&1
mkdir "%DESTINO%\python" >nul 2>&1
mkdir "%DESTINO%\ffmpeg" >nul 2>&1
mkdir "%DESTINO%\paquetes" >nul 2>&1
mkdir "%DESTINO%\musica" >nul 2>&1
mkdir "%DESTINO%\videos" >nul 2>&1

:: ============================================================
:: DESCARGAR PYTHON PORTABLE
:: ============================================================

echo.
echo [2/7] Descargando Python portable...
echo.
echo Esto puede tardar un poco.

set "PYTHON_ZIP=%TEMP%\karaokefest_python_%RANDOM%.zip"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.14.7/python-3.14.7-embed-amd64.zip' -OutFile '%PYTHON_ZIP%'"

if errorlevel 1 (
    echo.
    echo ERROR descargando Python.
    echo.
    pause
    exit /b 1
)

echo.
echo Extrayendo Python...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"Expand-Archive -LiteralPath '%PYTHON_ZIP%' -DestinationPath '%DESTINO%\python' -Force"

if errorlevel 1 (
    echo.
    echo ERROR extrayendo Python.
    echo.
    pause
    exit /b 1
)

del /f /q "%PYTHON_ZIP%" >nul 2>&1

:: ============================================================
:: CONFIGURAR PYTHON EMBEBIDO
:: ============================================================

echo.
echo Configurando Python portable...

set "PTH="

for %%F in ("%DESTINO%\python\*_pth") do (
    set "PTH=%%~fF"
)

if not defined PTH (
    echo.
    echo ERROR:
    echo No se encontro el archivo _pth de Python.
    echo.
    pause
    exit /b 1
)

>>"%PTH%" echo Lib\site-packages
>>"%PTH%" echo import site

mkdir "%DESTINO%\python\Lib\site-packages" >nul 2>&1

:: ============================================================
:: DESCARGAR GET-PIP
:: ============================================================

echo.
echo [3/7] Preparando pip...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"Invoke-WebRequest -Uri 'https://bootstrap.pypa.io/get-pip.py' -OutFile '%DESTINO%\python\get-pip.py'"

if errorlevel 1 (
    echo.
    echo ERROR descargando get-pip.py.
    echo.
    pause
    exit /b 1
)

"%DESTINO%\python\python.exe" "%DESTINO%\python\get-pip.py" --no-warn-script-location

if errorlevel 1 (
    echo.
    echo ERROR instalando pip.
    echo.
    echo Es posible que este equipo tenga bloqueadas
    echo las descargas o la ejecucion de Python.
    echo.
    pause
    exit /b 1
)

del /f /q "%DESTINO%\python\get-pip.py" >nul 2>&1

:: ============================================================
:: INSTALAR PAQUETES
:: ============================================================

echo.
echo [4/7] Instalando paquetes Python...
echo.
echo Instalando Flask...
echo.

"%DESTINO%\python\python.exe" -m pip install ^
Flask ^
flask-cors ^
yt-dlp ^
--target "%DESTINO%\paquetes" ^
--no-warn-script-location

if errorlevel 1 (
    echo.
    echo ERROR instalando los paquetes Python.
    echo.
    pause
    exit /b 1
)

:: ============================================================
:: DESCARGAR FFMPEG
:: ============================================================

echo.
echo [5/7] Descargando FFmpeg portable...
echo.
echo Esto puede tardar un poco.

set "FFMPEG_ZIP=%TEMP%\karaokefest_ffmpeg_%RANDOM%.zip"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile '%FFMPEG_ZIP%'"

if errorlevel 1 (
    echo.
    echo ERROR descargando FFmpeg.
    echo.
    pause
    exit /b 1
)

echo.
echo Extrayendo FFmpeg...

set "FFMPEG_TEMP=%TEMP%\karaokefest_ffmpeg_extract_%RANDOM%"

mkdir "%FFMPEG_TEMP%" >nul 2>&1

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"Expand-Archive -LiteralPath '%FFMPEG_ZIP%' -DestinationPath '%FFMPEG_TEMP%' -Force"

if errorlevel 1 (
    echo.
    echo ERROR extrayendo FFmpeg.
    echo.
    pause
    exit /b 1
)

:: ============================================================
:: BUSCAR BIN DE FFMPEG
:: ============================================================

set "FFMPEG_BIN="

for /r "%FFMPEG_TEMP%" %%F in (ffmpeg.exe) do (
    if not defined FFMPEG_BIN set "FFMPEG_BIN=%%~dpF"
)

if not defined FFMPEG_BIN (
    echo.
    echo ERROR:
    echo No se encontro ffmpeg.exe.
    echo.
    pause
    exit /b 1
)

echo.
echo Copiando FFmpeg...

copy /y "%FFMPEG_BIN%ffmpeg.exe" "%DESTINO%\ffmpeg\ffmpeg.exe" >nul
copy /y "%FFMPEG_BIN%ffprobe.exe" "%DESTINO%\ffmpeg\ffprobe.exe" >nul

if exist "%FFMPEG_BIN%ffplay.exe" (
    copy /y "%FFMPEG_BIN%ffplay.exe" "%DESTINO%\ffmpeg\ffplay.exe" >nul
)

rmdir /s /q "%FFMPEG_TEMP%" >nul 2>&1
del /f /q "%FFMPEG_ZIP%" >nul 2>&1

:: ============================================================
:: COPIAR SERVIDOR
:: ============================================================

echo.
echo [6/7] Copiando servidor.py...

copy /y "%~dp0servidor.py" "%DESTINO%\servidor.py" >nul

if errorlevel 1 (
    echo.
    echo ERROR copiando servidor.py.
    echo.
    pause
    exit /b 1
)

:: ============================================================
:: CREAR INICIAR_SERVIDOR.BAT
:: ============================================================

echo.
echo [7/7] Creando iniciador...

(
echo @echo off
echo title KaraokeFest Utility - Servidor
echo.
echo cd /d "%%~dp0"
echo.
echo set "PYTHONPATH=%%~dp0paquetes"
echo set "PATH=%%~dp0ffmpeg;%%~dp0python;%%PATH%%"
echo.
echo echo ============================================================
echo echo        KARAOKEFEST UTILITY
echo echo ============================================================
echo echo.
echo echo Servidor iniciandose...
echo echo.
echo echo Direccion local:
echo echo http://127.0.0.1:8765
echo echo.
echo echo Para acceder desde otro dispositivo:
echo echo http://IP-DE-ESTE-PC:8765
echo echo.
echo echo ============================================================
echo echo.
echo.
echo "%%~dp0python\python.exe" "%%~dp0servidor.py"
echo.
echo pause
) > "%DESTINO%\iniciar_servidor.bat"

:: ============================================================
:: CREAR DESINSTALADOR DENTRO DE LA INSTALACION
:: ============================================================

(
echo @echo off
echo title Desinstalador - KaraokeFest Utility
echo.
echo echo Esta carpeta contiene la instalacion de KaraokeFest Utility.
echo echo.
echo choice /C SN /N /M "Eliminar TODA esta carpeta? [S/N]: "
echo if errorlevel 2 exit /b 0
echo.
echo cd /d "%%~dp0.."
echo rmdir /s /q "%%~dp0"
echo echo.
echo echo KaraokeFest Utility ha sido eliminado.
echo pause
) > "%DESTINO%\desinstalar_local.bat"

:: ============================================================
:: FINAL
:: ============================================================

echo.
echo ============================================================
echo             INSTALACION COMPLETADA
echo ============================================================
echo.
echo Instalado en:
echo.
echo %DESTINO%
echo.
echo Estructura:
echo.
echo %DESTINO%\
echo +-- python\
echo +-- ffmpeg\
echo +-- paquetes\
echo +-- musica\
echo +-- videos\
echo +-- servidor.py
echo +-- iniciar_servidor.bat
echo +-- desinstalar_local.bat
echo.
echo Para iniciar el servidor:
echo.
echo %DESTINO%\iniciar_servidor.bat
echo.
echo ============================================================
echo.
pause
exit /b 0