# 03 - PACELC (rama "Else"): sin partición, elegir consistencia cuesta latencia.
# Una transacción A deja un bloqueo abierto 8 s; se mide una lectura consistente (espera)
# y una lectura histórica AS OF SYSTEM TIME '-5s' (no espera y devuelve el valor anterior).
# Requiere haber corrido 01. Uso: .\experimento\scripts\03_pacelc_latencia.ps1   (-SinPausa omite la pausa)
param([switch]$SinPausa, [int]$Intentos = 5)
. "$PSScriptRoot\_comun.ps1"

Start-Registro '03_pacelc_latencia'
Test-Docker

Show-Contexto 'Paso 1: dejar el saldo de la cuenta 1 en 500 (valor de partida conocido)'
Invoke-Sql roach1 'UPDATE banco.cuentas SET saldo = 500 WHERE id = 1;'
Wait-Segundos 6 'para que la lectura histórica de -5 s ya vea el saldo 500'

$sqlA = 'BEGIN; UPDATE banco.cuentas SET saldo = saldo - 100 WHERE id = 1; SELECT pg_sleep(8); COMMIT;'
# Señal de que A ya hizo su UPDATE: su sentencia pg_sleep aparece en ejecución en el clúster.
# ('pg_' || 'sleep' evita que esta misma consulta se cuente a sí misma)
$sqlEnEspera = "SELECT count(*) FROM [SHOW CLUSTER STATEMENTS] WHERE strpos(query, 'pg_' || 'sleep') > 0;"
$consultas = [ordered]@{
    consistente = 'SELECT * FROM banco.cuentas WHERE id = 1;'
    historica   = "SELECT * FROM banco.cuentas AS OF SYSTEM TIME '-5s' WHERE id = 1;"
}

function Measure-Lectura {
    param([string]$Tipo, [string]$Sql)
    $t = Measure-Command {
        $Global:Lectura = & docker exec roach1 ./cockroach sql --insecure --host=roach1:26257 --format=csv -e $Sql 2>&1 | ForEach-Object { "$_" }
    }
    $saldo = ($Lectura | ConvertFrom-Csv | Select-Object -First 1).saldo
    $ms = [math]::Round($t.TotalMilliseconds)
    Write-Host ("  {0,-12} {1,6} ms   saldo leído = {2}" -f $Tipo, $ms, $saldo)
    [pscustomobject]@{ intento = $script:i; tipo = $Tipo; ms = $ms; saldo_leido = $saldo }
}

$resultados = @()
for ($script:i = 1; $script:i -le $Intentos; $script:i++) {
    Show-Contexto "Intento $i de ${Intentos}: sesión A abre la transacción en segundo plano"
    Write-Host "Sesión A: $sqlA" -ForegroundColor DarkGray
    $job = Start-Job -ScriptBlock {
        param($sql)
        & docker exec roach1 ./cockroach sql --insecure --host=roach1:26257 -e $sql 2>&1 | ForEach-Object { "$_" }
    } -ArgumentList $sqlA

    # Esperar a que A esté dentro de pg_sleep: su UPDATE ya dejó la fila 1 bloqueada y aún no hace COMMIT
    $bloqueado = $false
    for ($k = 0; $k -lt 30 -and -not $bloqueado; $k++) {
        $n = & docker exec roach1 ./cockroach sql --insecure --host=roach1:26257 --format=csv -e $sqlEnEspera 2>$null | Select-Object -Last 1
        if ([int]$n -gt 0) { $bloqueado = $true }
    }
    if (-not $bloqueado) { Write-Host 'La sesión A no llegó a tomar el bloqueo; se omite este intento.' -ForegroundColor Red; $job | Wait-Job | Remove-Job -Force; continue }
    Write-Host 'Sesión A ya actualizó la fila 1 y está en pg_sleep(8): transacción abierta, sin COMMIT.'

    # Primero la histórica (no debe esperar), luego la consistente (debe esperar al COMMIT de A)
    $resultados += Measure-Lectura 'historica'   $consultas.historica
    $resultados += Measure-Lectura 'consistente' $consultas.consistente

    $job | Wait-Job | Receive-Job | Out-Null
    $job | Remove-Job
    if ($i -lt $Intentos) { Wait-Segundos 6 'separar intentos para que -5 s no se mezcle con el intento anterior' }
}

$csv = Join-Path $DirSalidas 'latencias.csv'
$resultados | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
Write-Host "Resultados guardados en $csv"

Show-Contexto 'Resumen: latencia por tipo de lectura'
$resultados | Format-Table -AutoSize | Out-Host
$resultados | Group-Object tipo | ForEach-Object {
    $m = $_.Group | Measure-Object ms -Average -Minimum -Maximum
    [pscustomobject]@{
        tipo           = $_.Name
        lecturas       = $m.Count
        promedio_ms    = [math]::Round($m.Average)
        minimo_ms      = $m.Minimum
        maximo_ms      = $m.Maximum
        saldos_leidos  = ($_.Group.saldo_leido -join ', ')
    }
} | Format-Table -AutoSize | Out-Host
Request-Captura 7 'la lectura consistente tarda varios segundos (espera el COMMIT) y la histórica responde rápido con el saldo anterior'

Show-Contexto 'Paso final: restaurar el saldo de la cuenta 1 a 500'
Invoke-Sql roach1 'UPDATE banco.cuentas SET saldo = 500 WHERE id = 1;'

Stop-Registro
