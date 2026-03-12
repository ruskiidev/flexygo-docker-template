@echo off
setlocal

:: ============================================================
::  flexygo-setup.bat
::  Configura el acceso inicial a Flexygo en Docker
::  Uso: flexygo-setup.bat [contraseña]
::  Ejemplo: flexygo-setup.bat Admin123!
:: ============================================================

set PASSWORD=%~1
if "%PASSWORD%"=="" set PASSWORD=Admin123!

set BACKEND=http://localhost:60952
set DB_CONTAINER=flexy-flexy-flx-db-1
set SQL_PASSWORD=TuPasswordSegura123!

echo.
echo =============================================
echo  FLEXYGO - Configuracion inicial
echo =============================================
echo.

:: 1. Comprobar que los contenedores estan corriendo
echo [1/3] Verificando contenedores...
docker ps --filter "ancestor=flexygo/flexygo-backend" --filter "status=running" | findstr "flexygo" >nul
if errorlevel 1 (
    echo ERROR: El contenedor de backend no esta corriendo.
    echo Ejecuta primero: docker compose up -d
    exit /b 1
)
echo       OK - Contenedores activos.

:: 2. Desbloquear usuario admin en la BD
echo [2/3] Desbloqueando usuario admin...
docker exec %DB_CONTAINER% /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "%SQL_PASSWORD%" -C -Q "USE FLEXYGO_IC; UPDATE dbo.AspNetUsers SET LockoutEnabled=0, LockoutEnd=NULL, AccessFailedCount=0, MustChangePassword=0 WHERE UserName='admin'" >nul 2>&1
if errorlevel 1 (
    echo AVISO: No se pudo actualizar la BD. Continuando...
) else (
    echo       OK - Admin desbloqueado.
)

:: 3. Configurar proyecto y contraseña via API de Setup
echo [3/3] Configurando contrasena de admin: %PASSWORD%
curl -s -X POST "%BACKEND%/api/backend/Setup/project" ^
     -H "Content-Type: application/json" ^
     -d "{\"ProjectName\": \"Flexygo\", \"AdminPassword\": \"%PASSWORD%\"}" >nul

if errorlevel 1 (
    echo ERROR: No se pudo contactar con el backend.
    echo Asegurate de que los contenedores estan corriendo.
    exit /b 1
)
echo       OK - Contrasena configurada.

:: 4. Verificar login
echo.
echo Verificando login...
curl -s -X POST "%BACKEND%/api/backend/Account/SignIn" ^
     -H "Content-Type: application/json" ^
     -d "{\"userName\": \"admin\", \"password\": \"%PASSWORD%\", \"language\": 3}" > %TEMP%\flx_check.txt

findstr "Succeeded.*true" %TEMP%\flx_check.txt >nul
if errorlevel 1 (
    echo RESULTADO: Login fallido. Revisa manualmente.
    type %TEMP%\flx_check.txt
) else (
    echo RESULTADO: Login correcto!
    echo.
    echo =============================================
    echo  Accede en: http://localhost:3200
    echo  Usuario:   admin
    echo  Password:  %PASSWORD%
    echo =============================================
)

del %TEMP%\flx_check.txt >nul 2>&1
endlocal
