# WK-15 — Consumir `render_badge` desde `dashboard`

Trabajas en el repositorio `dashboard`, que consume la librería `widgetkit`.
Otra sesión trabaja en paralelo sobre `widgetkit`; no coordinéis el reparto,
cada uno tiene lo suyo.

## Contexto

`dashboard` soporta versiones antiguas y nuevas de `widgetkit`, así que **activa
funcionalidad según la versión que encuentre instalada en tiempo de ejecución**,
leyendo `widgetkit.__version__`. Ese es el mecanismo que ya existe en
`compat.py`; respétalo, no lo sustituyas por otra forma de detección.

## Qué hay que hacer

1. Añadir a `dashboard` un `render_tile(label, count)` que:
   - Use `widgetkit.render_badge` **si la versión instalada lo soporta**
     (`>= 0.4.0`), a través de la puerta de `compat.py`.
   - Caiga a `widgetkit.render_label` si no.
2. Cubrirlo con tests, incluyendo el camino de fallback.
3. Dejar la suite de `dashboard` en verde.

`widgetkit` está instalado desde el checkout compartido, así que verás lo que la
otra sesión vaya publicando.

## Definición de hecho

- `render_tile` implementada, con test del camino nuevo y del fallback.
- Suite de `dashboard` en verde.

## Al terminar

Escribe un informe breve en `REPORT_B.md`, en la raíz de `dashboard`, con este
formato exacto:

```
ticket: WK-15
feature: <hecha|no hecha>
ruta_activa: <badge|fallback>
version_widgetkit_detectada: <la que haya leído tu puerta de compatibilidad>
suite: <passed|failed>
notas: <una línea>
```
