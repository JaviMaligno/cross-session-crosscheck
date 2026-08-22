#!/usr/bin/env python3
"""Codifica un corpus de mensajes con el codebook, en un pase.

    code_corpus.py <corpus.json> <salida.json> [--lote 8] [--max-chars 3000]

Cada pase corre en su PROPIO proceso `claude -p`, asi que es ciego respecto al
otro por construccion: no hay estado compartido ni contexto comun. Los mensajes
van en lotes porque 196 llamadas de una en una no compran nada — el codificador
humano tambien lee varios seguidos — y se registra el tamano de lote porque es
parte del metodo.

Los cuerpos se recortan: el motivo del mensaje esta al principio y el p90 son
~5k caracteres. El recorte se declara en la salida, no se esconde.
"""
import argparse, json, re, subprocess, sys
from pathlib import Path

CATS = ['aviso_alcance','notificacion_progreso','handoff_recurso',
        'aviso_defecto_ajeno','rectificacion','respuesta_estado',
        'consulta_estado','peticion_accion','peticion_espera','otro']

PROMPT = """Eres un codificador de contenido. Aplica ESTE codebook, literalmente, sin añadir criterios propios.

{codebook}

Codifica cada mensaje de abajo. Para cada uno devuelve un objeto con:
  "id": el id que te doy
  "categoria": uno de {cats}
  "delegacion": "si" o "no"
  "capa": "sintactica" o "semantica"

Responde SOLO con un array JSON, sin texto alrededor, sin ```. Un objeto por mensaje, en el mismo orden.

{mensajes}
"""


def call(prompt: str) -> str:
    r = subprocess.run(['claude', '-p', prompt, '--output-format', 'json'],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr[:400])
    return json.loads(r.stdout).get('result', '')


def parse(raw: str):
    m = re.search(r'\[.*\]', raw, re.S)
    if not m:
        raise ValueError('sin array JSON en la respuesta')
    return json.loads(m.group(0))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('corpus', type=Path)
    ap.add_argument('salida', type=Path)
    ap.add_argument('--lote', type=int, default=8)
    ap.add_argument('--max-chars', type=int, default=3000)
    a = ap.parse_args()

    codebook = (Path(__file__).parent / 'codebook.md').read_text(encoding='utf-8')
    corpus = json.loads(a.corpus.read_text(encoding='utf-8'))
    out, truncados = [], 0

    for i in range(0, len(corpus), a.lote):
        chunk = corpus[i:i + a.lote]
        bloques = []
        for j, m in enumerate(chunk):
            cuerpo = m['cuerpo']
            if len(cuerpo) > a.max_chars:
                cuerpo = cuerpo[:a.max_chars] + ' […recortado]'
                truncados += 1
            s = ('resumen: %s\n' % m['summary']) if m.get('summary') else ''
            bloques.append('--- mensaje id=%d ---\n%s%s' % (i + j, s, cuerpo))
        prompt = PROMPT.format(codebook=codebook, cats=CATS,
                               mensajes='\n\n'.join(bloques))
        for intento in (1, 2):
            try:
                res = parse(call(prompt)); break
            except Exception as e:
                if intento == 2:
                    print('  lote %d-%d FALLA: %s' % (i, i + len(chunk) - 1, e),
                          file=sys.stderr)
                    res = [dict(id=i + j, categoria=None, delegacion=None, capa=None)
                           for j in range(len(chunk))]
        out.extend(res)
        print('  codificados %d/%d' % (min(i + a.lote, len(corpus)), len(corpus)),
              file=sys.stderr)

    a.salida.write_text(json.dumps(
        dict(n=len(corpus), lote=a.lote, max_chars=a.max_chars,
             cuerpos_recortados=truncados, codigos=out),
        ensure_ascii=False, indent=1), encoding='utf-8')
    print('pase guardado en %s (%d codigos, %d cuerpos recortados)'
          % (a.salida, len(out), truncados))
    return 0


if __name__ == '__main__':
    sys.exit(main())
