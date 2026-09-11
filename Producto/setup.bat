@echo off
setlocal enabledelayedexpansion

echo =======================================================
echo    Configuracion y Ejecucion del Proyecto TAG OK
echo =======================================================
echo.

rem Ir al directorio donde se encuentra este script
cd /d "%~dp0"

rem Usar el SDK local cuando Flutter no esta instalado globalmente
if exist "%~dp0..\.tools\flutter\bin\flutter.bat" (
    set "PATH=%~dp0..\.tools\flutter\bin;%PATH%"
    set "PUB_CACHE=%~dp0..\.tools\pub-cache"
    for %%I in ("%~dp0..\.tools\flutter") do set "LOCAL_FLUTTER=%%~fI"
    if not defined GIT_CONFIG_COUNT set "GIT_CONFIG_COUNT=0"
    set "GIT_CONFIG_KEY_!GIT_CONFIG_COUNT!=safe.directory"
    set "GIT_CONFIG_VALUE_!GIT_CONFIG_COUNT!=!LOCAL_FLUTTER:\=/!"
    set /a GIT_CONFIG_COUNT+=1
)

echo [1/3] Creando archivos .env vacios (requerido por Flutter)...
echo.
if not exist "tag_ok\.env" (
    echo. > "tag_ok\.env"
    echo - Creado tag_ok\.env vacio
)
if not exist "admin\.env" (
    echo. > "admin\.env"
    echo - Creado admin\.env vacio
)
echo.

echo [2/3] Instalar/Actualizar dependencias del proyecto...
echo.
echo Instalando dependencias de la app principal (tag_ok)...
cd tag_ok
call flutter pub get
cd ..

echo.
echo Instalando dependencias del panel de administrador (admin)...
cd admin
call flutter pub get
cd ..

echo.
echo =======================================================
echo    Instalacion y configuracion completadas con exito!
echo =======================================================
echo (Nota: Las claves de Firebase y Gemini se cargan en 
echo  memoria automaticamente. ¡No necesitas archivos .env!)
echo.

rem 2. Menu de ejecucion
:menu
echo Selecciona la aplicacion que deseas ejecutar:
echo 1) App Principal (tag_ok) - Ejecutar en Windows Desktop
echo 2) App Principal (tag_ok) - Ejecutar en Chrome (Web)
echo 3) Panel Administrador (admin) - Ejecutar en Windows Desktop
echo 4) Panel Administrador (admin) - Ejecutar en Chrome (Web)
echo 5) Salir
echo.
set /p opcion="Introduce el numero de tu opcion (1-5): "

if "%opcion%"=="1" (
    echo Ejecutando App Principal (tag_ok) en Windows...
    cd tag_ok
    flutter run -d windows
    cd ..
    goto menu
)
if "%opcion%"=="2" (
    echo Ejecutando App Principal (tag_ok) en Chrome...
    cd tag_ok
    flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8090 --no-web-experimental-hot-reload
    cd ..
    goto menu
)
if "%opcion%"=="3" (
    echo Ejecutando Panel Administrador (admin) en Windows...
    cd admin
    flutter run -d windows
    cd ..
    goto menu
)
if "%opcion%"=="4" (
    echo Ejecutando Panel Administrador (admin) en Chrome...
    cd admin
    flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8091 --no-web-experimental-hot-reload
    cd ..
    goto menu
)
if "%opcion%"=="5" (
    echo Saliendo del script. ¡Adios!
    pause
    exit /b 0
)

echo Opcion no valida, por favor intenta de nuevo.
echo.
goto menu
