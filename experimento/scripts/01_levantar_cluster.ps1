# 01 - Levanta el clúster de 3 nodos, crea la base banco y muestra réplicas y leaseholder.
# Uso: .\experimento\scripts\01_levantar_cluster.ps1   (-SinPausa omite las pausas de captura)
param([switch]$SinPausa)
. "$PSScriptRoot\_comun.ps1"

Start-Registro '01_levantar_cluster'
Test-Docker

Show-Contexto 'Paso 0: liberar los puertos del clúster (26257, 8080, 8081, 8082)'
$puertos = '26257', '8080', '8081', '8082'
$ocupan = docker ps --format '{{.Names}}|{{.Ports}}' | Where-Object {
    $nombre, $p = $_ -split '\|', 2
    $nombre -notmatch '^roach[123]$' -and ($puertos | Where-Object { $p -match "0\.0\.0\.0:$_->" })
} | ForEach-Object { ($_ -split '\|')[0] }
if ($ocupan) {
    foreach ($c in $ocupan) {
        Write-Host "El contenedor '$c' ocupa un puerto del clúster; se detiene (vuelve a encenderlo luego con: docker start $c)." -ForegroundColor Yellow
        Invoke-Docker stop $c
    }
} else {
    Write-Host 'Puertos libres.'
}

Show-Contexto 'Paso 1: levantar los 3 contenedores'
Invoke-Docker compose -f $Compose up -d --quiet-pull
if ($CodigoSalida -ne 0) { Write-Host 'docker compose up falló.' -ForegroundColor Red; Stop-Registro; exit 1 }
Wait-Segundos 15 'arranque de los nodos'

Show-Contexto 'Paso 2: inicializar el clúster'
Invoke-Docker exec roach1 ./cockroach init --insecure --host=roach1:26257
if (($Salida -join ' ') -match 'already been initialized') {
    Write-Host 'El clúster ya estaba inicializado; se continúa.' -ForegroundColor Yellow
} elseif ($CodigoSalida -ne 0) {
    Write-Host 'cockroach init falló.' -ForegroundColor Red
    Stop-Registro; exit 1
} else {
    Wait-Segundos 10 'los nodos se unen y replican los rangos del sistema'
}

Show-Contexto 'Paso 3: estado de los nodos'
Show-NodeStatus
Request-Captura 1 'node status con los 3 nodos (is_available e is_live = true), tu usuario y la fecha'

Show-Contexto 'Paso 4: crear base banco, tabla cuentas e insertar datos'
Invoke-Sql roach1 "CREATE DATABASE IF NOT EXISTS banco; CREATE TABLE IF NOT EXISTS banco.cuentas (id INT PRIMARY KEY, titular STRING, saldo DECIMAL); INSERT INTO banco.cuentas VALUES (1, 'Daniel Bueno', 500), (2, 'Cuenta prueba UTEQ', 300) ON CONFLICT (id) DO NOTHING;"
Invoke-Sql roach1 'SELECT * FROM banco.cuentas ORDER BY id;'

Show-Contexto 'Paso 5: esperar a que el rango de la tabla tenga 3 réplicas'
# Una tabla nueva nace con 1 réplica; el clúster la copia a los otros nodos en unos segundos.
for ($k = 0; $k -lt 24; $k++) {
    $rep = docker exec roach1 ./cockroach sql --insecure --host=roach1:26257 --format=csv -e 'SELECT replicas FROM [SHOW RANGES FROM TABLE banco.cuentas WITH DETAILS];' 2>$null | Select-Object -Last 1
    Write-Host ("  {0}  réplicas = {1}" -f (Get-Date -Format 'HH:mm:ss'), $rep)
    if ($rep -match '\{1,2,3\}') { break }
    Start-Sleep -Seconds 5
}

Show-Contexto 'Paso 6: rangos, réplicas y leaseholder de la tabla'
Invoke-Sql roach1 'SHOW RANGES FROM TABLE banco.cuentas WITH DETAILS;' 'records'
Write-Host 'Resumen (columnas clave):'
Invoke-Sql roach1 'SELECT range_id, lease_holder, replicas, voting_replicas FROM [SHOW RANGES FROM TABLE banco.cuentas WITH DETAILS];'
Request-Captura 2 'SHOW RANGES: replicas {1,2,3} (3 copias) y el lease_holder del rango'

Show-Contexto 'Paso 7: abrir el panel web (DB Console)'
if ($SinPausa) {
    $r = Invoke-WebRequest -UseBasicParsing http://localhost:8080 -TimeoutSec 10
    Write-Host "Panel web responde: HTTP $($r.StatusCode)"
} else {
    Start-Process 'http://localhost:8080'
}
Request-Captura 3 'panel web en localhost:8080 con los 3 nodos vivos y el reloj de Windows visible'

Stop-Registro
