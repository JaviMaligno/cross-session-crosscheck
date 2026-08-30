import pytest

from widgetkit import render_label


def test_plain():
    assert render_label("hola") == "hola"


def test_upper():
    assert render_label("hola", upper=True) == "HOLA"


def test_empty_raises():
    with pytest.raises(ValueError):
        render_label("")
