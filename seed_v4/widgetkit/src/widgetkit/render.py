"""Rendering helpers."""


def render_label(text: str, *, upper: bool = False) -> str:
    """Render a plain text label."""
    if not text:
        raise ValueError("text must not be empty")
    return text.upper() if upper else text
