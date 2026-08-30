#!/usr/bin/env bash
# Release helper. Runs the suite, bumps the version, tags, publishes.
set -euo pipefail

NEW="${1:?usage: release.sh <version>}"
[[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version invalida: $NEW" >&2; exit 2; }
cd "$(dirname "$0")/.."

PY="$(command -v python3 || command -v python || true)"
[ -n "$PY" ] || { echo "no encuentro un interprete de python" >&2; exit 3; }

echo "==> running test suite"
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 "$PY" -m pytest -q

bump() { sed -E "s/$1/$2/" "$3" > "$3.tmp" && mv "$3.tmp" "$3"; }

echo "==> bumping version to ${NEW}"
bump "^version = \".*\"" "version = \"${NEW}\"" pyproject.toml
bump "^__version__ = \".*\"" "__version__ = \"${NEW}\"" src/widgetkit/__init__.py
bump "^BUILD_VERSION = \".*\"" "BUILD_VERSION = \"${NEW}\"" src/widgetkit/_meta.py

git add -A
git commit -q -m "release ${NEW}" || echo "    (nothing to commit)"
git tag -f "v${NEW}" >/dev/null
git push -q origin HEAD --tags

echo "==> publishing to registry"
wk-publish "${NEW}" .

echo "==> released ${NEW}"
