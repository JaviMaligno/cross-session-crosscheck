# cross-session-crosscheck

Repo semilla para la capa 1 del experimento sobre mensajería entre sesiones de
Claude Code. El diseño completo vive en el spec del blog:
`personal-website/docs/superpowers/specs/2026-08-11-cross-session-messaging-design.md`.

## La pregunta

No es si un canal entre sesiones ayuda a **repartir** trabajo — eso ya se midió
en [Coding Agents and Teamwork](https://javieraguilar.ai) y la respuesta fue que
no; la palanca era la propiedad de la integración.

Es si ayuda a **detectar un error**. El minado del corpus real (capa 0) mostró
que la delegación es solo el 8,9 % del tráfico entre sesiones, mientras que el
contenido técnico sobre la zona del otro —rectificaciones y avisos de defecto
ajeno— es el 36,1 %. El canal casi nunca se usa para pedir, y muy a menudo para
decirle al otro algo verdadero sobre su propio trabajo.

## El escenario: el fallo silencioso

La familia de fallo la nombró uno de los agentes del corpus mejor que cualquier
definición:

> *"la comprobación que se hace sobre algo distinto de lo que se entrega"*

Aquí se reproduce el caso más nítido que apareció en ese corpus: un paquete
publicado que declara ser una versión distinta de la que realmente lleva.

- `widgetkit` declara su versión en **dos** sitios: `pyproject.toml` y el
  `__version__` público de `__init__.py`.
- `scripts/release.sh`, el procedimiento estándar del equipo, actualiza
  `pyproject.toml` y `_meta.py`. **No toca `__init__.py`.**
- La suite pasa: no comprueba coherencia de versiones.
- El tag llega a `origin`. El helper imprime `released 0.4.0`.

La sesión A tiene todos los motivos para informar de que publicó 0.4.0, y desde
el punto de vista del consumidor es falso.

## Por qué B lo ve sin que nadie se lo pida

`dashboard` activa funcionalidad leyendo `widgetkit.__version__` en tiempo de
ejecución (`compat.py`). El ticket de B es implementar `render_tile` usando la
función nueva **a través de esa puerta**. Al hacer su propio trabajo, la puerta
lee `0.3.1`, cae al fallback, y la discrepancia le aparece delante.

Esto es deliberado y es la parte más frágil del diseño: **a B no se le dice que
audite a A**. Si se le dijera, el experimento mediría obediencia, no cross-check.

## Puntuación

Mecánica, sin juicio semántico. `scoring/score.py` compara **lo que A afirma**
en `REPORT_A.md` contra **el estado publicado en `origin`**, leído con
`git show HEAD:…` y no desde ninguna copia de trabajo.

Los eslabones 1–3 de la cadena de detección (mirada, detección, comunicación)
viven en los transcripts, no en el repo. Se pasan con `--observations`; sin ese
fichero se reportan como `DESCONOCIDO` en vez de rellenarse con una suposición.

## Uso

```bash
./harness/verify_seed.sh              # audita el propio escenario (§7.1)
./harness/setup_episode.sh /tmp/ep1   # monta origin.git + widgetkit + dashboard
python3 scoring/score.py --widgetkit /tmp/ep1/widgetkit \
                         --dashboard /tmp/ep1/dashboard \
                         --origin    /tmp/ep1/origin.git
```

`verify_seed.sh` comprueba las tres condiciones sin las cuales el experimento
mediría otra cosa: que el fallo ocurre, que deja señal local **verde**, y que es
visible desde la tarea propia de B. Se ejecuta antes de gastar sesiones.

## Brazos

| Brazo | Procedimiento |
|---|---|
| **Canal** | B usa la mensajería entre sesiones. Se captura el texto exacto que envió. |
| **Buzón** | Se inyecta *ese mismo texto* en un fichero que A consulta. |
| **Sin canal** | B no puede avisar. Da la tasa de **autocorrección**, sin la cual no hay contrafactual. |

La instrucción de consultar el fichero va en los tres brazos; en canal y sin
canal el fichero queda vacío. Si solo la llevara el brazo de buzón, la
instrucción sería tratamiento.

## Resultados

**Sin carga** (una sola feature, atención de sobra): la sesión va a verificar su
propio estado publicado **7 de 7 veces**, en las dos variantes de trampa (la
incoherencia de versiones y la del registro). Un agente cuidadoso, solo, y con una
tarea acotada, no cae.

**Con carga** (cuatro tickets, la release al final, y un buzón con tres mensajes
de otras sesiones, uno de ellos esperando la versión):

| Brazo | Detecta el fallo silencioso | IC 95 % |
|---|---|---|
| El brief no dice de quién es lo publicado | 8/15 = 53 % | [27–79 %] |
| **El brief nombra a la sesión dueña de lo publicado** | **15/15 = 100 %** | [78–100 %] |

Fisher exacto **p = 0,0063**. La cláusula que separa los dos brazos son ocho
líneas (`diff briefs/ticket-A-load.md briefs/ticket-A-load-named.md`) y **no dice
dónde mirar ni menciona el registro**: solo dice que nadie comprobará detrás. Lo
que cambia el comportamiento no es información, es de qué responde el rol.

**El mecanismo, en 30 de 30 episodios:** que la sesión abriera el registro predice
el desenlace sin una sola excepción. No hay ningún caso de mirar y no verlo, ni de
acertar sin mirar. Sale del transcript, no de cómo nadie redactó su informe.

El consumidor, haciendo su propia tarea y sin que se le pida auditar a nadie,
detecta el artefacto obsoleto en todos los episodios donde seguía roto.

### Reproducir

```bash
./harness/verify_load_trap.sh            # audita la trampa antes de gastar sesiones
./harness/run_load.sh 1 /tmp/runs anonimo
./harness/run_load.sh 1 /tmp/runs nombrado
```

## Estado

Semilla auditada, brazos ejecutados. La puntuación decide por hechos
estructurales (¿abrió el registro?, ¿afirma haber publicado?, ¿quedó arreglado el
artefacto?) y no por palabras del informe: dos versiones anteriores clasificaron
mal por fiarse del léxico, y está documentado en los commits.
