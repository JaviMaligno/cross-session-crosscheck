#!/usr/bin/env python3
"""Codifica el desenlace de cada delegacion, en un pase.

    code_followthrough.py <followthrough.json> <salida.json> [--lote 3]

Un pase por proceso, ciego respecto al otro. Lotes pequenos porque cada item
lleva el contexto posterior del receptor y son largos.
"""
import argparse, json, re, subprocess, sys
from pathlib import Path

DESENLACES = ['cumplido','acuse_interno_con_cierre','acuse_interno_con_caida',
              'acuse_sin_accion','accion_incorrecta','deriva','sin_evidencia']

PROMPT = """Eres un codificador de contenido. Aplica ESTE codebook, literalmente.

{codebook}

Para cada caso devuelve un objeto con:
  "id": el id que te doy
  "desenlace": uno de {des}
  "accion_le_tocaba": "si" o "no"
  "evidencia": una cita corta de los turnos posteriores que sostiene tu decision (máx 120 caracteres)

Responde SOLO con un array JSON, sin texto alrededor, sin ```.

{casos}
"""


def call(prompt):
    r = subprocess.run(['claude','-p',prompt,'--output-format','json'],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr[:300])
    return json.loads(r.stdout).get('result','')


def parse(raw):
    m = re.search(r'\[.*\]', raw, re.S)
    if not m: raise ValueError('sin array JSON')
    return json.loads(m.group(0))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('entrada', type=Path); ap.add_argument('salida', type=Path)
    ap.add_argument('--lote', type=int, default=3)
    a = ap.parse_args()

    codebook = (Path(__file__).parent / 'codebook_followthrough.md').read_text(encoding='utf-8')
    items = json.loads(a.entrada.read_text(encoding='utf-8'))
    out = []
    for i in range(0, len(items), a.lote):
        chunk = items[i:i+a.lote]
        casos = []
        for m in chunk:
            casos.append(
                '=== caso id=%d ===\nPETICION RECIBIDA:\n%s\n\nLO QUE HIZO EL RECEPTOR DESPUES '
                '(%d turnos):\n%s' % (m['id'], (m['summary'] + '\n' if m['summary'] else '')
                                      + m['peticion'], m['turnos_del_receptor'],
                                      m['contexto_posterior']))
        prompt = PROMPT.format(codebook=codebook, des=DESENLACES, casos='\n\n'.join(casos))
        for intento in (1,2):
            try:
                res = parse(call(prompt)); break
            except Exception as e:
                if intento == 2:
                    print('  lote %d FALLA: %s' % (i, e), file=sys.stderr)
                    res = [dict(id=m['id'], desenlace=None) for m in chunk]
        out.extend(res)
        print('  %d/%d' % (min(i+a.lote, len(items)), len(items)), file=sys.stderr)
    a.salida.write_text(json.dumps(dict(n=len(items), lote=a.lote, codigos=out),
                                   ensure_ascii=False, indent=1), encoding='utf-8')
    print('guardado en %s' % a.salida)
    return 0


if __name__ == '__main__':
    sys.exit(main())
