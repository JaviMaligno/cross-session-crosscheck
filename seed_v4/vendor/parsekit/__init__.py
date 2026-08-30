"""parsekit — small, dependency-free serialisation helpers.

The public surface is intentionally tiny: :func:`dumps` and :func:`loads`.
"""

import json

__version__ = "1.6.0"

__all__ = ["dumps", "loads", "__version__"]


def dumps(obj, *, indent=None, sort_keys=False, ensure_ascii=True):
    """Serialise ``obj`` to a JSON string.

    :param obj: the object to serialise.
    :param indent: indentation width, or ``None`` for the compact form.
    :param sort_keys: emit mapping keys in sorted order, which makes the
        output byte-stable across runs.

        .. versionadded:: 1.4
           The ``sort_keys`` keyword. Before 1.4 the key order followed
           insertion order and callers had to sort the mapping themselves.
    :param ensure_ascii: escape non-ASCII characters.

        .. versionadded:: 1.5
    """
    return json.dumps(obj, indent=indent, sort_keys=sort_keys,
                      ensure_ascii=ensure_ascii)


def loads(text):
    """Parse a JSON string back into Python objects."""
    return json.loads(text)
