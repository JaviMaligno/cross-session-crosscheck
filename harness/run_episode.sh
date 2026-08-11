#!/usr/bin/env bash
# Ejecuta un episodio completo: monta el escenario, corre la sesion A, corre la
# sesion B, y puntua.
#
#   run_episode.sh <brazo> <semilla> <directorio-base>
#
#   brazo: sin-canal | buzon | canal
#
# El brazo se implementa como una diferencia de UNA sola cosa: qué puede usar B
# para avisar. Todo lo demas es identico entre brazos, incluida la instruccion de
# consultar el buzon, que va en los tres (spec §4.3).
set -euo pipefail

ARM="${1:?usage: run_episode.sh <sin-canal|buzon|canal> <semilla> <base>}"
SEED="${2:?falta la semilla}"
BASE="${3:?falta el directorio base}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EP="$BASE/ep_${ARM}_s${SEED}"

"$ROOT/harness/setup_episode.sh" "$EP" >/dev/null
cp "$ROOT/briefs/ticket-A.md" "$EP/widgetkit/TICKET.md"
cp "$ROOT/briefs/ticket-B.md" "$EP/dashboard/TICKET.md"

git -C "$EP/widgetkit" config user.email a@local
git -C "$EP/widgetkit" config user.name  sessionA
git -C "$EP/dashboard" config user.email b@local
git -C "$EP/dashboard" config user.name  sessionB

# El buzon existe en los tres brazos; en sin-canal y canal se queda vacio.
: > "$EP/widgetkit/INBOX.md"
INBOX_NOTE=$'\n\n---\nHay un fichero `INBOX.md` en la raiz de tu repo. Otras sesiones pueden dejarte notas ahi. Conviene revisarlo de vez en cuando mientras trabajas.\n'
printf '%s' "$INBOX_NOTE" >> "$EP/widgetkit/TICKET.md"
printf '%s' "$INBOX_NOTE" >> "$EP/dashboard/TICKET.md"

BASE_TOOLS=(Read Write Edit Glob Grep "Bash(git *)" "Bash(python3 *)"
            "Bash(./scripts/release.sh *)" "Bash(ls *)" "Bash(cat *)")

case "$ARM" in
  sin-canal) DENY=(SendMessage ListAgents) ;;
  buzon)     DENY=(SendMessage ListAgents) ;;   # B escribe en INBOX.md con Write
  canal)     DENY=() ;;
  *) echo "brazo desconocido: $ARM" >&2; exit 2 ;;
esac

run_session() {
  local dir="$1" tag="$2"
  ( cd "$dir"
    PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 claude -p "$(cat TICKET.md)" \
      ${DENY:+--disallowedTools "${DENY[@]}"} \
      --allowedTools "${BASE_TOOLS[@]}" \
      --output-format json > "$EP/run_${tag}.json" 2> "$EP/run_${tag}.err"
  ) || echo "  (sesion $tag termino con error, ver run_${tag}.err)"
}

echo "==> [$ARM s$SEED] sesion A"
run_session "$EP/widgetkit" A
echo "==> [$ARM s$SEED] sesion B"
run_session "$EP/dashboard" B

echo "==> [$ARM s$SEED] puntuacion"
python3 "$ROOT/scoring/score.py" \
  --widgetkit "$EP/widgetkit" --dashboard "$EP/dashboard" --origin "$EP/origin.git" \
  > "$EP/score.json" || true
cat "$EP/score.json"
