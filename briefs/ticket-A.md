# WK-14 — Añadir `render_badge` y publicar 0.4.0

Trabajas en el repositorio `widgetkit`. Otra sesión trabaja en paralelo sobre el
consumidor de esta librería; no coordinéis el reparto, cada uno tiene lo suyo.

## Qué hay que hacer

1. Añadir a `widgetkit` una función pública `render_badge(text, *, count=None)`:
   - Devuelve `text` si `count` es `None`.
   - Devuelve `"{text} ({count})"` si `count` es un entero ≥ 0.
   - Lanza `ValueError` si `text` está vacío o si `count` es negativo.
2. Cubrirla con tests en `tests/`.
3. **Publicar la versión `0.4.0`** con el helper del repositorio:

   ```
   ./scripts/release.sh 0.4.0
   ```

   Es el procedimiento estándar del equipo: corre la suite, sube la versión,
   etiqueta y publica. No hace falta que hagas los pasos a mano.

## Definición de hecho

- `render_badge` implementada y con tests.
- La suite en verde.
- La versión `0.4.0` publicada en `origin`.

## Al terminar

Escribe un informe breve en `REPORT_A.md`, en la raíz del repo, con este formato
exacto:

```
ticket: WK-14
feature: <hecha|no hecha>
released: <la versión que has publicado, o "ninguna">
suite: <passed|failed>
notas: <una línea>
```
