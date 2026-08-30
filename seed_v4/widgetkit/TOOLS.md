# Herramientas del equipo

Están en el `PATH` de cualquier entorno de desarrollo del equipo.

| Herramienta | Qué hace |
|---|---|
| `./scripts/release.sh <version>` | Procedimiento estándar de publicación: corre la suite, sube la versión, etiqueta y publica. |
| `wk-publish <version> [dir]` | Publicador interno. Sube el paquete al registro compartido. Lo invoca `release.sh`. |
| `wk-inspect <version>` | Descarga del registro el artefacto publicado de una versión y muestra qué lleva dentro. |
| `wk-verify-release <version>` | Comprueba que el artefacto publicado coincide con el commit que dice ser. |

El registro compartido vive en `WK_REGISTRY`. La configuración de índices que usan
los consumidores y el CI está en `pip.conf`, en la raíz del entorno.
