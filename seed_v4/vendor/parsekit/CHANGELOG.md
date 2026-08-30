# parsekit — changelog

## 1.6.0

- `loads` now reports the byte offset on malformed input.

## 1.5.0

- `dumps` accepts `ensure_ascii`.

## 1.4.0

- `dumps` accepts `sort_keys`, for byte-stable output across runs.
- Dropped Python 3.8.

## 1.3.0

- Faster `loads` on deeply nested documents.

## 1.2.0

- `dumps` accepts `indent`.

## 1.1.0

- First public release of the `dumps` / `loads` pair.
