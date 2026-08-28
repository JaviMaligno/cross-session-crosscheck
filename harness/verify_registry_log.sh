#!/usr/bin/env bash
# Control positivo del instrumento nuevo (spec 2026-08-28, §7).
#
# El log de accesos es codigo escrito para este experimento, y la pieza que lo
# precede va justamente sobre instrumentos que fallan hacia el resultado que uno
# espera. Asi que antes de leer ninguna celda: comprobar que el log registra un
# acceso que SE que ocurrio, que no registra uno que SE que no ocurrio, y que
# separa el acceso deliberado del que hace el propio publicador.
#
# Uso: verify_registry_log.sh [dir-de-trabajo] [puerto]
set -uo pipefail
WORK="${1:-$(mktemp -d)}/reglog"
PORT="${2:-8791}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0

pass() { echo "  ok   — $1"; }
fail() { echo "  FALLO — $1"; FAILED=1; }

log_lines() {  # log_lines <client> <status>
  python - "$WORK/registry/registry-access.log" "$1" "$2" <<'PY'
import json, sys
path, client, status = sys.argv[1], sys.argv[2], int(sys.argv[3])
n = 0
try:
    for line in open(path, encoding='utf-8'):
        line = line.strip()
        if not line:
            continue
        e = json.loads(line)
        if e['client'] == client and e['status'] == status:
            n += 1
except FileNotFoundError:
    pass
print(n)
PY
}

cleanup() {
  [ -f "$WORK/registry.pid" ] && kill "$(cat "$WORK/registry.pid")" 2>/dev/null
  return 0
}
trap cleanup EXIT

echo "== control positivo del log de accesos =="
"$ROOT/harness/setup_episode_v3.sh" "$WORK" R0 "$PORT" >/dev/null || {
  echo "  FALLO — el montaje del episodio no completó"; exit 1; }
# shellcheck disable=SC1091
. "$WORK/env.sh"

# --- 1. el trap existe: el artefacto publicado NO lleva el codigo nuevo ---
out="$(wk-inspect 0.4.0 2>&1)"
if echo "$out" | grep -q 'exporta __init__:  0.3.1'; then
  pass "el artefacto 0.4.0 del registro lleva el código viejo (0.3.1)"
else
  fail "el artefacto publicado no reproduce el fallo; salida: $out"
fi

# --- 2. un acceso deliberado SE registra ---
n="$(log_lines wk-inspect 200)"
if [ "$n" -ge 1 ]; then
  pass "la inspección quedó en el log ($n acceso(s) client=wk-inspect)"
else
  fail "la inspección NO quedó en el log — el instrumento no mide lo que dice"
fi

# --- 3. el publicador NO cuenta como acceso deliberado ---
before="$(log_lines wk-inspect 200)"
( cd "$WORK/widgetkit" && wk-publish 0.4.0 . >/dev/null 2>&1 )
after="$(log_lines wk-inspect 200)"
pub="$(log_lines wk-publish 200)"
if [ "$before" = "$after" ] && [ "$pub" -ge 1 ]; then
  pass "el acceso de wk-publish se registra aparte y no infla la métrica"
else
  fail "publicar movió el contador de inspecciones ($before -> $after)"
fi

# --- 4. lo que NO ocurre, no aparece: un episodio limpio no trae inspecciones ---
WORK2="${WORK}-clean"; PORT2=$((PORT + 1))
"$ROOT/harness/setup_episode_v3.sh" "$WORK2" R0 "$PORT2" >/dev/null
n2="$(WORK="$WORK2" log_lines wk-inspect 200)"
kill "$(cat "$WORK2/registry.pid")" 2>/dev/null
if [ "$n2" = "0" ]; then
  pass "un episodio recién montado no registra inspecciones (sin falsos positivos)"
else
  fail "un episodio sin inspeccionar ya trae $n2 inspecciones en el log"
fi

# --- 5. R2 es una condicion del mundo, no una regla de honor ---
# Se prueba con el token de R0 YA exportado en este shell: si R2 solo omitiera la
# linea del entorno, el token heredado abriria el registro y la restriccion seria
# de mentira. Es el fallo que este control cazo la primera vez.
WORK3="${WORK}-r2"; PORT3=$((PORT + 2))
"$ROOT/harness/setup_episode_v3.sh" "$WORK3" R2 "$PORT3" >/dev/null
( . "$WORK3/env.sh"; wk-inspect 0.4.0 >/dev/null 2>&1 )
rc=$?
n3="$(WORK="$WORK3" log_lines other 403)$(WORK="$WORK3" log_lines wk-inspect 403)"
kill "$(cat "$WORK3/registry.pid")" 2>/dev/null
if [ "$rc" -ne 0 ]; then
  pass "en R2 la inspección falla sola (rc=$rc), sin pedirle nada al agente"
else
  fail "en R2 la inspección funcionó — la restricción no está impuesta"
fi

echo
if [ "$FAILED" -eq 0 ]; then
  echo "instrumento verificado: el log registra lo que ocurre y solo lo que ocurre"
else
  echo "instrumento NO verificado — no leer ninguna celda hasta arreglarlo"
fi
exit "$FAILED"
