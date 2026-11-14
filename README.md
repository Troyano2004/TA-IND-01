# TA-IND-01 — Análisis crítico de CockroachDB frente a Google Spanner

Sistemas Distribuidos, UTEQ. Estudiante: Erwin Daniel Bueno Troya.

## Video de sustentación

Enlace: PENDIENTE

## Estructura del repositorio

- `docker-compose.yml`: clúster local de CockroachDB con 3 nodos.
- `experimento/`: comandos usados y salidas obtenidas.
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

Los pasos del experimento están en `experimento/comandos.md`.

## Cómo compilar el informe

- Compilador: pdflatex (MiKTeX o TeX Live)
- Archivo principal: `informe/main.tex`
- Bibliografía: biblatex con estilo `ieee` y backend `biber`
- Dependencias: paquetes `biblatex`, `biblatex-ieee`, `babel` (spanish), `graphicx`, `hyperref`, `booktabs`, `csquotes`

Orden de comandos, desde la carpeta `informe/`:

```
pdflatex main.tex
biber main
pdflatex main.tex
pdflatex main.tex
```
