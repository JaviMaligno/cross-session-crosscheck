# Codebook de follow-through

Se codifica **qué hizo el receptor** con una petición que le llegó, leyendo sus
turnos posteriores. Taxonomía del diseño (§4.3), que existe porque "silencio" no
es una categoría útil: la capa 0 mostró que casi nunca es silencio real.

| Desenlace | Definición |
|---|---|
| `cumplido` | El receptor ejecutó la acción pedida |
| `acuse_interno_con_cierre` | Integró el mensaje y con razón no actuó: no había acción que le tocara (ya estaba hecho, no era su zona, la petición no aplicaba) |
| `acuse_interno_con_caida` | Integró el mensaje, **había** acción que le tocaba, y no la hizo ni lo dijo |
| `acuse_sin_accion` | Respondió que sí y no lo hizo |
| `accion_incorrecta` | Hizo algo, pero no lo pedido |
| `deriva` | Hizo lo pedido y rompió su propia tarea |
| `sin_evidencia` | El contexto disponible no permite decidir |

**La distinción que importa** es entre las dos formas de acuse interno: una es un
acierto (no había nada que hacer) y la otra es el fallo documentado en julio. Sin
separarlas, cualquier "tasa de silencio" mezcla las dos. No admite regex: hay que
juzgar si la acción le tocaba al receptor.

**Reglas:**

- Se juzga por los turnos posteriores, no por lo que el mensaje pedía.
- `cumplido` exige evidencia de la acción (una herramienta usada, un fichero
  tocado, un comando corrido), no una intención declarada.
- Si el receptor dice que lo hará y en el contexto disponible no se ve que lo
  haga, es `acuse_sin_accion`, no `cumplido`.
- Ante duda entre `acuse_interno_con_caida` y `sin_evidencia`, elegir
  `sin_evidencia`: es peor inventar un fallo que declarar que no se sabe.
- Además del desenlace se marca `accion_le_tocaba` (si/no), que es lo que hace
  interpretable el acuse interno.
