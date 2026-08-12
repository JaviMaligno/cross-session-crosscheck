#!/usr/bin/env bash
# Brazo de concurrencia: las dos sesiones vivas a la vez, con el canal abierto.
#
#   run_concurrent.sh <semilla> <directorio-base>
#
# Resuelve los tres problemas que tiene este brazo:
#
#  1. VENTANA. A tiene trabajo DESPUES de la release (WK-19), asi que sigue viva
#     y localizable cuando B descubre el problema.
#  2. ARRANQUE. B no arranca a ciegas: se espera a que el tag v0.4.0 aparezca en
#     origin, que es la senal de que A ya ha publicado. Antes de eso B estaria
#     mirando el artefacto obsoleto preexistente, que es otra situacion.
#  3. AISLAMIENTO. El canal queda abierto solo para estas dos sesiones; el brief
#     de B le prohibe explicitamente escribir a nada que no sea el widgetkit de
#     este episodio.
set -euo pipefail

SEED="${1:?usage: run_concurrent.sh <semilla> <base>}"
BASE="${2:?falta el directorio base}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EP="$BASE/conc_s${SEED}"

"$ROOT/harness/setup_episode_v2.sh" "$EP" >/dev/null
cp "$ROOT/briefs/ticket-A-concurrent.md" "$EP/widgetkit/TICKET.md"
cp "$ROOT/briefs/ticket-B-concurrent.md" "$EP/dashboard/TICKET.md"
cp "$ROOT/tools/install-widgetkit.sh"    "$EP/dashboard/install-widgetkit.sh"
chmod +x "$EP/dashboard/install-widgetkit.sh"
cat > "$EP/dashboard/conftest.py" <<'EOF'
import sys, pathlib
here = pathlib.Path(__file__).parent
sys.path.insert(0, str(here / ".deps" / "src"))
sys.path.insert(0, str(here / "src"))
EOF

git -C "$EP/widgetkit" config user.email a@local
git -C "$EP/widgetkit" config user.name  sessionA
git -C "$EP/dashboard" config user.email b@local
git -C "$EP/dashboard" config user.name  sessionB

export WK_REGISTRY="$EP/registry"
export PATH="$EP/bin:$PATH"
export PYTEST_DISABLE_PLUGIN_AUTOLOAD=1

TOOLS_A=(Read Write Edit Glob Grep "Bash(git *)" "Bash(python3 *)"
         "Bash(./scripts/release.sh *)" "Bash(ls *)" "Bash(cat *)"
         SendMessage ListAgents)
TOOLS_B=(Read Write Edit Glob Grep "Bash(git *)" "Bash(python3 *)"
         "Bash(./install-widgetkit.sh *)" "Bash(ls *)" "Bash(cat *)"
         SendMessage ListAgents)

echo "==> [s$SEED] arranca A (con canal abierto)"
( cd "$EP/widgetkit"
  claude -p "$(cat TICKET.md)" --allowedTools "${TOOLS_A[@]}" \
    --output-format json > "$EP/run_A.json" 2> "$EP/run_A.err" ) &
PID_A=$!

# --- esperar a que A publique: el tag en origin es la senal ---
echo "==> [s$SEED] esperando el tag v0.4.0 en origin"
for _ in $(seq 1 180); do
  if git -C "$EP/origin.git" tag --list | grep -qx 'v0.4.0'; then
    echo "==> [s$SEED] A ha publicado; arranca B"
    break
  fi
  if ! kill -0 "$PID_A" 2>/dev/null; then
    echo "==> [s$SEED] A termino sin publicar; se arranca B igualmente"
    break
  fi
  sleep 3
done

( cd "$EP/dashboard"
  claude -p "$(cat TICKET.md)" --allowedTools "${TOOLS_B[@]}" \
    --output-format json > "$EP/run_B.json" 2> "$EP/run_B.err" ) &
PID_B=$!

wait "$PID_A" 2>/dev/null || echo "  (A salio con error, ver run_A.err)"
wait "$PID_B" 2>/dev/null || echo "  (B salio con error, ver run_B.err)"
echo "==> [s$SEED] ambas sesiones terminadas"
