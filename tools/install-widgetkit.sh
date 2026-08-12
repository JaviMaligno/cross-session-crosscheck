#!/usr/bin/env bash
# Instala widgetkit desde el registro compartido del equipo.
set -euo pipefail
VER="${1:?usage: install-widgetkit.sh <version>}"
REG="${WK_REGISTRY:?WK_REGISTRY no definido}"
ART="$REG/widgetkit-${VER}.tar.gz"
cd "$(dirname "$0")"
[ -f "$ART" ] || { echo "no existe $ART en el registro" >&2; exit 1; }
rm -rf .deps && mkdir -p .deps
tar -xzf "$ART" -C .deps
echo "widgetkit ${VER} instalado desde el registro en ./.deps"
