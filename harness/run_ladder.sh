#!/usr/bin/env bash
# Un episodio de la escalera de profundidad.
#
#   run_ladder.sh <L2|L3|L4> <semilla> <base> <puerto> [modelo]
#
# Todas las celdas son R0 —sin restriccion— y con carga, que es la condicion
# realista y la que ya esta medida en L1 para los tres modelos. La restriccion
# no es variable aqui: la pieza anterior midio que apenas mueve nada.
set -euo pipefail

LEVEL="${1:?usage: run_ladder.sh <L2|L3|L4> <semilla> <base> <puerto> [modelo]}"
SEED="${2:?falta la semilla}"
BASE="${3:?falta el directorio base}"
PORT="${4:?falta el puerto}"
MODEL="${5:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MTAG=""
case "$MODEL" in
  ''|*opus*) MTAG="" ;;
  *sonnet*)  MTAG="_sonnet" ;;
  *haiku*)   MTAG="_haiku" ;;
esac
EP="$BASE/ep_${LEVEL}${MTAG}_s${SEED}"

"$ROOT/harness/setup_episode_v4.sh" "$EP" "$LEVEL" "$PORT" >/dev/null

cp "$ROOT/briefs/ticket-A-load-solo.md" "$EP/widgetkit/TICKET.md"
cp "$ROOT/briefs/inbox-load.md" "$EP/widgetkit/INBOX.md"
git -C "$EP/widgetkit" config user.email a@local
git -C "$EP/widgetkit" config user.name  sessionA

# Lista permisiva a proposito. La restriccion no se mide aqui, y en la tanda
# anterior una lista estrecha bloqueo tres episodios por escribir la misma orden
# con otra grafia — un artefacto que se leyo como "el modelo debil no completa la
# tarea". Aqui cualquier bloqueo seria ruido puro.
TOOLS=(Read Write Edit Glob Grep
       "Bash(git *)" "Bash(python *)" "Bash(python3 *)" "Bash(pytest *)"
       "Bash(./scripts/release.sh *)" "Bash(scripts/release.sh *)"
       "Bash(bash *)" "Bash(sh *)" "Bash(cd *)"
       "Bash(ls *)" "Bash(cat *)" "Bash(head *)" "Bash(tail *)" "Bash(sed *)"
       "Bash(grep *)" "Bash(rg *)" "Bash(find *)" "Bash(diff *)" "Bash(pip *)"
       "Bash(tar *)" "Bash(curl *)"
       "Bash(wk-inspect *)" "Bash(wk-publish *)" "Bash(wk-verify-release *)")

MODEL_ARG=()
[ -n "$MODEL" ] && MODEL_ARG=(--model "$MODEL")

cleanup() {
  [ -f "$EP/registry.pid" ] && kill "$(cat "$EP/registry.pid")" 2>/dev/null
  return 0
}
trap cleanup EXIT

echo "==> [$LEVEL${MTAG} s$SEED] sesion"
( cd "$EP/widgetkit"
  # shellcheck disable=SC1091
  . "$EP/env.sh"
  PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 claude -p "$(cat TICKET.md)" \
    ${MODEL_ARG[@]+"${MODEL_ARG[@]}"} \
    --allowedTools "${TOOLS[@]}" \
    --output-format json > "$EP/run_A.json" 2> "$EP/run_A.err"
) || echo "  (la sesion termino con error, ver run_A.err)"

cleanup
trap - EXIT

# el modelo que corrio de verdad, leido del resultado y no del argumento
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

echo "==> [$LEVEL${MTAG} s$SEED] informe"
sed -n '1,40p' "$EP/widgetkit/REPORT_A.md" 2>/dev/null || echo "(sin informe)"
