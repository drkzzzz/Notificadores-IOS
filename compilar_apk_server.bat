@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Compilar APK SERVER - Notificadores SAT (no toca PROD)

rem Coloque este .bat DENTRO de la carpeta del proyecto SERVER
rem y ejecútelo ahí. Compila la versión con cola offline / MODIF / Finalizado.
set "SOURCE_DIR=%~dp0"
set "SOURCE_DIR=%SOURCE_DIR:~0,-1%"
for /f %%d in ('powershell -NoProfile -Command "Get-Date -Format ddMMyyyy"') do set "FECHA=%%d"
for /f %%h in ('powershell -NoProfile -Command "Get-Date -Format HHmm"') do set "HORA=%%h"
set "BUILD_PARENT=%LOCALAPPDATA%\SAT"
set "BUILD_DIR=%BUILD_PARENT%\NotificadoresSATT_SERVER_%RANDOM%_%RANDOM%"
set "OUTPUT_APK=%SOURCE_DIR%\NOTIFICADORES-SATT-%FECHA%-%HORA%.apk"
set "NOTIFICADORES_API_KEY=L3nsd@ys"
set "NOTIFICADORES_API_BASE_URL=http://190.119.38.13"

if not exist "%SOURCE_DIR%\pubspec.yaml" (
    echo No se encontro pubspec.yaml en: %SOURCE_DIR%
    pause
    exit /b 1
)
where flutter >nul 2>&1
if errorlevel 1 (
    echo Flutter no esta instalado o no figura en el PATH de este equipo.
    pause
    exit /b 1
)
if not exist "%BUILD_PARENT%" mkdir "%BUILD_PARENT%"
echo Copiando el proyecto SERVER a carpeta local para compilar...
robocopy "%SOURCE_DIR%" "%BUILD_DIR%" /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /XD .git .dart_tool build .idea /XF local.properties >nul
if %ERRORLEVEL% GEQ 8 goto :copy_error
if not exist "%BUILD_DIR%\pubspec.yaml" goto :copy_error
pushd "%BUILD_DIR%"
echo Obteniendo dependencias (incluye cola offline: sqflite/connectivity/uuid)...
call flutter pub get
if errorlevel 1 goto :error
echo Generando APK SERVER de prueba...
call flutter build apk --release --dart-define=NOTIFICADORES_API_KEY=%NOTIFICADORES_API_KEY% --dart-define=NOTIFICADORES_API_BASE_URL=%NOTIFICADORES_API_BASE_URL%
if errorlevel 1 goto :error
set "GENERATED_APK=%BUILD_DIR%\build\app\outputs\flutter-apk\app-release.apk"
if not exist "%GENERATED_APK%" goto :apk_error
copy /Y "%GENERATED_APK%" "%OUTPUT_APK%" >nul
if errorlevel 1 goto :apk_error
popd
echo.
echo APK SERVER generado en:
echo %OUTPUT_APK%
echo.
echo IMPORTANTE: el APK de PROD (NOTIFICADORES-SAT-FINAL-20260918.apk) no se toco.
pause
exit /b 0
:copy_error
echo No se pudo copiar el proyecto SERVER.
pause
exit /b 1
:apk_error
popd >nul 2>&1
echo Flutter termino pero no se encontro el APK.
pause
exit /b 1
:error
popd >nul 2>&1
echo No se pudo generar el APK SERVER. Revisa el mensaje de Flutter.
pause
exit /b 1