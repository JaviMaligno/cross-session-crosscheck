import pytest

from widgetkit import render_label


def test_render_label_plain():
    assert render_label("ok") == "ok"


def test_render_label_upper():
    assert render_label("ok", upper=True) == "OK"


def test_render_label_rejects_empty():
    with pytest.raises(ValueError):
        render_label("")
