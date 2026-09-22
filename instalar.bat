@echo off

:: ============================================================
:: SELECTOR DE CARPETA
:: SI TARDA MAS DE 10 SEGUNDOS EN ABRIRSE -> RUTA MANUAL
:: ============================================================

set "SELECCION=%TEMP%\karaokefest_seleccion_%RANDOM%.txt"
set "ABIERTO=%TEMP%\karaokefest_abierto_%RANDOM%.txt"
set "PSCRIPT=%TEMP%\karaokefest_selector_%RANDOM%.ps1"

if exist "%SELECCION%" del /f /q "%SELECCION%" >nul 2>&1
if exist "%ABIERTO%" del /f /q "%ABIERTO%" >nul 2>&1
if exist "%PSCRIPT%" del /f /q "%PSCRIPT%" >nul 2>&1

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

echo.
echo Abriendo selector de carpeta...
echo.

start "" /b powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PSCRIPT%"

set /a TIEMPO=0

:ESPERAR_SELECTOR

:: ¿Ya se ha inicializado el selector?
if exist "%ABIERTO%" goto SELECTOR_ABIERTO

:: ¿Han pasado 10 segundos?
if %TIEMPO% GEQ 10 goto SELECTOR_TARDA

timeout /t 1 /nobreak >nul
set /a TIEMPO+=1

goto ESPERAR_SELECTOR


:: ============================================================
:: EL SELECTOR SE ABRIO CORRECTAMENTE
:: ============================================================

:SELECTOR_ABIERTO

echo Selector abierto correctamente.
echo.
echo Ahora puedes tardar todo el tiempo que quieras.
echo.

:ESPERAR_SELECCION

if exist "%SELECCION%" goto CARPETA_SELECCIONADA

:: Si PowerShell termina sin seleccionar nada
tasklist /FI "IMAGENAME eq powershell.exe" 2>NUL | find /I "powershell.exe" >NUL

if errorlevel 1 (
    echo.
    echo No se selecciono ninguna carpeta.
    goto RUTA_MANUAL
)

timeout /t 1 /nobreak >nul
goto ESPERAR_SELECCION


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
:: CARPETA SELECCIONADA
:: ============================================================

:CARPETA_SELECCIONADA

set /p "BASE=<%SELECCION%>"

del /f /q "%SELECCION%" >nul 2>&1
del /f /q "%ABIERTO%" >nul 2>&1
del /f /q "%PSCRIPT%" >nul 2>&1

if "%BASE%"=="" goto RUTA_MANUAL

goto CARPETA_LISTA


:: ============================================================
:: RUTA MANUAL
:: ============================================================

:RUTA_MANUAL

del /f /q "%SELECCION%" >nul 2>&1
del /f /q "%ABIERTO%" >nul 2>&1
del /f /q "%PSCRIPT%" >nul 2>&1

echo.
echo Introduce manualmente la ruta de la carpeta.
echo.
echo Ejemplos:
echo.
echo C:\Users\TuUsuario\Desktop
echo D:\Programas
echo E:\Karaoke
echo.

set /p "BASE=Ruta: "

if "%BASE%"=="" (
    echo.
    echo No se introdujo ninguna ruta.
    echo Instalacion cancelada.
    pause
    exit /b 1
)

set "BASE=%BASE:"=%"

goto CARPETA_LISTA


:: ============================================================
:: CONTINUAR INSTALACION
:: ============================================================

:CARPETA_LISTA

echo.
echo ============================================================
echo Carpeta seleccionada:
echo.
echo %BASE%
echo ============================================================
echo.

set "DESTINO=%BASE%\karaokefestutility"
