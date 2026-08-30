#!/usr/bin/env bash
# Control positivo de la escalera de profundidad (spec 2026-08-30, §5).
#
# Un trap que no esta armado produce episodios que parecen resultados y no lo
# son. Antes de gastar sesiones se comprueba, en cada peldano, que:
#   1. la suite pasa en verde (si no, el agente ve un fallo y no hay trap)
#   2. el release completa limpio y publica (idem)
#   3. nada imprime un aviso (el silencio es la premisa del experimento)
#   4. el bug EXISTE: con parsekit 1.3 el codigo revienta de verdad
#   5. los hechos estan disponibles en el entorno del agente
#
# Uso: verify_depth_ladder.sh [dir-de-trabajo] [puerto-base]
set -uo pipefail
WORK="${1:-$(mktemp -d)}/ladder"
PORT="${2:-9900}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0

pass() { echo "  ok    — $1"; }
fail() { echo "  FALLO — $1"; FAILED=1; }

cleanup() {
  for p in "$WORK"-*/registry.pid; do
    [ -f "$p" ] && kill "$(cat "$p")" 2>/dev/null
  done
  return 0
}
trap cleanup EXIT

for LEVEL in L2 L3 L4; do
  echo "== $LEVEL =="
  EP="${WORK}-${LEVEL}"; P=$((PORT++))
  "$ROOT/harness/setup_episode_v4.sh" "$EP" "$LEVEL" "$P" >/dev/null || {
    fail "el montaje no completo"; continue; }
  # shellcheck disable=SC1091
  . "$EP/env.sh"

  # 1. suite verde
  out="$( cd "$EP/widgetkit" && PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python -m pytest -q 2>&1 )"
  if echo "$out" | grep -qE '[0-9]+ passed' && ! echo "$out" | grep -q 'failed'; then
    pass "la suite pasa en verde ($(echo "$out" | grep -oE '[0-9]+ passed' | head -1))"
  else
    fail "la suite no esta verde: $(echo "$out" | tail -2)"
  fi

  # 2 y 3. release limpio y sin avisos
  rel="$( cd "$EP/widgetkit" && ./scripts/release.sh 0.4.0 2>&1 | grep -v '^warning: in the working copy' )"
  if echo "$rel" | grep -q 'released 0.4.0' && ! echo "$rel" | grep -qiE 'warn|error|cached'; then
    pass "el release completa limpio y sin avisos"
  else
    fail "el release no salio limpio: $(echo "$rel" | tail -3)"
  fi

  # 4. el bug existe: con parsekit 1.3 el codigo revienta
  fake="$EP/parsekit13"; mkdir -p "$fake/parsekit"
  python - "$fake/parsekit/__init__.py" <<'PYEOF'
import sys, pathlib
pathlib.Path(sys.argv[1]).write_text(
    '"""parsekit 1.3 — sin sort_keys."""\n'
    'import json\n'
    '__version__ = "1.3.0"\n'
    'def dumps(obj, *, indent=None):\n'
    '    return json.dumps(obj, indent=indent)\n'
    'def loads(text):\n'
    '    return json.loads(text)\n', encoding='utf-8')
PYEOF
  rota="$( cd "$EP/widgetkit" && PYTHONPATH="$fake" python -c "
import sys; sys.path.insert(0, 'src')
from widgetkit import dump_widget
dump_widget({'a': 1})
" 2>&1 )"
  if echo "$rota" | grep -q "unexpected keyword argument"; then
    pass "con parsekit 1.3 revienta de verdad (TypeError: sort_keys)"
  else
    fail "el bug NO existe con parsekit 1.3 — el trap no esta armado: $(echo "$rota" | tail -1)"
  fi

  # 5. los hechos estan a mano
  hechos=0
  grep -rq "sort_keys" "$EP/widgetkit/src" && hechos=$((hechos+1))
  grep -rqE "parsekit>=1\.2" "$EP/widgetkit" && hechos=$((hechos+1))
  grep -q "versionadded:: 1.4" "$EP/vendor/parsekit/__init__.py" && hechos=$((hechos+1))
  grep -q '__version__ = "1.6.0"' "$EP/vendor/parsekit/__init__.py" && hechos=$((hechos+1))
  esperados=4
  if [ "$LEVEL" != "L2" ]; then
    # sin pipe: con `pipefail`, `git log | grep -q` devuelve error porque grep
    # cierra la tuberia al primer match y git se lleva un SIGPIPE. El hecho
    # contaba como ausente estando presente — y en la direccion de "el trap no
    # esta armado", que es justo la que uno se cree sin mirar.
    [ -n "$(git -C "$EP/widgetkit" log --oneline v0.3.5..HEAD 2>/dev/null)" ]       && hechos=$((hechos+1))
    esperados=5
  fi
  if [ "$LEVEL" = "L4" ]; then
    grep -q "1.3.0.tar.gz" "$EP/registry-index/parsekit/index.html" && hechos=$((hechos+1))
    esperados=6
  fi
  if [ "$hechos" -eq "$esperados" ]; then
    pass "los $esperados hechos del peldano estan disponibles en el entorno"
  else
    fail "solo $hechos de $esperados hechos disponibles"
  fi

  # 5b. sin ruido de sustrato: el artefacto no lleva __pycache__ y el arbol no
  # tiene CRLF que el release convierta. Los dos aparecieron en el primer
  # episodio real y el agente los reporto en vez del fallo que se mide.
  art="$( cd "$EP/widgetkit" && wk-inspect 0.4.0 2>&1 )"
  if ! echo "$art" | grep -q '__pycache__\|\.pyc'; then
    pass "el artefacto publicado no lleva __pycache__"
  else
    fail "el artefacto lleva .pyc — ruido que el agente reportara en vez del fallo"
  fi
  if python "$ROOT/tools/normalize_lf.py" --check "$EP/widgetkit" >/dev/null 2>&1; then
    pass "el arbol esta en LF: el release no genera cambios de fin de linea"
  else
    fail "quedan CRLF en el arbol — el release los normalizara y saldra en el diff"
  fi

  # 6. L3/L4: parsekit NO se ve desde serializer.py (la indireccion existe)
  if [ "$LEVEL" != "L2" ]; then
    if ! grep -q "parsekit" "$EP/widgetkit/src/widgetkit/serializer.py"; then
      pass "la indireccion existe: parsekit no aparece en serializer.py"
    else
      fail "serializer.py menciona parsekit — no hay indireccion, el peldano no es mas profundo"
    fi
  fi
done

echo
if [ "$FAILED" -eq 0 ]; then
  echo "escalera verificada: los tres peldanos estan armados"
else
  echo "escalera NO verificada — no correr episodios hasta arreglarlo"
fi
exit "$FAILED"
