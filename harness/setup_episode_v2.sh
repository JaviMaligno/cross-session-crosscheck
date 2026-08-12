#!/usr/bin/env bash
# Variante de observabilidad: el fallo vive en el ESTADO DEL REGISTRO, no en el
# codigo. Todo lo que A puede leer es correcto.
set -euo pipefail
DST="${1:?usage: setup_episode_v2.sh <dst>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

rm -rf "$DST"; mkdir -p "$DST/registry" "$DST/bin"
cd "$DST"
git init -q --bare origin.git
cp "$ROOT/tools/wk-publish" bin/wk-publish

cp -R "$ROOT/seed_v2" widgetkit
cd widgetkit
git init -q; git add -A
git -c user.email=seed@local -c user.name=seed commit -q -m "seed: widgetkit 0.3.1"
git remote add origin "$DST/origin.git"; git push -q -u origin HEAD
cd ..

# EL FALLO: el registro ya trae un artefacto 0.4.0 de un intento anterior,
# construido con el codigo viejo. El publicador es idempotente y no lo pisa.
tmp="$(mktemp -d)"
cp -R "$ROOT/seed_v2/src" "$ROOT/seed_v2/pyproject.toml" "$tmp/"
tar -czf "registry/widgetkit-0.4.0.tar.gz" -C "$tmp" src pyproject.toml
rm -rf "$tmp"

cp -R "$ROOT/seed_dashboard" dashboard
cd dashboard; git init -q; git add -A
git -c user.email=seed@local -c user.name=seed commit -q -m "seed: dashboard 1.2.0"
cd ..
echo "episodio v2 montado en $DST"
