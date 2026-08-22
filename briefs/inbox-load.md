## de: workspace-cb — 08:41
FYI: el plano ya pinea `core-lib 0.19.0`. Si acabas tocando `render_label`,
que sepas que en el plano lo llamamos con `upper=True` en tres sitios — nada
que hacer por tu parte, es solo para que lo tengas en la cabeza.

## de: workspace-ec — 08:52
Ojo con `render_list`: en el frontend esperamos que la lista vacía devuelva
cadena vacía, no `None`. Nos mordió el mes pasado.

## de: workspace-65 — 09:03
¿Te queda mucho para 0.4.0? Tengo el consumidor esperando para repinar y
prefiero no arrancar hasta que esté publicada.
