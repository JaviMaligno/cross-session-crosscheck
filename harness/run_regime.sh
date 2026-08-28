#!/usr/bin/env bash
# Corre un episodio de la serie "lo que cuesta la restriccion"
# (spec 2026-08-28-constraint-cost-design).
#
#   run_regime.sh <R0|R1|R2> <semilla> <base> [puerto]
#
# El regimen cambia DOS cosas y solo dos:
#   - que herramientas tiene la sesion (R1 no tiene Bash: no ejecuta nada)
#   - si el entorno trae la credencial de lectura del registro (R2 no la trae)
#
# El brief de la tarea es el mismo en los tres; R1 anade el bloque del protocolo
# del runner y nada mas, lo que se verifica con diff antes de correr.
set -euo pipefail

REGIME="${1:?usage: run_regime.sh <R0|R1|R2> <semilla> <base> [puerto]}"
SEED="${2:?falta la semilla}"
BASE="${3:?falta el directorio base}"
PORT="${4:-8900}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EP="$BASE/ep_${REGIME}_s${SEED}"

"$ROOT/harness/setup_episode_v3.sh" "$EP" "$REGIME" "$PORT" >/dev/null

case "$REGIME" in
  R1) cp "$ROOT/briefs/ticket-A-mediated.md" "$EP/widgetkit/TICKET.md" ;;
  *)  cp "$ROOT/briefs/ticket-A-solo.md"     "$EP/widgetkit/TICKET.md" ;;
esac

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

( cd "$EP/widgetkit"
  # shellcheck disable=SC1091
  . "$EP/env.sh"
  PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 claude -p "$(cat TICKET.md)" \
    --allowedTools "${TOOLS[@]}" \
    --output-format json > "$EP/run_A.json" 2> "$EP/run_A.err"
) || echo "  (la sesion termino con error, ver run_A.err)"

cleanup
trap - EXIT

echo "==> [$REGIME s$SEED] puntuacion"
python "$ROOT/scoring/score_regime.py" --episode "$EP" --regime "$REGIME" \
  > "$EP/score.json" || true
cat "$EP/score.json"
