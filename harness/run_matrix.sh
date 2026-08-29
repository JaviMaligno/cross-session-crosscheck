#!/usr/bin/env bash
# Matriz completa: capacidad x restriccion x carga.
#
#   run_matrix.sh <base> [puerto-inicial]
#
# Corre SOLO lo que falta: un episodio con run_A.json valido no se repite, y uno
# que murio por el limite de gasto si. Asi la tanda se puede relanzar tantas
# veces como haga falta sin gastar de mas.
#
# Antes de nada comprueba que hay presupuesto, porque una tanda entera contra el
# limite produce nueve ficheros que parecen resultados y no lo son: en la tanda
# del 29-08, seis episodios volvieron con "stop_sequence" y coste 0,00 y habrian
# entrado en la tabla como ceros limpios si nadie mira el motivo.
set -uo pipefail

BASE="${1:?usage: run_matrix.sh <base> [puerto-inicial]}"
PORT="${2:-9100}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$BASE"

STRONG=""                            # vacio = por defecto de la CLI (Opus 5)
WEAK="claude-haiku-4-5-20251001"

# --- preflight: ¿hay presupuesto? ---
probe="$(claude -p 'responde solo: ok' --output-format json 2>/dev/null \
         | python -c "import json,sys; print(json.load(sys.stdin).get('stop_reason',''))" 2>/dev/null)"
if [ "$probe" = "stop_sequence" ]; then
  echo "ABORTA: la cuenta esta en el limite de gasto. No se corre nada." >&2
  exit 3
fi
echo "preflight ok (stop_reason=$probe)"

vivo() {  # vivo <ruta-episodio> -> 0 si ya tiene un resultado valido
  local j="$1/run_A.json"
  [ -f "$j" ] || return 1
  python - "$j" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding='utf-8', errors='replace'))
except Exception:
    sys.exit(1)
sys.exit(1 if d.get('stop_reason') == 'stop_sequence' else 0)
PY
}

corre() {  # corre <regimen> <semilla> <load|""> <modelo> <etiqueta>
  local reg="$1" seed="$2" load="$3" model="$4" tag="$5"
  local sfx=""; [ "$load" = "load" ] && sfx="_load"
  local mtag=""; case "$model" in *haiku*) mtag="_haiku";; esac
  local ep="$BASE/ep_${reg}${sfx}${mtag}_s${seed}"
  if vivo "$ep"; then
    echo "  · ${tag} ya hecho, se salta"
    return 0
  fi
  echo "############ ${tag} (puerto $PORT) ############"
  bash "$ROOT/harness/run_regime.sh" "$reg" "$seed" "$BASE" "$PORT" "$load" "$model" 2>&1 | tail -12
  PORT=$((PORT + 1))
}

for MODEL_KIND in strong weak; do
  if [ "$MODEL_KIND" = strong ]; then M="$STRONG"; MN="opus"; else M="$WEAK"; MN="haiku"; fi
  for LOAD in "" load; do
    LN="sin-carga"; [ "$LOAD" = "load" ] && LN="cargado"
    for REG in R0 R1 R2; do
      for SEED in 1 2 3; do
        corre "$REG" "$SEED" "$LOAD" "$M" "$MN/$LN/$REG s$SEED"
      done
    done
  done
done

echo "############ matriz completa ############"
