#!/usr/bin/env python3
"""Runner mecanico: las manos del regimen de ejecucion mediada (R1).

El agente no ejecuta nada. Escribe en REQUESTS.txt los comandos que quiere
correr, uno por linea, y este proceso los ejecuta y deja la salida en
OUTPUTS.txt.

Las reglas son las que hacen honesta la medicion:

- **Ejecuta lo que se le pide y nada mas.** No corrige, no completa, no
  reordena, no sugiere, no avisa de un comando mal escrito. Un comando roto
  devuelve su error tal cual.
- **No emite juicio.** Fuera del bloque de salida y su codigo de retorno no
  escribe texto propio.
- **Registra todo.** requests.log (JSONL) es el dato primario de R1: no solo si
  pidio la inspeccion, sino en que turno, que pidio antes y que pidio despues.

Lo que se pierde frente a una persona haciendo de manos es la latencia humana,
y se declara como limite en el articulo.

Uso:
    runner.py --dir <cwd> --env <env.sh> [--poll 1.0] [--timeout 60]
"""

import argparse
import json
import os
import shutil
import subprocess
import time
from pathlib import Path

BASH = ''

BANNER = (
    "# Salidas de los comandos pedidos en REQUESTS.txt.\n"
    "# Una entrada por comando, en el orden en que se pidieron.\n"
)


def win_path(p: str) -> str:
    """/c/Users/x -> C:/Users/x

    Los scripts del harness hablan en rutas de Git Bash y Python en Windows no
    las entiende: usadas como cwd dan NotADirectoryError. Lo caza el ensayo en
    seco; sin esta traduccion el runner no encuentra ni su propio directorio.
    """
    if len(p) > 2 and p[0] == '/' and p[2] == '/' and p[1].isalpha():
        return f'{p[1].upper()}:{p[2:]}'
    return p


def bash_path(p: str) -> str:
    """C:/Users/x -> /c/Users/x, para lo que consume bash (el source)."""
    if len(p) > 1 and p[1] == ':':
        return f'/{p[0].lower()}{p[2:]}'.replace('\\', '/')
    return p.replace('\\', '/')


def find_bash() -> str:
    """El bash de Git Bash, no el primero que aparezca en el PATH.

    En esta maquina conviven dos: `Git/usr/bin/bash` monta la raiz de Windows en
    /mnt/c, y `Git/bin/bash` en /c, que es la convencion que usa todo el harness.
    Python resuelve `bash` al primero, asi que un `source /c/.../env.sh` fallaba
    con "No such file or directory" y el comando corria con el PATH de la maquina
    en vez del episodio: `wk-inspect` "no existia" y R1 habria medido un entorno
    roto en vez de una decision del agente.
    """
    override = os.environ.get('RUNNER_BASH')
    if override and Path(override).exists():
        return override
    preferred = Path(r'C:\Program Files\Git\bin\bash.exe')
    if preferred.exists():
        return str(preferred)
    found = shutil.which('bash')
    if not found:
        raise SystemExit('runner: no encuentro bash')
    return found


def run_one(cmd: str, cwd: Path, env_file: Path, timeout: int) -> tuple[str, int]:
    """Ejecuta el comando literalmente, con el entorno del episodio cargado."""
    env_for_bash = bash_path(str(env_file))
    wrapped = f'. "{env_for_bash}"; {cmd}'
    try:
        p = subprocess.run([BASH, '-c', wrapped], cwd=win_path(str(cwd).replace('\\', '/')),
                           capture_output=True, text=True, timeout=timeout)
        return (p.stdout + p.stderr), p.returncode
    except subprocess.TimeoutExpired:
        return f'[runner: el comando no terminó en {timeout}s y se cortó]\n', 124


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--dir', required=True, type=Path)
    ap.add_argument('--env', required=True, type=Path)
    ap.add_argument('--poll', type=float, default=1.0)
    ap.add_argument('--timeout', type=int, default=60)
    a = ap.parse_args()

    global BASH
    BASH = find_bash()

    a.dir = Path(win_path(str(a.dir).replace('\\', '/')))
    workdir = a.dir
    requests = workdir / 'REQUESTS.txt'
    outputs = workdir / 'OUTPUTS.txt'
    logfile = workdir / 'requests.log'

    requests.touch()
    outputs.write_text(BANNER, encoding='utf-8')
    logfile.touch()

    served = 0
    while True:
        try:
            lines = requests.read_text(encoding='utf-8', errors='replace').splitlines()
        except OSError:
            time.sleep(a.poll)
            continue

        # solo lineas con contenido cuentan como peticion; los comentarios del
        # agente no se ejecutan, pero se anotan para no perder el contexto
        pending = lines[served:]
        for raw in pending:
            served += 1
            cmd = raw.strip()
            if not cmd or cmd.startswith('#'):
                with logfile.open('a', encoding='utf-8') as fh:
                    fh.write(json.dumps({'ts': round(time.time(), 3),
                                         'n': served, 'cmd': raw,
                                         'ejecutado': False}) + '\n')
                continue

            out, rc = run_one(cmd, a.dir, a.env, a.timeout)
            with outputs.open('a', encoding='utf-8') as fh:
                fh.write(f'\n--- [{served}] $ {cmd}\n{out}[exit {rc}]\n')
            with logfile.open('a', encoding='utf-8') as fh:
                fh.write(json.dumps({'ts': round(time.time(), 3),
                                     'n': served, 'cmd': cmd,
                                     'ejecutado': True, 'exit': rc}) + '\n')

        time.sleep(a.poll)


if __name__ == '__main__':
    main()
