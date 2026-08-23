#!/usr/bin/env python3
"""Para cada delegacion, reconstruye lo que hizo el RECEPTOR despues.

    extract_followthrough.py <corpus.json> <ids_delegacion.json> <salida.json>

El follow-through no se puede leer del mensaje: hay que mirar los turnos
siguientes del transcript donde llego. El corpus original no guardaba puntero,
asi que aqui se re-extrae con (fichero, linea) y se emparejan los mensajes por
contenido — no por posicion, que no es estable entre ejecuciones.

Se registra aparte, y mecanicamente, si el receptor MANDO respuesta: eso separa
"acuse sin accion" de "acuse interno", que es la distincion que el spec dice que
no admite regex.
"""
import argparse, hashlib, json, re, sys
from pathlib import Path

ROOT = Path.home() / '.claude' / 'projects'
ENV = re.compile(r'<teammate-message\b([^>]*)>(.*?)</teammate-message>', re.S)
ATTR = re.compile(r'([\w_-]+)="([^"]*)"')
# Ventana amplia: con 14 turnos / 9k caracteres, un "sin evidencia" no se podia
# distinguir de "lo corte yo". Ahora se registra ademas si el corte fue nuestro o
# fue el final del transcript, que es la unica forma de que un cero signifique
# algo.
MAX_TURNOS, MAX_CHARS = 25, 18000
MAX_ACCIONES = 300


def key_of(tid, summary, body):
    return (tid, summary[:200], hashlib.sha256(body.encode()).hexdigest()[:16])


def texto(o):
    if o.get('type') == 'queue-operation':
        return str(o.get('content') or '')
    c = (o.get('message') or {}).get('content')
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        return ''.join(b.get('text', '') for b in c
                       if isinstance(b, dict) and b.get('type') == 'text')
    return ''


def render(lineas, desde):
    """Lo que hizo el receptor a partir de `desde`, en dos piezas.

    Una ventana de prosa (para ver si acusa recibo y con que intencion) y, por
    separado, el INDICE COMPLETO de sus acciones posteriores hasta el final del
    transcript. La ventana sola no vale: con 40 turnos seguiamos cortando 37 de
    71 casos, y un corte nuestro no puede sostener un "no lo hizo". El indice es
    barato en tokens y es lo que contesta la pregunta.
    """
    prosa, turnos, envio = [], 0, False
    acciones, truncado_indice = [], False
    for raw in lineas[desde + 1:]:
        try: o = json.loads(raw)
        except Exception: continue
        msg = o.get('message') or {}
        c = msg.get('content')
        blocks = c if isinstance(c, list) else []
        en_ventana = turnos < MAX_TURNOS and sum(len(x) for x in prosa) < MAX_CHARS
        if msg.get('role') == 'assistant':
            if en_ventana: turnos += 1
            for b in blocks:
                if not isinstance(b, dict): continue
                if b.get('type') == 'text' and b.get('text', '').strip() and en_ventana:
                    prosa.append('[dice] ' + b['text'].strip()[:400])
                elif b.get('type') == 'tool_use':
                    inp = b.get('input') or {}
                    # 400 y no 100: con 100 el refutador rechazaba cumplidos
                    # legitimos porque la ruta o el comando citados llegaban
                    # cortados — 4 de 14 refutaciones eran ese artefacto mio.
                    arg = str(inp.get('command') or inp.get('file_path')
                              or inp.get('pattern') or inp.get('summary') or '')[:400]
                    linea = '%s %s' % (b.get('name'), arg)
                    if en_ventana: prosa.append('[usa] ' + linea)
                    if len(acciones) < MAX_ACCIONES: acciones.append(linea)
                    else: truncado_indice = True
                    if b.get('name') == 'SendMessage':
                        envio = True
        elif isinstance(c, list) and en_ventana:
            for b in blocks:
                if isinstance(b, dict) and b.get('type') == 'tool_result':
                    t = b.get('content')
                    t = t if isinstance(t, str) else ''.join(
                        x.get('text', '') for x in (t or []) if isinstance(x, dict))
                    if t.strip(): prosa.append('[resultado] ' + t.strip()[:150])
    return ('\n'.join(prosa)[:MAX_CHARS], turnos, envio, acciones, truncado_indice)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('corpus', type=Path)
    ap.add_argument('ids', type=Path)
    ap.add_argument('salida', type=Path)
    a = ap.parse_args()

    corpus = json.loads(a.corpus.read_text(encoding='utf-8'))
    quiero = set(json.loads(a.ids.read_text(encoding='utf-8')))
    por_clave = {key_of(m['teammate_id'], m['summary'], m['cuerpo']): i
                 for i, m in enumerate(corpus) if i in quiero}

    encontrados = {}
    for p in ROOT.rglob('*.jsonl'):
        try: lineas = p.read_text(encoding='utf-8', errors='ignore').splitlines()
        except Exception: continue
        for idx, raw in enumerate(lineas):
            if 'teammate-message' not in raw: continue
            try: o = json.loads(raw)
            except Exception: continue
            for attrs, body in ENV.findall(texto(o)):
                at = dict(ATTR.findall(attrs))
                k = key_of(at.get('teammate_id', ''), at.get('summary', ''), body.strip())
                if k not in por_clave or por_clave[k] in encontrados: continue
                ctx, turnos, envio, acciones, trunc = render(lineas, idx)
                encontrados[por_clave[k]] = dict(
                    id=por_clave[k], summary=at.get('summary', ''),
                    peticion=body.strip()[:2000], proyecto=p.parent.name,
                    turnos_del_receptor=turnos, mando_respuesta=envio,
                    acciones_posteriores=acciones,
                    indice_truncado=trunc, contexto_posterior=ctx)

    faltan = sorted(quiero - set(encontrados))
    salida = [encontrados[i] for i in sorted(encontrados)]
    a.salida.write_text(json.dumps(salida, ensure_ascii=False, indent=1), encoding='utf-8')
    sin_ctx = sum(1 for x in salida if x['turnos_del_receptor'] == 0)
    print('delegaciones pedidas: %d | reconstruidas: %d | no localizadas: %d'
          % (len(quiero), len(salida), len(faltan)))
    print('sin ningun turno posterior (mensaje al final del transcript): %d' % sin_ctx)
    print('el receptor mando respuesta: %d' % sum(1 for x in salida if x['mando_respuesta']))
    tr = sum(1 for x in salida if x['indice_truncado'])
    acc = [len(x['acciones_posteriores']) for x in salida]
    print('indice de acciones posteriores: mediana %d, max %d' %
          (sorted(acc)[len(acc)//2], max(acc)))
    print('casos con el indice truncado (>%d acciones): %d' % (MAX_ACCIONES, tr))
    if faltan: print('ids no localizados: %s' % faltan[:20])
    return 0


if __name__ == '__main__':
    sys.exit(main())
