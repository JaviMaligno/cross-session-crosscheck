#!/usr/bin/env python3
"""Pase adversarial: intenta REFUTAR cada `cumplido`.

    refute_followthrough.py <followthrough.json> <acuerdos.json> <salida.json>

Cada cumplido se acepto a la primera en la v1, y en este estudio todos los
instrumentos han fallado al menos una vez y siempre hacia el resultado esperado.
Aqui un pase independiente recibe la evidencia citada y tiene el trabajo
contrario: demostrar que no muestra la accion pedida. Ante duda, refuta.
"""
import argparse, json, re, subprocess, sys
from pathlib import Path

PROMPT = """Tu trabajo es REFUTAR una afirmacion de cumplimiento. No la confirmes por cortesia: si la evidencia citada no demuestra que la accion pedida se hizo, refutala. Ante duda, refuta.

PETICION RECIBIDA:
{peticion}

ACCION QUE OTRO CODIFICADOR DIJO QUE SE PEDIA:
{accion}

EVIDENCIA QUE CITO:
{evidencia}

TODAS las acciones del receptor tras la recepcion, hasta el final de su sesion:
{indice}

Responde SOLO con un objeto JSON, sin texto alrededor:
{{"id": {id}, "refutado": "si" o "no", "motivo": "una linea"}}

"refutado":"si" si la evidencia citada no demuestra la accion pedida (es una intencion, es otra accion, o no aparece en el indice). "no" solo si el indice contiene inequivocamente la accion pedida."""


def call(prompt):
    r = subprocess.run(['claude','-p',prompt,'--output-format','json'],
                       capture_output=True, text=True)
    if r.returncode != 0: raise RuntimeError(r.stderr[:300])
    return json.loads(r.stdout).get('result','')


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('entrada', type=Path)
    ap.add_argument('acuerdos', type=Path)
    ap.add_argument('salida', type=Path)
    a = ap.parse_args()

    items = {m['id']: m for m in json.loads(a.entrada.read_text(encoding='utf-8'))}
    acuerdos = json.loads(a.acuerdos.read_text(encoding='utf-8'))
    out = []
    for c in acuerdos:
        m = items[int(c['id'])]
        prompt = PROMPT.format(
            peticion=((m['summary'] + '\n') if m['summary'] else '') + m['peticion'][:1500],
            accion=c.get('accion_pedida', '(no declarada)'),
            evidencia=c.get('evidencia', '(ninguna)'),
            indice='\n'.join(m['acciones_posteriores'])[:30000],
            id=int(c['id']))
        try:
            raw = call(prompt)
            mm = re.search(r'\{.*\}', raw, re.S)
            out.append(json.loads(mm.group(0)))
        except Exception as e:
            print('  id %s FALLA: %s' % (c['id'], e), file=sys.stderr)
            out.append(dict(id=int(c['id']), refutado=None, motivo='error'))
        print('  %d/%d' % (len(out), len(acuerdos)), file=sys.stderr)

    a.salida.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding='utf-8')
    ref = sum(1 for x in out if x.get('refutado') == 'si')
    print('refutados %d de %d cumplidos' % (ref, len(out)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
