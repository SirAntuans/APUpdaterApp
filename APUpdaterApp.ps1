#requires -Version 5.1
<#
.SYNOPSIS
    APUpdaterApp - Actualizacion y auditoria de aplicaciones mediante WinGet.
.DESCRIPTION
    Motor PowerShell de APSoft para APU.bat. Incluye diagnostico, escaneo,
    actualizacion, listado, mantenimiento de fuentes y registros de ejecucion.
.NOTES
    Version: 1.0.0
    Marca: APSoft
#>

[CmdletBinding()]
param(
    [ValidateSet('Scan','Update','HealthCheck','List','Sources')]
    [string]$Mode = 'HealthCheck',

    [switch]$Silent,
    [switch]$IncludeUnknown,

    [ValidateRange(1,365)]
    [int]$LogRetentionDays = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:AppName = 'APUpdaterApp'
$script:Version = '1.0.0'
$script:WingetPath = $null
$script:LogRoot = Join-Path $env:ProgramData 'APSoft\APUpdaterApp\Logs'
$script:LogFile = Join-Path $script:LogRoot ('APUpdaterApp_{0}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Initialize-Log {
    try {
        if (-not (Test-Path -LiteralPath $script:LogRoot)) {
            New-Item -Path $script:LogRoot -ItemType Directory -Force | Out-Null
        }
        Get-ChildItem -LiteralPath $script:LogRoot -Filter '*.log' -File -ErrorAction SilentlyContinue |
            Where-Object LastWriteTime -LT (Get-Date).AddDays(-$LogRetentionDays) |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
    catch {
        $script:LogRoot = Join-Path $env:TEMP 'APSoft\APUpdaterApp\Logs'
        New-Item -Path $script:LogRoot -ItemType Directory -Force | Out-Null
        $script:LogFile = Join-Path $script:LogRoot ('APUpdaterApp_{0}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','OK','WARN','ERROR')][string]$Level = 'INFO'
    )
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    $colour = @{ INFO='Cyan'; OK='Green'; WARN='Yellow'; ERROR='Red' }[$Level]
    Write-Host $line -ForegroundColor $colour
    try { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 } catch { }
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Resolve-WinGet {
    $command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $candidate = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps') `
        -Filter winget.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($candidate) { return $candidate.FullName }
    return $null
}

function Invoke-WinGet {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$IgnoreExitCode
    )

    Write-Log ('Ejecutando: winget {0}' -f ($Arguments -join ' '))
    try {
        & $script:WingetPath @Arguments 2>&1 | ForEach-Object {
            $text = $_.ToString()
            Write-Host $text
            try { Add-Content -LiteralPath $script:LogFile -Value $text -Encoding UTF8 } catch { }
        }
        $code = $LASTEXITCODE
    }
    catch {
        Write-Log $_.Exception.Message 'ERROR'
        return 50
    }

    if ($null -eq $code) { $code = 0 }
    if (($code -ne 0) -and (-not $IgnoreExitCode)) {
        Write-Log ('WinGet finalizo con codigo {0} (0x{0:X8}).' -f [uint32]$code) 'WARN'
    }
    return [int]$code
}

function Show-Header {
    Clear-Host
    Write-Host '========================================================' -ForegroundColor DarkCyan
    Write-Host '               APSoft - APUpdaterApp' -ForegroundColor Cyan
    Write-Host ('               Version {0}' -f $script:Version) -ForegroundColor DarkGray
    Write-Host '========================================================' -ForegroundColor DarkCyan
    Write-Host ''
}

function Invoke-HealthCheck {
    Write-Log 'Iniciando Health Check.'
    $isAdmin = Test-Administrator
    Write-Log ('Administrador: {0}' -f $(if ($isAdmin) {'Si'} else {'No'})) $(if ($isAdmin) {'OK'} else {'WARN'})
    Write-Log ('PowerShell: {0}' -f $PSVersionTable.PSVersion)
    Write-Log ('Sistema: {0}' -f [Environment]::OSVersion.VersionString)
    Write-Log ('Equipo: {0}' -f $env:COMPUTERNAME)
    Write-Log ('Usuario: {0}\{1}' -f $env:USERDOMAIN, $env:USERNAME)
    Write-Log ('WinGet: {0}' -f $script:WingetPath) 'OK'

    $version = & $script:WingetPath --version 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Log ('Version WinGet: {0}' -f ($version -join ' ')) 'OK' }
    else { Write-Log 'No se pudo consultar la version de WinGet.' 'ERROR'; return 12 }

    $sourceCode = Invoke-WinGet -Arguments @('source','list') -IgnoreExitCode
    if ($sourceCode -ne 0) { Write-Log 'No se pudieron enumerar las fuentes.' 'WARN'; return 13 }
    Write-Log 'Health Check completado.' 'OK'
    return 0
}

Initialize-Log
Show-Header
Write-Log ('Inicio. Modo={0}; Silent={1}; IncludeUnknown={2}' -f $Mode, $Silent.IsPresent, $IncludeUnknown.IsPresent)

$script:WingetPath = Resolve-WinGet
if (-not $script:WingetPath) {
    Write-Log 'WinGet no esta instalado, no esta registrado o no es accesible para este usuario.' 'ERROR'
    Write-Host ''
    Write-Host 'Instale o repare "App Installer" y vuelva a ejecutar la herramienta.' -ForegroundColor Yellow
    exit 10
}

$exitCode = 0
try {
    switch ($Mode) {
        'HealthCheck' {
            $exitCode = Invoke-HealthCheck
        }
        'Scan' {
            $args = @('list','--upgrade-available','--accept-source-agreements')
            if ($IncludeUnknown) { $args += '--include-unknown' }
            $exitCode = Invoke-WinGet -Arguments $args
        }
        'List' {
            $exitCode = Invoke-WinGet -Arguments @('list','--accept-source-agreements')
        }
        'Sources' {
            if (-not (Test-Administrator)) {
                Write-Log 'Se recomienda ejecutar este modo como administrador.' 'WARN'
            }
            $exitCode = Invoke-WinGet -Arguments @('source','update')
        }
        'Update' {
            if (-not (Test-Administrator)) {
                Write-Log 'La sesion no esta elevada. Algunos instaladores pueden solicitar elevacion o fallar.' 'WARN'
            }

            $sourceCode = Invoke-WinGet -Arguments @('source','update') -IgnoreExitCode
            if ($sourceCode -ne 0) {
                Write-Log 'No se pudieron actualizar todas las fuentes; se continuara con la cache disponible.' 'WARN'
            }

            $args = @(
                'upgrade','--all',
                '--accept-source-agreements',
                '--accept-package-agreements'
            )
            if ($Silent) { $args += '--silent' }
            if ($IncludeUnknown) { $args += '--include-unknown' }

            $exitCode = Invoke-WinGet -Arguments $args
        }
    }
}
catch {
    Write-Log $_.Exception.Message 'ERROR'
    $exitCode = 99
}

Write-Host ''
if ($exitCode -eq 0) { Write-Log 'Operacion finalizada correctamente.' 'OK' }
else { Write-Log ('Operacion finalizada con codigo {0}.' -f $exitCode) 'WARN' }
Write-Host ('Log: {0}' -f $script:LogFile) -ForegroundColor DarkGray
exit $exitCode
