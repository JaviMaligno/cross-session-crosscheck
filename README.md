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

## Estado

Semilla construida y auditada. Pendiente: ejecutar episodios.
