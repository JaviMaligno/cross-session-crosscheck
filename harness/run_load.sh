#!/usr/bin/env bash
# Brazo de CARGA: la sesion que publica lleva cuatro cosas encima, y la trampa
# es la del registro (setup v2), identica a la del brazo sin carga.
#
#   run_load.sh <semilla> <directorio-base>
#
# Replica exactamente la configuracion de los tres episodios originales
# (familia `load2`, 2026-08-12), que se corrieron a mano y no estaban en el
# repo. Las tres piezas que definen el brazo:
#
#  1. CARGA. `ticket-A-load.md` (cuatro tickets, la release al final) en vez de
#     un solo feature, y un `INBOX.md` con tres mensajes de otras sesiones, uno
#     preguntando por 0.4.0 porque hay un consumidor esperando.
#  2. SIN CANAL. Ni A ni B pueden mandar mensajes: este brazo mide si la sesion
#     verifica su propio estado publicado, no si el par la avisa. El aviso del
#     par es el brazo concurrente (`run_concurrent.sh`).
#  3. TRAMPA INTACTA. El registro trae ya un artefacto 0.4.0 obsoleto y
#     `wk-publish` es idempotente. `verify_load_trap.sh` lo comprueba antes de
#     gastar sesiones; no se confia en un `diff` recordado.
#
# El consumidor corre DESPUES, en secuencia, como en los originales: da la
# deteccion aguas abajo sin poder comunicarla.
set -euo pipefail

SEED="${1:?usage: run_load.sh <semilla> <base>}"
BASE="${2:?falta el directorio base}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EP="$BASE/load3_s${SEED}"

"$ROOT/harness/setup_episode_v2.sh" "$EP" >/dev/null
cp "$ROOT/briefs/ticket-A-load.md"    "$EP/widgetkit/TICKET.md"
cp "$ROOT/briefs/inbox-load.md"       "$EP/widgetkit/INBOX.md"
cp "$ROOT/briefs/ticket-B-registry.md" "$EP/dashboard/TICKET.md"
cp "$ROOT/tools/install-widgetkit.sh"  "$EP/dashboard/install-widgetkit.sh"
chmod +x "$EP/dashboard/install-widgetkit.sh"
cat > "$EP/dashboard/conftest.py" <<'PYEOF'
import sys, pathlib
here = pathlib.Path(__file__).parent
sys.path.insert(0, str(here / ".deps" / "src"))
sys.path.insert(0, str(here / "src"))
PYEOF

git -C "$EP/widgetkit" config user.email a@local
git -C "$EP/widgetkit" config user.name  sessionA
git -C "$EP/dashboard" config user.email b@local
git -C "$EP/dashboard" config user.name  sessionB

export WK_REGISTRY="$EP/registry"
export PATH="$EP/bin:$PATH"
export PYTEST_DISABLE_PLUGIN_AUTOLOAD=1

DENY=(SendMessage ListAgents)
TOOLS_A=(Read Write Edit Glob Grep "Bash(git *)" "Bash(python3 *)"
         "Bash(./scripts/release.sh *)" "Bash(ls *)" "Bash(cat *)")
TOOLS_B=(Read Write Edit Glob Grep "Bash(git *)" "Bash(python3 *)"
         "Bash(./install-widgetkit.sh *)" "Bash(ls *)" "Bash(cat *)")

echo "==> [carga s$SEED] sesion A (cargada, publica)"
( cd "$EP/widgetkit"
  claude -p "$(cat TICKET.md)" --disallowedTools "${DENY[@]}" \
    --allowedTools "${TOOLS_A[@]}" \
    --output-format json > "$EP/run_A.json" 2> "$EP/run_A.err" ) \
  || echo "  (A salio con error, ver run_A.err)"

echo "==> [carga s$SEED] sesion B (consumidor)"
( cd "$EP/dashboard"
  claude -p "$(cat TICKET.md)" --disallowedTools "${DENY[@]}" \
    --allowedTools "${TOOLS_B[@]}" \
    --output-format json > "$EP/run_B.json" 2> "$EP/run_B.err" ) \
  || echo "  (B salio con error, ver run_B.err)"

echo "==> [carga s$SEED] puntuacion"
python3 "$ROOT/scoring/score_load.py" "$EP"
