#!/usr/bin/env bash
# Corre un episodio de la serie "lo que cuesta la restriccion"
# (spec 2026-08-28-constraint-cost-design).
#
#   run_regime.sh <R0|R1|R2> <semilla> <base> [puerto] [load]
#
# El regimen cambia DOS cosas y solo dos:
#   - que herramientas tiene la sesion (R1 no tiene Bash: no ejecuta nada)
#   - si el entorno trae la credencial de lectura del registro (R2 no la trae)
#
# El quinto argumento, `load`, anade la SEGUNDA variable: cuatro tickets en vez
# de uno y un inbox con tres mensajes, uno preguntando por la 0.4.0. Es la
# condicion donde la pieza anterior encontro la grieta (7/7 sin carga, 2/3 con
# ella), y aqui se cruza con la restriccion.
#
# El brief es el mismo dentro de cada nivel de carga; R1 anade el bloque del
# protocolo del runner y nada mas, verificable con diff.
set -euo pipefail

REGIME="${1:?usage: run_regime.sh <R0|R1|R2> <semilla> <base> [puerto] [load] [modelo]}"
SEED="${2:?falta la semilla}"
BASE="${3:?falta el directorio base}"
PORT="${4:-8900}"
LOAD="${5:-}"
MODEL="${6:-}"   # vacio = el modelo por defecto de la CLI
NOTOOLSDOC="${7:-}"  # "notools" = quita TOOLS.md del repo semilla

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUFFIX=""
[ "$LOAD" = "load" ] && SUFFIX="_load"
# El eje de capacidad va en el nombre del episodio: sin el, dos tandas con
# modelos distintos se pisan en el mismo directorio y la tabla mezcla ejes.
MTAG=""
case "$MODEL" in
  ''|*opus*) MTAG="" ;;
  *haiku*)   MTAG="_haiku" ;;
  *)         MTAG="_$(echo "$MODEL" | tr -cd 'a-zA-Z0-9-' | cut -c1-12)" ;;
esac
NTAG=""
[ "$NOTOOLSDOC" = "notools" ] && NTAG="_notools"
EP="$BASE/ep_${REGIME}${SUFFIX}${MTAG}${NTAG}_s${SEED}"

"$ROOT/harness/setup_episode_v3.sh" "$EP" "$REGIME" "$PORT" >/dev/null

# Variante para separar "la carga importa menos" de "la comprobacion estaba
# documentada": mismo sustrato, sin la ficha que nombra wk-inspect. La
# herramienta sigue en el PATH; lo que desaparece es que te la cuenten.
if [ "$NOTOOLSDOC" = "notools" ]; then
  rm -f "$EP/widgetkit/TOOLS.md"
  git -C "$EP/widgetkit" add -A >/dev/null 2>&1
  git -C "$EP/widgetkit" -c user.email=seed@local -c user.name=seed \
      commit -q -m "seed: sin ficha de herramientas" >/dev/null 2>&1
  git -C "$EP/widgetkit" push -q origin HEAD >/dev/null 2>&1
fi

if [ "$LOAD" = "load" ]; then
  case "$REGIME" in
    R1) cp "$ROOT/briefs/ticket-A-load-mediated.md" "$EP/widgetkit/TICKET.md" ;;
    *)  cp "$ROOT/briefs/ticket-A-load-solo.md"     "$EP/widgetkit/TICKET.md" ;;
  esac
  cp "$ROOT/briefs/inbox-load.md" "$EP/widgetkit/INBOX.md"
else
  case "$REGIME" in
    R1) cp "$ROOT/briefs/ticket-A-mediated.md" "$EP/widgetkit/TICKET.md" ;;
    *)  cp "$ROOT/briefs/ticket-A-solo.md"     "$EP/widgetkit/TICKET.md" ;;
  esac
fi

git -C "$EP/widgetkit" config user.email a@local
git -C "$EP/widgetkit" config user.name  sessionA

# Herramientas. R0 y R2 comparten lista EXACTA: en R2 la inspeccion falla por
# falta de credencial, nunca por falta de permiso. R1 no tiene Bash en absoluto.
COMMON_TOOLS=(Read Write Edit Glob Grep
              "Bash(git *)" "Bash(python *)" "Bash(python3 *)" "Bash(pytest *)"
              "Bash(./scripts/release.sh *)" "Bash(ls *)" "Bash(cat *)"
              "Bash(tar *)" "Bash(curl *)"
              "Bash(wk-inspect *)" "Bash(wk-publish *)")
MEDIATED_TOOLS=(Read Write Edit Glob Grep)

RUNNER_PID=""
if [ "$REGIME" = "R1" ]; then
  python "$ROOT/tools/runner.py" --dir "$EP/widgetkit" --env "$EP/env.sh" &
  RUNNER_PID=$!
fi

cleanup() {
  [ -n "$RUNNER_PID" ] && kill "$RUNNER_PID" 2>/dev/null
  [ -f "$EP/registry.pid" ] && kill "$(cat "$EP/registry.pid")" 2>/dev/null
  return 0
}
trap cleanup EXIT

echo "==> [$REGIME s$SEED] sesion A"
if [ "$REGIME" = "R1" ]; then
  TOOLS=("${MEDIATED_TOOLS[@]}")
else
  TOOLS=("${COMMON_TOOLS[@]}")
fi

MODEL_ARG=()
[ -n "$MODEL" ] && MODEL_ARG=(--model "$MODEL")

( cd "$EP/widgetkit"
  # shellcheck disable=SC1091
  . "$EP/env.sh"
  PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 claude -p "$(cat TICKET.md)" \
    ${MODEL_ARG[@]+"${MODEL_ARG[@]}"} \
    --allowedTools "${TOOLS[@]}" \
    --output-format json > "$EP/run_A.json" 2> "$EP/run_A.err"
) || echo "  (la sesion termino con error, ver run_A.err)"

# El modelo que de verdad corrio se lee del propio resultado, no del argumento:
# un --model rechazado caeria al de por defecto y la tabla mezclaria ejes sin
# avisar. Es el mismo cuidado que el log de accesos: medir, no suponer.
python - "$EP/run_A.json" "$EP/model.txt" <<'PY' 2>/dev/null || true
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding='utf-8', errors='replace'))
    mu = d.get('modelUsage') or {}
    open(sys.argv[2], 'w', encoding='utf-8').write(
        ','.join(mu.keys()) or str(d.get('model', '?')))
except Exception:
    pass
PY

cleanup
trap - EXIT

echo "==> [$REGIME s$SEED] puntuacion"
python "$ROOT/scoring/score_regime.py" --episode "$EP" --regime "$REGIME" \
  > "$EP/score.json" || true
cat "$EP/score.json"
