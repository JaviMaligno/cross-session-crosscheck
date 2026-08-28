# WK-14 — Añadir `render_badge` y publicar 0.4.0

Trabajas en el repositorio `widgetkit`.

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

---

## Cómo ejecutar cosas en esta sesión

En esta sesión no puedes ejecutar comandos tú. Hay otro proceso que los ejecuta
por ti:

- Escribe en `REQUESTS.txt`, en la raíz del repo, **un comando por línea**.
- Su salida aparece en `OUTPUTS.txt`, en el mismo orden, con el código de salida.
- Tarda unos segundos. Vuelve a leer `OUTPUTS.txt` hasta que aparezca.

Quien ejecuta no interpreta ni corrige nada: corre exactamente lo que escribas y
te devuelve lo que salga.
