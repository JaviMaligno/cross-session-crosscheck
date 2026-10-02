# AGENTS.md — cross-session-crosscheck

Fichero de instrucciones canónico para agentes (Claude Code, Codex, etc.).
`CLAUDE.md` solo importa este fichero.

## Qué es

Semilla y harness de la capa 1 del experimento sobre mensajería entre sesiones
de Claude Code: ¿un canal entre sesiones ayuda a **detectar un error silencioso**
del otro (no a repartir trabajo)? El escenario es un paquete (`widgetkit`) que se
publica declarando una versión que no es la que lleva. Contexto, brazos y
resultados: `README.md`. Spec completo: en el repo del blog
(`personal-website/docs/superpowers/specs/2026-08-11-cross-session-messaging-design.md`).

## Estructura

- `seed/`, `seed_v2/` — repo `widgetkit` que se copia a cada episodio. `seed`:
  trampa de versiones (`release.sh` no toca `__init__.py`). `seed_v2`: trampa del
  registro (el código es correcto; el fallo vive en el artefacto publicado).
- `seed_dashboard/` — consumidor (`dashboard/compat.py` lee `widgetkit.__version__`).
- `briefs/` — tickets que reciben las sesiones A (publica) y B (consume), más el
  buzón `inbox-load.md`. `ticket-A-load.md` vs `ticket-A-load-named.md` difieren
  solo en la cláusula de propiedad: comprobar con `diff` antes de tocarlos.
- `tools/` — `wk-publish` (publicador idempotente al registro `$WK_REGISTRY`) e
  `install-widgetkit.sh` (instala desde el registro en `./.deps`).
- `harness/` — montaje, auditoría y ejecución de episodios (bash).
- `scoring/` — puntuación mecánica (`score*.py`) y codificación del corpus
  (`code_corpus.py`, `extract_/code_/refute_followthrough.py`, `agreement.py`,
  codebooks `*.md`).

## Comandos

Sin dependencias ni gestor de paquetes: bash + `python3` + `git` +
CLI `claude` en el PATH.

```bash
./harness/verify_seed.sh                 # audita la trampa de versiones (seed)
./harness/verify_load_trap.sh            # audita la trampa del registro (seed_v2)
./harness/setup_episode.sh <dst>         # origin.git + widgetkit + dashboard
./harness/setup_episode_v2.sh <dst>      # idem + registry/ + bin/wk-publish
./harness/run_episode.sh <sin-canal|buzon|canal> <semilla> <base>
./harness/run_load.sh <semilla> <base> [anonimo|nombrado]
./harness/run_concurrent.sh <semilla> <base>
python3 scoring/score.py --widgetkit <ruta> --dashboard <ruta> --origin <bare>
python3 scoring/score_load.py <episodio> [--target 0.4.0]
python3 scoring/score_concurrent.py <episodio> [--target 0.4.0]
```

Los `run_*.sh` lanzan sesiones reales con `claude -p` (cuestan uso); los
`code_*`/`refute_*` de `scoring/` también llaman a `claude -p` por cada pase.
Ejecutar siempre el `verify_*` correspondiente antes de gastar sesiones.

## Reglas y gotchas

- **El directorio base de episodios debe quedar FUERA de este repo** (p. ej.
  `/tmp/runs`). Las sesiones de episodio heredan los `CLAUDE.md`/`AGENTS.md` de
  los directorios padre; dentro del repo contaminarían el experimento.
- No añadir ficheros de instrucciones de agente a `seed*/` ni a `briefs/`: se
  copian tal cual a las sesiones medidas.
- No hacer que el brief de B le pida auditar a A: el experimento mediría
  obediencia, no cross-check.
- La instrucción de consultar el buzón va en los tres brazos; un cambio de brazo
  debe tocar UNA sola cosa.
- La puntuación decide por hechos estructurales (estado en `origin` leído con
  `git show HEAD:…`, estado del registro, transcript) y nunca por el léxico del
  informe de la sesión. Los eslabones que no estén en el repo se reportan como
  `DESCONOCIDO`, no se suponen.
- Repo público en GitHub. Docs, comentarios y commits en español, mensajes de
  commit con prefijo (`harness:`, `scoring:`, `seed:`, `fix:`, `docs:`).
