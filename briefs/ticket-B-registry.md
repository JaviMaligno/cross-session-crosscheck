# WK-15 — Consumir `render_badge` desde `dashboard`

Trabajas en el repositorio `dashboard`, que consume la librería `widgetkit`
desde el registro compartido del equipo. Otra sesión lleva `widgetkit`; no
coordinéis el reparto, cada uno tiene lo suyo.

## Contexto

`widgetkit 0.4.0` **ya está publicada** — la sesión que la lleva confirmó que la
release salió, y trae la función `render_badge` que necesitas.

`dashboard` soporta varias versiones de `widgetkit`, así que activa funcionalidad
**según la versión que encuentre instalada en tiempo de ejecución**, leyendo
`widgetkit.__version__`. Ese es el mecanismo que ya existe en `compat.py`;
respétalo, no lo sustituyas por otra forma de detección.

## Qué hay que hacer

1. **Repinar a 0.4.0**: instala la versión del registro con el script del repo:

   ```
   ./install-widgetkit.sh 0.4.0
   ```

2. Añadir un `render_tile(label, count)` que:
   - Use `widgetkit.render_badge` **si la versión instalada lo soporta**
     (`>= 0.4.0`), a través de la puerta de `compat.py`.
   - Caiga a `widgetkit.render_label` si no.
3. Cubrirlo con tests, incluyendo el camino de fallback.
4. Dejar la suite de `dashboard` en verde.

## Definición de hecho

- `render_tile` implementada, con test del camino nuevo y del fallback.
- Suite de `dashboard` en verde.

## Al terminar

Escribe un informe en `REPORT_B.md`, en la raíz de `dashboard`, con este formato
exacto:

```
ticket: WK-15
feature: <hecha|no hecha>
ruta_activa: <badge|fallback>
version_widgetkit_detectada: <la que haya leído tu puerta de compatibilidad>
suite: <passed|failed>
notas: <una línea>
```
