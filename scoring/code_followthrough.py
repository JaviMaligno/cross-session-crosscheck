#!/usr/bin/env python3
"""Codifica el desenlace de cada delegacion, en un pase.

    code_followthrough.py <followthrough.json> <salida.json>

Un caso por llamada: en la v1 iban de tres en tres y los contextos largos se
contaminaban entre si. Un pase por proceso, ciego respecto al otro.

Se exige declarar `accion_pedida` ANTES del desenlace y citar evidencia literal
para `cumplido`. La v1 preguntaba ademas si la accion le tocaba al receptor y
salio 100 % "si" sin una sola variacion: una pregunta que solo admite una
respuesta no mide nada, asi que se ha quitado.
"""
import argparse, json, re, subprocess, sys, time
from pathlib import Path

DESENLACES = ['cumplido','acuse_interno_con_cierre','acuse_interno_con_caida',
              'acuse_sin_accion','accion_incorrecta','deriva','sin_evidencia']

PROMPT = """Eres un codificador de contenido. Aplica ESTE codebook, literalmente.

{codebook}

PETICION RECIBIDA:
{peticion}

VENTANA DE PROSA — primeros {turnos} turnos del receptor tras la recepcion:
{prosa}

INDICE DE ACCIONES POSTERIORES del receptor, hasta el final de su sesion ({n} acciones{trunc}):
{indice}

Responde SOLO con un objeto JSON, sin texto alrededor, sin ```:
{{"id": {id}, "accion_pedida": "...", "desenlace": uno de {des}, "evidencia": "cita literal o 'ninguna'", "nada_que_hacer_porque": "solo si el desenlace es acuse_interno_con_cierre, si no cadena vacia"}}"""


def call(prompt):
    r = subprocess.run(['claude','-p',prompt,'--output-format','json'],
                       capture_output=True, text=True)
    if r.returncode != 0:
        # Un `claude -p` que muere por limite de uso sale con codigo != 0 y
        # stderr VACIO. La v1 de esto reportaba '  id X FALLA: ' sin motivo, y 58
        # de 71 casos se perdieron sin que el log dijera por que.
        raise RuntimeError('returncode=%d stderr=%r stdout=%r'
                           % (r.returncode, r.stderr[:200], r.stdout[:200]))
    return json.loads(r.stdout).get('result','')


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('entrada', type=Path); ap.add_argument('salida', type=Path)
    a = ap.parse_args()

    codebook = (Path(__file__).parent / 'codebook_followthrough.md').read_text(encoding='utf-8')
    items = json.loads(a.entrada.read_text(encoding='utf-8'))
    # Reanudar: lo ya codificado con desenlace valido no se repite. Sin esto, un
    # corte a mitad obliga a pagar el pase entero otra vez.
    out, hechos = [], set()
    if a.salida.exists():
        try:
            prev = json.loads(a.salida.read_text(encoding='utf-8')).get('codigos', [])
            out = [c for c in prev if c.get('desenlace')]
            hechos = {int(c['id']) for c in out}
            print('reanudando: %d ya codificados' % len(hechos), file=sys.stderr)
        except Exception:
            pass
    for m in items:
        if m['id'] in hechos:
            continue
        prompt = PROMPT.format(
            codebook=codebook,
            peticion=((m['summary'] + '\n') if m['summary'] else '') + m['peticion'],
            turnos=m['turnos_del_receptor'], prosa=m['contexto_posterior'],
            n=len(m['acciones_posteriores']),
            trunc=', TRUNCADO' if m['indice_truncado'] else '',
            indice='\n'.join(m['acciones_posteriores'])[:30000],
            des=DESENLACES, id=m['id'])
        res = None
        for intento, espera in ((1, 20), (2, 60), (3, 0)):
            try:
                raw = call(prompt)
                mm = re.search(r'\{.*\}', raw, re.S)
                res = json.loads(mm.group(0)); break
            except Exception as e:
                print('  id %s intento %d: %s' % (m['id'], intento, e), file=sys.stderr)
                if espera: time.sleep(espera)
                else: res = dict(id=m['id'], desenlace=None)
        out.append(res)
        # guardar en cada paso: si esto se corta, se reanuda donde iba
        a.salida.write_text(json.dumps(dict(n=len(items), codigos=out),
                                       ensure_ascii=False, indent=1), encoding='utf-8')
        print('  %d/%d' % (len(out), len(items)), file=sys.stderr)

    a.salida.write_text(json.dumps(dict(n=len(items), codigos=out),
                                   ensure_ascii=False, indent=1), encoding='utf-8')
    print('guardado en %s' % a.salida)
    return 0


if __name__ == '__main__':
    sys.exit(main())
