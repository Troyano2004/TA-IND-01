# Funciones comunes que usan los scripts 01 a 04 (se cargan con: . "$PSScriptRoot\_comun.ps1")

$ErrorActionPreference = 'Continue'
$Global:RaizRepo   = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$Global:Compose    = Join-Path $RaizRepo 'docker-compose.yml'
$Global:DirSalidas = Join-Path $RaizRepo 'experimento\salidas'

# Imprime usuario, equipo y fecha (evidencia de autoría en cada captura)
function Show-Contexto {
    param([string]$Titulo)
    Write-Host ''
    Write-Host "==== $Titulo" -ForegroundColor Green
    Write-Host ("Usuario: {0} | Equipo: {1} | Fecha: {2}" -f (whoami), (hostname), (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor Cyan
}

# Abre la transcripción en experimento\salidas\<nombre>_<fecha-hora>.txt
function Start-Registro {
    param([string]$Nombre)
    if (-not (Test-Path $DirSalidas)) { New-Item -ItemType Directory -Force $DirSalidas | Out-Null }
    $archivo = Join-Path $DirSalidas ("{0}_{1}.txt" -f $Nombre, (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
    Start-Transcript -Path $archivo | Out-Null
    Write-Host "Salida guardada en: $archivo"
    Show-Contexto "Inicio de $Nombre"
}

function Stop-Registro {
    Show-Contexto 'Fin del script'
    Stop-Transcript | Out-Null
}

# Comprueba que Docker Desktop esté corriendo; si no, termina el script
function Test-Docker {
    docker version --format '{{.Server.Version}}' *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Docker Desktop no está corriendo. Ábrelo, espera a que diga "Engine running" y vuelve a ejecutar el script.' -ForegroundColor Red
        Stop-Registro
        exit 1
    }
    Write-Host 'Docker Desktop está corriendo.'
}

# Ejecuta docker con los argumentos dados, muestra la salida y la guarda en $Global:Salida
function Invoke-Docker {
    $Global:Salida = & docker @args 2>&1 | ForEach-Object { "$_" }
    $Global:CodigoSalida = $LASTEXITCODE
    $Global:Salida | Out-Host
}

# Ejecuta SQL dentro del contenedor indicado (sin comillas dobles dentro del SQL)
function Invoke-Sql {
    param([string]$Nodo, [string]$Sql, [string]$Formato = 'table')
    Write-Host "[$Nodo] > $Sql" -ForegroundColor DarkGray
    Invoke-Docker exec $Nodo ./cockroach sql --insecure "--host=${Nodo}:26257" "--format=$Formato" -e $Sql
}

function Show-NodeStatus {
    Invoke-Docker exec roach1 ./cockroach node status --insecure --host=roach1:26257 --format=table
}

# Punto de captura: mensaje en amarillo y pausa
function Request-Captura {
    param([int]$Numero, [string]$Texto)
    Show-Contexto "Punto de captura $Numero"
    Write-Host "CAPTURA ${Numero}: $Texto" -ForegroundColor Yellow
    if (-not $SinPausa) { Read-Host 'Toma la captura y presiona Enter' | Out-Null }
}

function Wait-Segundos {
    param([int]$Segundos, [string]$Motivo)
    Write-Host "Esperando $Segundos s ($Motivo)..."
    Start-Sleep -Seconds $Segundos
}
