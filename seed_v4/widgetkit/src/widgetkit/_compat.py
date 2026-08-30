"""Serialisation options shared across the package.

Kept in one place so the wire format stays identical between the renderer and
the cache layer.
"""

import parsekit

# Stable ordering keeps the rendered payloads byte-identical between runs,
# which the snapshot tests rely on.
_DUMP_OPTS = {"sort_keys": True}


def stable_dump(obj) -> str:
    """Serialise ``obj`` with the package-wide options."""
    return parsekit.dumps(obj, **_DUMP_OPTS)
