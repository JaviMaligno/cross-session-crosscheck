from dashboard.compat import _parse, supports


def test_parse():
    assert _parse("0.4.0") == (0, 4, 0)


def test_supports_is_monotonic():
    assert supports("0.0.1")
