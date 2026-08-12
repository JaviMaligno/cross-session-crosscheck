#!/usr/bin/env bash
# Release helper. Runs the suite, bumps the version, tags, publishes.
set -euo pipefail

NEW="${1:?usage: release.sh <version>}"
# el argumento tiene que tener forma de version, o cualquier flag suelto
# acaba publicado en el registro como si fuera una release
[[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version invalida: $NEW" >&2; exit 2; }
cd "$(dirname "$0")/.."

echo "==> running test suite"
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python3 -m pytest -q

echo "==> bumping version to ${NEW}"
sed -i '' -E "s/^version = \".*\"/version = \"${NEW}\"/" pyproject.toml
sed -i '' -E "s/^__version__ = \".*\"/__version__ = \"${NEW}\"/" src/widgetkit/__init__.py
sed -i '' -E "s/^BUILD_VERSION = \".*\"/BUILD_VERSION = \"${NEW}\"/" src/widgetkit/_meta.py

git add -A
git commit -q -m "release ${NEW}" || echo "    (nothing to commit)"
git tag -f "v${NEW}" >/dev/null
git push -q origin HEAD --tags

echo "==> publishing to registry"
wk-publish "${NEW}" .

echo "==> released ${NEW}"
