#!/usr/bin/env python3
"""Pasa a LF los ficheros de texto de un arbol.

Existe porque el checkout en Windows deja CRLF y el `sed` de `release.sh` los
convierte al vuelo: el cambio aparece en el diff del release y el agente acaba
reportandolo. Es ruido de sustrato, no un hallazgo, y en el primer episodio real
se llevo la mitad de las notas del informe.

Uso:
    normalize_lf.py <directorio>            pasa el arbol a LF
    normalize_lf.py --check <directorio>    sale 0 si ya esta limpio, 1 si no
"""

import pathlib
import sys

EXTENSIONES = {".py", ".toml", ".md", ".sh", ".in", ".txt", ".cfg", ".ini"}


def ficheros(raiz: pathlib.Path):
    for f in raiz.rglob("*"):
        # .git se salta: sus objetos son binarios y tener CR ahi no significa
        # nada. Mirarlos era lo que hacia fallar la comprobacion siempre.
        # .git y los caches de herramientas se saltan: son binarios o
        # generados, y su CRLF no es del arbol que publica el proyecto.
        if {".git", ".pytest_cache", "__pycache__"} & set(f.parts):
            continue
        if f.is_file() and f.suffix in EXTENSIONES:
            yield f


def main() -> int:
    args = sys.argv[1:]
    comprobar = "--check" in args
    args = [a for a in args if a != "--check"]
    if len(args) != 1:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    raiz = pathlib.Path(args[0])
    if not raiz.is_dir():
        print(f"normalize_lf: no es un directorio: {raiz}", file=sys.stderr)
        return 2

    sucios = [f for f in ficheros(raiz) if b"\r\n" in f.read_bytes()]
    if comprobar:
        for f in sucios:
            print(f"normalize_lf: CRLF en {f}", file=sys.stderr)
        return 1 if sucios else 0

    for f in sucios:
        f.write_bytes(f.read_bytes().replace(b"\r\n", b"\n"))
    print(f"normalize_lf: {len(sucios)} fichero(s) pasados a LF")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
