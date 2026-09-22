@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Desinstalador - KaraokeFest Utility

echo.
echo ============================================================
echo          KARAOKEFEST UTILITY - DESINSTALADOR
echo ============================================================
echo.
echo Selecciona la carpeta PADRE donde instalaste
echo KaraokeFest Utility.
echo.
echo Por ejemplo:
echo.
echo     Escritorio
echo     Documentos
echo     D:\
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
:: ARCHIVO TEMPORAL
:: ============================================================

set "SELECCION=%TEMP%\karaokefest_desinstalar_%RANDOM%.txt"

if exist "%SELECCION%" del /f /q "%SELECCION%" >nul 2>&1

:: ============================================================
:: SELECTOR
:: ============================================================

echo.
echo Abriendo selector...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"Add-Type -AssemblyName System.Windows.Forms; ^
$dialog = New-Object System.Windows.Forms.FolderBrowserDialog; ^
$dialog.Description = 'Selecciona la carpeta que contiene karaokefestutility'; ^
$dialog.ShowNewFolderButton = $false; ^
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { ^
    [System.IO.File]::WriteAllText('%SELECCION%', $dialog.SelectedPath) ^
}"

if not exist "%SELECCION%" (
    echo.
    echo No se selecciono ninguna carpeta.
    echo Desinstalacion cancelada.
    echo.
    pause
    exit /b 0
)

set /p "BASE=<%SELECCION%"

del /f /q "%SELECCION%" >nul 2>&1

set "DESTINO=%BASE%\karaokefestutility"

:: ============================================================
:: COMPROBAR
:: ============================================================

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
    echo La carpeta existe, pero no parece ser una
    echo instalacion de KaraokeFest Utility.
    echo.
    echo Carpeta:
    echo %DESTINO%
    echo.
    pause
    exit /b 1
)

:: ============================================================
:: CONFIRMACION
:: ============================================================

echo.
echo ============================================================
echo SE VA A ELIMINAR:
echo.
echo %DESTINO%
echo.
echo Se eliminaran:
echo.
echo   - Python portable
echo   - FFmpeg
echo   - Paquetes Python
echo   - servidor.py
echo   - musica
echo   - videos
echo   - playlist.db si existe
echo   - cualquier otro archivo dentro de esa carpeta
echo.
echo NO se eliminara el Python del sistema.
echo NO se modificara el registro.
echo NO se modificara PATH.
echo ============================================================
echo.

choice /C SN /N /M "Continuar con la desinstalacion? [S/N]: "

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
echo Eliminando...

rmdir /s /q "%DESTINO%"

if exist "%DESTINO%" (
    echo.
    echo ERROR:
    echo Windows no pudo eliminar completamente la carpeta.
    echo.
    echo Puede que el servidor siga ejecutandose.
    echo Cierra primero KaraokeFest Utility y vuelve a intentarlo.
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo       DESINSTALACION COMPLETADA
echo ============================================================
echo.
echo KaraokeFest Utility ha sido eliminado.
echo.
echo El Python normal de Windows NO ha sido tocado.
echo.
pause
exit /b 0