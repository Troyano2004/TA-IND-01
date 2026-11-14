# 02 - Tolerancia a fallos y CAP: se cae 1 nodo (sigue funcionando), se caen 2 (sin quórum), se recuperan.
# Requiere haber corrido 01. Uso: .\experimento\scripts\02_falla_nodos.ps1   (-SinPausa omite las pausas)
param([switch]$SinPausa)
. "$PSScriptRoot\_comun.ps1"

Start-Registro '02_falla_nodos'
Test-Docker

Show-Contexto 'Paso 1: estado inicial'
Show-NodeStatus
Invoke-Sql roach1 'SELECT * FROM banco.cuentas ORDER BY id;'

Show-Contexto 'Paso 2: detener roach3 (queda 2 de 3 nodos: hay quórum)'
Invoke-Docker stop roach3
Wait-Segundos 15 'el clúster detecta que roach3 no responde'
Show-NodeStatus
Invoke-Sql roach1 "INSERT INTO banco.cuentas VALUES (3, 'Con un nodo caido', 100) ON CONFLICT (id) DO NOTHING;"
Invoke-Sql roach1 'SELECT * FROM banco.cuentas ORDER BY id;'
Request-Captura 4 'roach3 aparece no vivo, pero el INSERT de la fila 3 y el SELECT funcionan con 2 de 3 nodos'

Show-Contexto 'Paso 3: detener roach2 (queda 1 de 3 nodos: sin quórum)'
Invoke-Docker stop roach2
Wait-Segundos 10 'vence el lease del nodo que queda'
$t = Measure-Command {
    Invoke-Sql roach1 "SET statement_timeout = '10s'; SELECT * FROM banco.cuentas ORDER BY id;"
}
Write-Host ("Tiempo de la consulta: {0:F1} s (código de salida {1})" -f $t.TotalSeconds, $CodigoSalida) -ForegroundColor Magenta
if ($CodigoSalida -ne 0) {
    Write-Host 'La consulta NO se respondió: con 1 de 3 réplicas no hay mayoría (quórum) y el sistema prefiere no responder antes que dar datos inconsistentes (CP).' -ForegroundColor Magenta
}
Request-Captura 5 'la consulta falla por timeout (~10 s) porque no hay quórum'

Show-Contexto 'Paso 4: recuperar roach2 y roach3'
Invoke-Docker start roach2 roach3
Wait-Segundos 20 'los nodos vuelven y se ponen al día con el log de Raft'
Show-NodeStatus
foreach ($n in 'roach1', 'roach2', 'roach3') {
    Invoke-Sql $n 'SELECT * FROM banco.cuentas ORDER BY id;'
}
Request-Captura 6 'los 3 nodos vivos y la fila 3 visible también al consultar desde roach3'

Stop-Registro
