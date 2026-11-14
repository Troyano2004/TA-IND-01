# TA-IND-01 — Análisis crítico de CockroachDB frente a Google Spanner

Sistemas Distribuidos, UTEQ. Estudiante: Erwin Daniel Bueno Troya.

## Video de sustentación

Enlace (Google Drive, acceso abierto): https://drive.google.com/drive/folders/1lKomzby1yBSvcqb9dh_gUM2cs1AvAV3y?usp=sharing

## Estructura del repositorio

- `docker-compose.yml`: clúster local de CockroachDB con 3 nodos.
- `experimento/scripts/`: scripts de PowerShell del experimento (01 a 04).
- `experimento/salidas/`: salidas obtenidas, incluida la prueba previa y `latencias.csv`.
- `capturas/`: capturas de la ejecución del clúster con usuario, equipo y fecha.
- `informe/`: fuente LaTeX (`main.tex`), bibliografía (`referencias.bib`), figuras, capturas y anexos.
- `informe/main.pdf`: informe compilado.
- `BITACORA.md`: registro de cada sesión de trabajo.

## Cómo levantar el clúster

Requisito: Docker Desktop.

```powershell
docker compose up -d
docker exec roach1 ./cockroach init --insecure --host=roach1
docker exec roach1 ./cockroach node status --insecure --host=roach1
```

Los pasos del experimento están en `experimento/scripts/` (01 a 04) y las salidas en `experimento/salidas/`.

## Cómo compilar el informe

- Compilador: pdflatex (MiKTeX o TeX Live)
- Archivo principal: `informe/main.tex`
- Bibliografía: biblatex con estilo `ieee` y backend `biber`
- Dependencias: paquetes `biblatex`, `biblatex-ieee`, `babel` (spanish), `graphicx`, `hyperref`, `booktabs`, `csquotes`, `tikz`, `lmodern`, `array`, `float`, `amssymb`, `listings`, `xcolor`

Orden de comandos, desde la carpeta `informe/`:

```
pdflatex main.tex
biber main
pdflatex main.tex
pdflatex main.tex
```
