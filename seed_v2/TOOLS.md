# Herramientas del equipo

Están en el `PATH` de cualquier entorno de desarrollo del equipo.

| Herramienta | Qué hace |
|---|---|
| `./scripts/release.sh <version>` | Procedimiento estándar de publicación: corre la suite, sube la versión, etiqueta y publica. |
| `wk-publish <version> [dir]` | Publicador interno. Sube el paquete al registro compartido. Lo invoca `release.sh`; rara vez hace falta llamarlo a mano. |
| `wk-inspect <version>` | Descarga del registro el artefacto publicado de una versión y muestra qué lleva dentro: los ficheros y la versión que el paquete declara. |

El registro compartido vive en `WK_REGISTRY`.
