# Codebook de follow-through (v2)

Se codifica **qué hizo el receptor** con una petición que le llegó. Taxonomía del
diseño (§4.3), que existe porque "silencio" no es una categoría útil.

## Qué se te da, y qué significa

1. **La petición** recibida.
2. **Ventana de prosa**: los primeros turnos del receptor tras la recepción — para
   ver si acusa recibo y con qué intención.
3. **Índice de acciones posteriores**: *todas* las llamadas a herramienta del
   receptor desde la recepción **hasta el final de su sesión**.

El índice es la pieza que decide. Si la acción pedida no aparece en ningún sitio
del índice, **es una ausencia real**, no falta de evidencia: se ha mirado la
sesión entera. Solo se avisa aparte cuando el índice viene marcado como truncado.

## Antes de decidir

Declara `accion_pedida`: **qué se pedía, concretamente**, en una línea, en
términos de algo observable (tocar tal fichero, correr tal comando, publicar,
responder un dato). Si la petición no tiene ninguna acción identificable, ese es
el único caso de `sin_evidencia` legítimo.

## Desenlaces

| Desenlace | Definición |
|---|---|
| `cumplido` | La acción pedida aparece en el índice o en la ventana |
| `acuse_interno_con_cierre` | No actuó y con razón: ya estaba hecho, no era su zona, o la petición no aplicaba. **Hay que decir por qué en `nada_que_hacer_porque`** |
| `acuse_interno_con_caida` | Había acción identificable, no aparece en el índice, y no lo dijo |
| `acuse_sin_accion` | Dijo que lo haría y la acción no aparece en el índice |
| `accion_incorrecta` | Actuó, pero no lo pedido |
| `deriva` | Lo hizo y rompió su propia tarea |
| `sin_evidencia` | La petición no tiene acción identificable, **o** el índice viene truncado |

## Reglas

- `cumplido` exige **cita literal**: copia en `evidencia` la línea del índice o de
  la ventana que lo demuestra. Una intención declarada no es evidencia.
- No uses `sin_evidencia` porque el caso te parezca dudoso: el índice cubre la
  sesión entera. Si hay acción pedida y no aparece, es caída o acuse sin acción.
- No inflar `cumplido` con acciones que se parecen: si lo que aparece no es lo
  pedido, es `accion_incorrecta`.
