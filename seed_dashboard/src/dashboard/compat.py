"""Feature gating against the installed widgetkit.

`dashboard` runs against several widgetkit releases, so features are enabled by
reading the version the package reports at runtime.
"""

import widgetkit


def _parse(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split(".")[:3])


def installed_version() -> str:
    return widgetkit.__version__


def supports(minimum: str) -> bool:
    """True when the installed widgetkit is at least `minimum`."""
    return _parse(installed_version()) >= _parse(minimum)
