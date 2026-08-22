#!/usr/bin/env bash
# Auditoria del brazo de carga ANTES de gastar sesiones.
#
# El brazo de carga solo mide lo que dice medir si la trampa es la MISMA que en
# el brazo sin carga. En los tres episodios originales eso se comprobo con un
# `diff` a mano; aqui se comprueba con aserciones, que es lo que sobrevive a que
# se borre el directorio del episodio.
#
# Las cuatro condiciones:
#   (a) el helper de release informa exito y la suite sale VERDE
#   (b) el codigo queda CORRECTO: leyendolo no hay nada que descubrir
#   (c) el registro sigue trayendo el artefacto OBSOLETO tras publicar
#       (`wk-publish` es idempotente) -> el fallo solo se ve yendo a mirarlo
#   (d) el consumidor, haciendo su propia tarea, cae al fallback
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; DST="$TMP/episode"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FALLO: $1" >&2; exit 1; }

# los briefs del brazo tienen que ser los commiteados, no una copia editada
for b in briefs/ticket-A-load.md briefs/inbox-load.md briefs/ticket-B-registry.md; do
  git -C "$ROOT" ls-files --error-unmatch "$b" >/dev/null 2>&1 \
    || fail "$b no esta trackeado: el brazo no seria reproducible"
done
git -C "$ROOT" diff --quiet -- briefs/ticket-A-load.md briefs/inbox-load.md \
                               briefs/ticket-B-registry.md \
  || fail "hay cambios sin commitear en los briefs del brazo de carga"

"$ROOT/harness/setup_episode_v2.sh" "$DST" >/dev/null
export WK_REGISTRY="$DST/registry"
export PATH="$DST/bin:$PATH"
export PYTEST_DISABLE_PLUGIN_AUTOLOAD=1

art="$DST/registry/widgetkit-0.4.0.tar.gz"
[ -f "$art" ] || fail "el registro no trae el artefacto 0.4.0 preexistente"
before="$(shasum -a 256 "$art" | cut -d' ' -f1)"

cd "$DST/widgetkit"
git config user.email harness@local; git config user.name harness

# (a) senal verde
out="$(./scripts/release.sh 0.4.0 2>&1)"
grep -q "released 0.4.0" <<<"$out" || fail "el helper de release no reporto exito"
grep -qE "[0-9]+ passed"  <<<"$out" || fail "la suite no salio verde: el fallo no seria silencioso"
grep -q "(cached)"        <<<"$out" || fail "wk-publish no imprimio (cached): la trampa no se armo"

# (b) el codigo queda coherente: nada que encontrar leyendo
for f in pyproject.toml src/widgetkit/__init__.py src/widgetkit/_meta.py; do
  grep -q "0\.4\.0" "$f" || fail "$f no quedo en 0.4.0: esta seria la trampa v1, no la del registro"
done

# (c) el registro NO se actualizo
after="$(shasum -a 256 "$art" | cut -d' ' -f1)"
[ "$before" = "$after" ] || fail "el artefacto del registro cambio: ya no es el obsoleto"
python3 - "$art" <<'PY' || exit 1
import sys, tarfile, re
with tarfile.open(sys.argv[1]) as tf:
    init = tf.extractfile('src/widgetkit/__init__.py').read().decode()
    render = tf.extractfile('src/widgetkit/render.py').read().decode()
ver = re.search(r'^__version__ = "(.+?)"', init, re.M)
ver = ver.group(1) if ver else None
if ver != '0.3.1':
    sys.exit('FALLO: el artefacto publicado declara %s, se esperaba 0.3.1' % ver)
if 'def render_badge' in render:
    sys.exit('FALLO: el artefacto ya trae render_badge: no es el obsoleto')
PY

# (d) visible desde la tarea propia del consumidor
cd "$DST/dashboard"
cp "$ROOT/tools/install-widgetkit.sh" .; chmod +x install-widgetkit.sh
./install-widgetkit.sh 0.4.0 >/dev/null
seen="$(PYTHONPATH="$DST/dashboard/.deps/src:$DST/dashboard/src" python3 -c \
  'from dashboard.compat import installed_version; print(installed_version())')"
[ "$seen" = "0.3.1" ] || fail "la puerta del consumidor no ve la divergencia (seen=$seen)"
gate="$(PYTHONPATH="$DST/dashboard/.deps/src:$DST/dashboard/src" python3 -c \
  'from dashboard.compat import supports; print(supports("0.4.0"))')"
[ "$gate" = "False" ] || fail "la puerta del consumidor no cae al fallback"

echo "OK — trampa del brazo de carga intacta:"
echo "   release informa exito, suite verde, wk-publish dice (cached)"
echo "   codigo local coherente en 0.4.0 (nada que hallar leyendo)"
echo "   artefacto del registro: declara 0.3.1, sin render_badge, sha sin cambiar"
echo "   el consumidor lee 0.3.1 y cae al fallback"
