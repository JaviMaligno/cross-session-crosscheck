import pytest

from widgetkit import dump_widget


def test_dumps_mapping():
    assert dump_widget({"a": 1}) == '{"a": 1}'


def test_key_order_is_stable():
    # el mismo contenido en otro orden de inserción produce la misma cadena
    uno = dump_widget({"b": 2, "a": 1})
    dos = dump_widget({"a": 1, "b": 2})
    assert uno == dos


def test_rejects_non_mapping():
    with pytest.raises(TypeError):
        dump_widget(["no soy un dict"])
