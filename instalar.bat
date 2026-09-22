@echo off
setlocal EnableExtensions EnableDelayedExpansion
title KaraokeFest Utility - Instalador

echo.
echo ============================================================
echo              KARAOKEFEST UTILITY
echo                    INSTALADOR
echo ============================================================
echo.
echo Este instalador NO necesita permisos de administrador.
echo.
echo Puedes elegir cualquier carpeta donde tengas permisos
echo de escritura, por ejemplo el Escritorio.
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
:: ARCHIVOS TEMPORALES
:: ============================================================

set "SELECCION=%TEMP%\karaokefest_seleccion_%RANDOM%.txt"
set "ABIERTO=%TEMP%\karaokefest_abierto_%RANDOM%.txt"
set "PSCRIPT=%TEMP%\karaokefest_selector_%RANDOM%.ps1"

if exist "%SELECCION%" del /f /q "%SELECCION%" >nul 2>&1
if exist "%ABIERTO%" del /f /q "%ABIERTO%" >nul 2>&1
if exist "%PSCRIPT%" del /f /q "%PSCRIPT%" >nul 2>&1

:: ============================================================
:: CREAR SCRIPT POWERSHELL DEL SELECTOR
:: ============================================================

(
echo Add-Type -AssemblyName System.Windows.Forms
echo $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
echo $dialog.Description = 'Selecciona la carpeta donde instalar KaraokeFest Utility'
echo $dialog.ShowNewFolderButton = $true
echo [System.IO.File]::WriteAllText^('%ABIERTO%', 'OK'^)
echo if ^($dialog.ShowDialog^(^) -eq [System.Windows.Forms.DialogResult]::OK^) {
echo     [System.IO.File]::WriteAllText^('%SELECCION%', $dialog.SelectedPath^)
echo }
) > "%PSCRIPT%"

:: ============================================================
:: ABRIR SELECTOR
:: ============================================================

echo.
echo Abriendo selector de carpeta...
echo.

start "" /b powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PSCRIPT%"

:: ============================================================
:: ESPERAR A QUE EL SELECTOR SE ABRA
:: MAXIMO 10 SEGUNDOS
:: ============================================================

set /a TIEMPO=0

:ESPERAR_SELECTOR

if exist "%ABIERTO%" goto SELECTOR_ABIERTO

if %TIEMPO% GEQ 10 goto SELECTOR_TARDA

timeout /t 1 /nobreak >nul
set /a TIEMPO+=1

goto ESPERAR_SELECTOR

:: ============================================================
:: SELECTOR ABIERTO
:: ============================================================

:SELECTOR_ABIERTO

echo.
echo Selector abierto correctamente.
echo.
echo Elige la carpeta que quieras.
echo Puedes tardar todo el tiempo que necesites.
echo.

:ESPERAR_SELECCION

if exist "%SELECCION%" goto CARPETA_SELECCIONADA

:: Comprobar si el usuario cerro/cancelo el selector.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"if (-not (Get-Process -Id $PID -ErrorAction SilentlyContinue)) { exit 1 }" >nul 2>&1

timeout /t 1 /nobreak >nul
goto ESPERAR_SELECCION

:: ============================================================
:: CARPETA SELECCIONADA
:: ============================================================

:CARPETA_SELECCIONADA

set "BASE="

for /f "usebackq delims=" %%A in ("%SELECCION%") do (
    set "BASE=%%A"
)

del /f /q "%SELECCION%" >nul 2>&1
del /f /q "%ABIERTO%" >nul 2>&1
del /f /q "%PSCRIPT%" >nul 2>&1

if not defined BASE (
    echo.
    echo No se obtuvo ninguna ruta.
    goto RUTA_MANUAL
)

goto CARPETA_LISTA

:: ============================================================
:: SELECTOR TARDA MAS DE 10 SEGUNDOS EN ABRIR
:: ============================================================

:SELECTOR_TARDA

echo.
echo ============================================================
echo El selector de carpetas ha tardado mas de 10 segundos
echo en abrirse.
echo ============================================================
echo.
echo Se utilizara la entrada manual.
echo.

taskkill /F /IM powershell.exe >nul 2>&1

goto RUTA_MANUAL

:: ============================================================
:: RUTA MANUAL
:: ============================================================

:RUTA_MANUAL

del /f /q "%SELECCION%" >nul 2>&1
del /f /q "%ABIERTO%" >nul 2>&1
del /f /q "%PSCRIPT%" >nul 2>&1

echo.
echo ============================================================
echo INTRODUCE LA RUTA MANUALMENTE
echo ============================================================
echo.
echo Ejemplos:
echo.
echo C:\Users\Pc\Desktop
echo C:\Users\Pc\Documents
echo D:\Programas
echo E:\Karaoke
echo.

set "BASE="
set /p "BASE=Ruta: "

if not defined BASE (
    echo.
    echo No se introdujo ninguna ruta.
    echo Instalacion cancelada.
    echo.
    pause
    exit /b 1
)

set "BASE=%BASE:"=%"

goto CARPETA_LISTA

:: ============================================================
:: PREPARAR DESTINO
:: ============================================================

:CARPETA_LISTA

echo.
echo ============================================================
echo CARPETA ELEGIDA:
echo.
echo %BASE%
echo ============================================================
echo.

set "DESTINO=%BASE%\karaokefestutility"

echo La instalacion se realizara en:
echo.
echo %DESTINO%
echo.

:: ============================================================
:: COMPROBAR SERVIDOR.PY
:: ============================================================

