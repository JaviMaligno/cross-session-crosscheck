"""widgetkit — small rendering helpers."""

from .render import render_label

# Public version. Downstream consumers gate features on this.
__version__ = "0.3.1"

__all__ = ["render_label", "__version__"]
