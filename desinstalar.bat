@echo off
setlocal EnableExtensions EnableDelayedExpansion
title KaraokeFest Utility - Desinstalador

echo.
echo ============================================================
echo              KARAOKEFEST UTILITY
echo                  DESINSTALADOR
echo ============================================================
echo.
echo Este desinstalador NO necesita permisos de administrador.
echo.
echo Selecciona la carpeta PADRE donde esta instalada
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
:: ARCHIVOS TEMPORALES
:: ============================================================

set "SELECCION=%TEMP%\karaokefest_desinstalar_%RANDOM%.txt"
set "ABIERTO=%TEMP%\karaokefest_desinstalar_abierto_%RANDOM%.txt"
set "PSCRIPT=%TEMP%\karaokefest_desinstalar_selector_%RANDOM%.ps1"

if exist "%SELECCION%" del /f /q "%SELECCION%" >nul 2>&1
if exist "%ABIERTO%" del /f /q "%ABIERTO%" >nul 2>&1
if exist "%PSCRIPT%" del /f /q "%PSCRIPT%" >nul 2>&1

:: ============================================================
:: CREAR SELECTOR
:: ============================================================

(
echo Add-Type -AssemblyName System.Windows.Forms
echo $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
echo $dialog.Description = 'Selecciona la carpeta donde esta karaokefestutility'
echo $dialog.ShowNewFolderButton = $false
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
echo Elige la carpeta que contiene:
echo.
echo     karaokefestutility
echo.
echo Puedes tardar todo el tiempo que necesites.
echo.

:ESPERAR_SELECCION

if exist "%SELECCION%" goto CARPETA_SELECCIONADA

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

if not defined BASE goto RUTA_MANUAL

goto CARPETA_LISTA

:: ============================================================
:: SELECTOR TARDA MAS DE 10 SEGUNDOS
:: ============================================================

:SELECTOR_TARDA

echo.
echo ============================================================
echo El selector ha tardado mas de 10 segundos en abrirse.
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
echo Ejemplo:
echo.
echo C:\Users\Pc\Desktop
echo.

set "BASE="
set /p "BASE=Ruta: "

if not defined BASE (
    echo.
    echo No se introdujo ninguna ruta.
    echo Desinstalacion cancelada.
    echo.
    pause
    exit /b 1
)

set "BASE=%BASE:"=%"

goto CARPETA_LISTA

:: ============================================================
:: COMPROBAR INSTALACION
:: ============================================================

:CARPETA_LISTA

set "DESTINO=%BASE%\karaokefestutility"

echo.
echo ============================================================
echo Instalacion encontrada:
echo.
echo %DESTINO%
echo ============================================================
echo.

if not exist "%DESTINO%" (
    echo.
    echo ERROR:
    echo No se encontro:
    echo.
    echo %DESTINO%
    echo.
    echo Comprueba que hayas seleccionado la carpeta correcta.
    echo.
    pause
    exit /b 1
)

if not exist "%DESTINO%\servidor.py" (
    echo.
    echo ERROR:
    echo La carpeta existe, pero no parece ser una instalacion
    echo de KaraokeFest Utility.
    echo.
    pause
    exit /b 1
)

:: ============================================================
:: CONFIRMACION
:: ============================================================

echo.
echo ============================================================
echo ATENCION
echo ============================================================
echo.
echo Se eliminara COMPLETAMENTE:
echo.
echo %DESTINO%
echo.
echo Incluyendo:
echo.
echo   Python portable
echo   FFmpeg
echo   Paquetes Python
echo   Musica descargada
echo   Videos descargados
echo   Base de datos
echo   servidor.py
echo   Archivos de configuracion
echo.
echo El Python normal de Windows NO sera eliminado.
echo.
echo ============================================================
echo.

choice /C SN /N /M "Eliminar esta instalacion? [S/N]: "

if errorlevel 2 (
    echo.
    echo Desinstalacion cancelada.
    echo.
    pause
    exit /b 0
)

:: ============================================================
:: ELIMINAR
:: ============================================================

echo.
echo Eliminando instalacion...
echo.

rmdir /s /q "%DESTINO%"

if exist "%DESTINO%" (
    echo.
    echo ============================================================
    echo ERROR
    echo ============================================================
    echo.
    echo Windows no pudo eliminar completamente la carpeta.
    echo.
    echo Comprueba que KaraokeFest Utility no este ejecutandose.
    echo Cierra el servidor y vuelve a ejecutar desinstalar.bat.
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo          DESINSTALACION COMPLETADA
echo ============================================================
echo.
echo KaraokeFest Utility ha sido eliminado correctamente.
echo.
echo El Python del sistema NO ha sido tocado.
echo.
pause

exit /b 0
