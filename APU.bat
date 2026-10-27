@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title APSoft - APUpdaterApp

set "APP=APUpdaterApp"
set "PS_SCRIPT=%~dp0APUpdaterApp.ps1"

if not exist "%PS_SCRIPT%" (
    cls
    echo ========================================================
    echo               APSoft - APUpdaterApp
    echo ========================================================
    echo.
    echo [ERROR] No se encontro el motor PowerShell:
    echo "%PS_SCRIPT%"
    echo.
    pause
    exit /b 10
)

rem Si recibe parametros, los transmite directamente al motor.
if not "%~1"=="" (
    call :RUN %*
    exit /b %ERRORLEVEL%
)

:MENU
cls
echo ========================================================
echo               APSoft - APUpdaterApp
echo ========================================================
echo  Actualizacion y auditoria de aplicaciones con WinGet
echo --------------------------------------------------------
echo.
echo  [1] Buscar actualizaciones
echo  [2] Actualizar aplicaciones
echo  [3] Actualizar en modo silencioso
echo  [4] Health Check
echo  [5] Ver aplicaciones instaladas
echo  [6] Actualizar fuentes WinGet
echo  [7] Incluir versiones desconocidas y actualizar
echo.
echo  [0] Salir
echo.
echo --------------------------------------------------------
choice /C 12345670 /N /M " Seleccione una opcion: "

if errorlevel 8 goto EXIT
if errorlevel 7 goto UPDATE_UNKNOWN
if errorlevel 6 goto SOURCES
if errorlevel 5 goto LIST
if errorlevel 4 goto HEALTH
if errorlevel 3 goto UPDATE_SILENT
if errorlevel 2 goto UPDATE
if errorlevel 1 goto SCAN
goto MENU

:SCAN
call :RUN -Mode Scan
call :PAUSE_RESULT %ERRORLEVEL%
goto MENU

:UPDATE
call :CONFIRM "Se actualizaran todas las aplicaciones compatibles."
if errorlevel 1 goto MENU
call :RUN -Mode Update
call :PAUSE_RESULT %ERRORLEVEL%
goto MENU

:UPDATE_SILENT
call :CONFIRM "Se actualizaran las aplicaciones en modo silencioso."
if errorlevel 1 goto MENU
call :RUN -Mode Update -Silent
call :PAUSE_RESULT %ERRORLEVEL%
goto MENU

:UPDATE_UNKNOWN
call :CONFIRM "Tambien se intentaran actualizar paquetes con version desconocida."
if errorlevel 1 goto MENU
call :RUN -Mode Update -Silent -IncludeUnknown
call :PAUSE_RESULT %ERRORLEVEL%
goto MENU

:HEALTH
call :RUN -Mode HealthCheck
call :PAUSE_RESULT %ERRORLEVEL%
goto MENU

:LIST
call :RUN -Mode List
call :PAUSE_RESULT %ERRORLEVEL%
goto MENU

:SOURCES
call :RUN -Mode Sources
call :PAUSE_RESULT %ERRORLEVEL%
goto MENU

:RUN
cls
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
exit /b %ERRORLEVEL%

:CONFIRM
cls
echo ========================================================
echo                    CONFIRMACION
echo ========================================================
echo.
echo %~1
echo.
choice /C SN /N /M "Desea continuar? [S/N]: "
if errorlevel 2 exit /b 1
exit /b 0

:PAUSE_RESULT
set "RC=%~1"
echo.
echo --------------------------------------------------------
if "%RC%"=="0" (
    echo [OK] Operacion finalizada correctamente.
) else (
    echo [AVISO] La operacion finalizo con codigo %RC%.
)
echo --------------------------------------------------------
echo.
pause
exit /b 0

:EXIT
endlocal
exit /b 0
