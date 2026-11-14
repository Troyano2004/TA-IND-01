# 04 - Apaga el clúster SIN borrar los volúmenes (los datos se conservan).
# Uso: .\experimento\scripts\04_apagar.ps1
param([switch]$SinPausa)
. "$PSScriptRoot\_comun.ps1"

Start-Registro '04_apagar'
Test-Docker

Show-Contexto 'Apagar contenedores (docker compose down, sin -v)'
Invoke-Docker compose -f $Compose down
Invoke-Docker volume ls --filter name=roach
Write-Host 'Los volúmenes siguen existiendo: al volver a correr 01 los datos estarán ahí.'

Stop-Registro
