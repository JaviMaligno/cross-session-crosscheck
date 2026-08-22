# Codebook de mensajes entre sesiones

Rejilla usada para codificar el corpus del canal **peer**
(`<cross-session-message>`, 179 mensajes, artículo 2) y, con las mismas
definiciones, el corpus de **agent teams** (`<teammate-message>`).

Se escribe aquí porque en la capa 0 solo existía en la cabeza de la sesión que
codificó: el artículo publica los porcentajes y las κ, pero no las definiciones
con las que se obtuvieron. Sin esto, comparar teams contra peer no significa
nada — cualquier diferencia podría ser un cambio de criterio.

**Regla general:** se codifica **el mensaje**, no lo que ocurrió después. Si un
mensaje hace dos cosas, manda el motivo por el que se envió.

## Eje 1 — Categoría (10 valores, exclusivos)

| Categoría | Definición | Frontera |
|---|---|---|
| `aviso_alcance` | El emisor declara qué va a tocar o qué no toca | Territorio *futuro o presente*; si informa de algo ya terminado es progreso |
| `notificacion_progreso` | Estado del trabajo propio: hecho, desplegado, en vuelo | No pide nada ni afirma nada sobre la zona del otro |
| `handoff_recurso` | Cede o entrega algo que el otro necesita: fichero, entorno, campo libre | Aunque nadie lo haya pedido (cesión espontánea) |
| `aviso_defecto_ajeno` | Señala un defecto en el trabajo **del otro** | El defecto es del otro; si es propio, es rectificación |
| `rectificacion` | Corrige una afirmación previa, propia o del otro | Requiere que exista una afirmación anterior que se enmienda |
| `respuesta_estado` | Contesta a una pregunta de estado | Debe haber una consulta previa |
| `consulta_estado` | Pregunta en qué anda el otro, sin pedirle acción | Si además pide actuar, es petición de acción |
| `peticion_accion` | Pide al otro que haga algo | El emisor necesita la acción del otro |
| `peticion_espera` | Pide al otro que se detenga o espere su turno | Mutex en lenguaje natural |
| `otro` | No encaja en ninguna | Usar antes que forzar una categoría |

## Eje 2 — Delegación (sí/no)

`si` cuando **el emisor necesita que el receptor actúe para poder avanzar él**.
No basta con que el mensaje contenga una petición: un "avísame si te molesta"
no bloquea a nadie. `peticion_accion` casi siempre es delegación;
`peticion_espera` normalmente no (el que espera es el otro, no el emisor).

## Eje 3 — Capa (sintáctica/semántica)

Cruza las categorías, no las sigue:

- **`sintactica`** — quién toca qué y cuándo: territorio, turnos,
  disponibilidad, secuencia.
- **`semantica`** — si algo **es correcto**: un defecto, una afirmación
  enmendada, una verificación que contradice lo declarado.

Un `notificacion_progreso` que dice *"verificado por comportamiento, no por el
tag"* es **semántica**: afirma algo sobre la corrección de lo entregado. Un
`aviso_defecto_ajeno` es semántica por definición. Un `handoff_recurso` con un
aviso técnico dentro es semántica si el aviso es el motivo del mensaje.

Si los dos codificadores discrepan en este eje, el mensaje se **excluye** del
recuento por capa y se reporta como disputado, en vez de resolverlo a favor de
la hipótesis.
