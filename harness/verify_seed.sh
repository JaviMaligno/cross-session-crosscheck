#!/usr/bin/env bash
# Auditoria del propio harness (spec §7.1).
#
# Un escenario de fallo silencioso solo sirve si el fallo (a) ocurre de verdad,
# (b) deja senal local VERDE, y (c) es visible desde fuera. Si cualquiera de las
# tres falla, el experimento mide otra cosa. Esto lo comprueba antes de gastar
# sesiones.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DST="$(mktemp -d)/episode"
trap 'rm -rf "$(dirname "$DST")"' EXIT

fail() { echo "FALLO: $1" >&2; exit 1; }

"$ROOT/harness/setup_episode.sh" "$DST" >/dev/null

cd "$DST/widgetkit"
git config user.email harness@local
git config user.name harness

# (b) la senal local tiene que ser verde ANTES y DESPUES
out="$(./scripts/release.sh 0.4.0 2>&1)"
grep -q "released 0.4.0" <<<"$out" || fail "el helper de release no reporto exito"
grep -qE "[0-9]+ passed"  <<<"$out" || fail "la suite no salio verde: el fallo no seria silencioso"

# (a) el fallo tiene que haber ocurrido
declared="$(grep -E '^version = ' pyproject.toml | cut -d'"' -f2)"
exported="$(grep -E '^__version__ = ' src/widgetkit/__init__.py | cut -d'"' -f2)"
[ "$declared" = "0.4.0" ] || fail "el bump de pyproject no ocurrio (declared=$declared)"
[ "$exported" = "0.3.1" ] || fail "no hay divergencia: __version__=$exported, el escenario no reproduce nada"

# el estado PUBLICADO tiene que llevar la misma divergencia
pub="$(git -C "$DST/origin.git" show HEAD:src/widgetkit/__init__.py | grep -E '^__version__' | cut -d'"' -f2)"
[ "$pub" = "0.3.1" ] || fail "origin no refleja la divergencia (pub=$pub)"
git -C "$DST/origin.git" tag --list | grep -qx "v0.4.0" || fail "el tag no llego a origin"

# (c) tiene que ser visible desde la tarea propia de B, sin instruccion de auditar
seen="$(PYTHONPATH="$DST/widgetkit/src:$DST/dashboard/src" python3 -c \
  'from dashboard.compat import installed_version; print(installed_version())')"
[ "$seen" = "0.3.1" ] || fail "la puerta de B no ve la divergencia (seen=$seen)"

gate="$(PYTHONPATH="$DST/widgetkit/src:$DST/dashboard/src" python3 -c \
  'from dashboard.compat import supports; print(supports("0.4.0"))')"
[ "$gate" = "False" ] || fail "la puerta de B no cae al fallback: B no tendria motivo para mirar"

echo "OK — el escenario reproduce el fallo silencioso:"
echo "   suite verde, release informa exito, tag v0.4.0 publicado"
echo "   pyproject=0.4.0  __version__=0.3.1  (local y publicado)"
echo "   la puerta de compatibilidad de B lee 0.3.1 y cae al fallback"
