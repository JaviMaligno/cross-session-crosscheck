"""Payload serialisation for widget state."""

from ._compat import stable_dump


def dump_widget(widget: dict) -> str:
    """Serialise a widget mapping to its wire representation."""
    if not isinstance(widget, dict):
        raise TypeError("widget must be a mapping")
    return stable_dump(widget)