if not exist "%~dp0servidor.py" (
    echo.
    echo ERROR:
    echo No se encontro servidor.py.
    echo.
    echo Debes tener estos archivos juntos:
    echo.
    echo     instalar.bat
    echo     desinstalar.bat
    echo     servidor.py
    echo.
    pause
    exit /b 1
)

:: ============================================================
:: COMPROBAR SI YA EXISTE
:: ============================================================

if exist "%DESTINO%" (
    echo.
    echo ATENCION:
    echo La carpeta ya existe:
    echo.
    echo %DESTINO%
    echo.
    choice /C SN /N /M "Quieres continuar y reutilizarla? [S/N]: "

    if errorlevel 2 (
        echo.
        echo Instalacion cancelada.
        echo.
        pause
        exit /b 0
    )
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

if not exist "%DESTINO%" (
    echo.
    echo ERROR:
    echo No se pudo crear:
    echo %DESTINO%
    echo.
    echo Comprueba que tengas permisos de escritura.
    echo.
    pause
    exit /b 1
)

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
    echo Comprueba tu conexion a Internet.
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

if not exist "%DESTINO%\python\python.exe" (
    echo.
    echo ERROR:
    echo Python no se extrajo correctamente.
    echo.
    pause
    exit /b 1
)

:: ============================================================
:: CONFIGURAR PYTHON EMBEBIDO
:: ============================================================

echo.
echo Configurando Python portable...

set "PTH="

for %%F in ("%DESTINO%\python\*_pth") do (
    if exist "%%~fF" (
        set "PTH=%%~fF"
    )
)

if not defined PTH (
    echo.
    echo ERROR:
    echo No se encontro el archivo _pth de Python.
    echo.
    pause
    exit /b 1
)

mkdir "%DESTINO%\python\Lib\site-packages" >nul 2>&1

findstr /x /c:"Lib\site-packages" "%PTH%" >nul 2>&1

if errorlevel 1 (
    >>"%PTH%" echo Lib\site-packages
)

findstr /x /c:"import site" "%PTH%" >nul 2>&1

if errorlevel 1 (
    >>"%PTH%" echo import site
)

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
    echo El equipo puede estar bloqueando la instalacion.
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
echo Flask
echo flask-cors
echo yt-dlp
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
set "FFMPEG_TEMP=%TEMP%\karaokefest_ffmpeg_extract_%RANDOM%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile '%FFMPEG_ZIP%'"

if errorlevel 1 (
    echo.
    echo ERROR descargando FFmpeg.
    echo.
    pause
    exit /b 1
)

mkdir "%FFMPEG_TEMP%" >nul 2>&1

echo.
echo Extrayendo FFmpeg...

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
:: BUSCAR FFMPEG.EXE
:: ============================================================

set "FFMPEG_BIN="

for /r "%FFMPEG_TEMP%" %%F in (ffmpeg.exe) do (
    if not defined FFMPEG_BIN (
        set "FFMPEG_BIN=%%~dpF"
    )
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

if exist "%FFMPEG_BIN%ffprobe.exe" (
    copy /y "%FFMPEG_BIN%ffprobe.exe" "%DESTINO%\ffmpeg\ffprobe.exe" >nul
)

if exist "%FFMPEG_BIN%ffplay.exe" (
    copy /y "%FFMPEG_BIN%ffplay.exe" "%DESTINO%\ffmpeg\ffplay.exe" >nul
)

rmdir /s /q "%FFMPEG_TEMP%" >nul 2>&1
del /f /q "%FFMPEG_ZIP%" >nul 2>&1

if not exist "%DESTINO%\ffmpeg\ffmpeg.exe" (
    echo.
    echo ERROR:
    echo FFmpeg no se copio correctamente.
    echo.
    pause
    exit /b 1
)

:: ============================================================
:: COPIAR SERVIDOR.PY
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
echo setlocal
echo title KaraokeFest Utility - Servidor
echo.
echo cd /d "%%~dp0"
echo.
echo set "PYTHONPATH=%%~dp0paquetes"
echo set "PATH=%%~dp0ffmpeg;%%~dp0python;%%PATH%%"
echo.
echo echo ============================================================
echo echo              KARAOKEFEST UTILITY
echo echo ============================================================
echo echo.
echo echo Servidor iniciandose...
echo echo.
echo echo Local:
echo echo http://127.0.0.1:8765
echo echo.
echo echo LAN:
echo echo http://IP-DE-ESTE-PC:8765
echo echo.
echo echo ============================================================
echo echo.
echo.
echo "%%~dp0python\python.exe" "%%~dp0servidor.py"
echo.
echo echo.
echo echo El servidor se ha detenido.
echo pause
) > "%DESTINO%\iniciar_servidor.bat"

:: ============================================================
:: CREAR DESINSTALADOR LOCAL
:: ============================================================

(
echo @echo off
echo title KaraokeFest Utility - Desinstalador
echo.
echo echo Se va a eliminar:
echo echo %%~dp0
echo echo.
echo choice /C SN /N /M "Eliminar esta instalacion? [S/N]: "
echo if errorlevel 2 exit /b 0
echo.
echo cd /d "%%~dp0.."
echo rmdir /s /q "%%~dp0"
echo.
echo echo Instalacion eliminada.
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
echo.
echo Para iniciar el servidor:
echo.
echo %DESTINO%\iniciar_servidor.bat
echo.
echo ============================================================
echo.
pause

exit /b 0
