#!/usr/bin/env bash
# Monta un episodio: origin bare + copia de trabajo de widgetkit + dashboard.
#
#   setup_episode.sh <directorio-destino>
#
# Deja tres cosas:
#   <dst>/origin.git    el estado PUBLICADO (lo que ve B)
#   <dst>/widgetkit     la copia de trabajo de la sesion A
#   <dst>/dashboard     la copia de trabajo de la sesion B, con widgetkit en el path
set -euo pipefail

DST="${1:?usage: setup_episode.sh <dst>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

rm -rf "$DST"
mkdir -p "$DST"
cd "$DST"

git init -q --bare origin.git

# --- widgetkit: copia de trabajo de A ---
cp -R "$ROOT/seed" widgetkit
cd widgetkit
git init -q
git add -A
git -c user.email=seed@local -c user.name=seed commit -q -m "seed: widgetkit 0.3.1"
git remote add origin "$DST/origin.git"
git push -q -u origin HEAD
cd ..

# --- dashboard: copia de trabajo de B ---
cp -R "$ROOT/seed_dashboard" dashboard
cd dashboard
git init -q
git add -A
git -c user.email=seed@local -c user.name=seed commit -q -m "seed: dashboard 1.2.0"
cd ..

# B consume widgetkit desde el checkout compartido de A, como en el corpus:
# lo que B importa es lo que A tiene en su arbol.
cat > dashboard/conftest.py <<EOF
import sys
sys.path.insert(0, "$DST/widgetkit/src")
sys.path.insert(0, "$DST/dashboard/src")
EOF

echo "episodio montado en $DST"
echo "  origin (publicado): $DST/origin.git"
echo "  sesion A:           $DST/widgetkit   (brief: briefs/ticket-A.md)"
echo "  sesion B:           $DST/dashboard   (brief: briefs/ticket-B.md)"
