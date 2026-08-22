#!/usr/bin/env python3
"""Acuerdo entre dos pases de codificacion, y tasas de titular.

    agreement.py <pase1.json> <pase2.json> [--etiqueta teams]

Reporta, por eje, acuerdo bruto y kappa de Cohen. Las tasas se calculan SOLO
sobre los mensajes donde los dos pases coinciden en ese eje; los disputados se
reportan aparte en vez de resolverse a favor de nada.
"""
import argparse, json, sys
from collections import Counter
from pathlib import Path

EJES_POR_DEFECTO = ['categoria', 'delegacion', 'capa']


def kappa(a, b):
    """Cohen's kappa sobre pares alineados."""
    n = len(a)
    if n == 0:
        return None
    po = sum(1 for x, y in zip(a, b) if x == y) / n
    ca, cb = Counter(a), Counter(b)
    pe = sum((ca[k] / n) * (cb[k] / n) for k in set(a) | set(b))
    if pe == 1:
        return None
    return (po - pe) / (1 - pe)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('pase1', type=Path)
    ap.add_argument('pase2', type=Path)
    ap.add_argument('--etiqueta', default='corpus')
    ap.add_argument('--ejes', default=','.join(EJES_POR_DEFECTO),
                    help='ejes a comparar, separados por comas')
    ap.add_argument('--clave-validez', default='categoria',
                    help='campo que debe existir en ambos pases para contar el item')
    a = ap.parse_args()
    ejes = [e.strip() for e in a.ejes.split(',') if e.strip()]

    p1 = {c['id']: c for c in json.loads(a.pase1.read_text())['codigos']}
    p2 = {c['id']: c for c in json.loads(a.pase2.read_text())['codigos']}
    ids = [i for i in sorted(set(p1) & set(p2))
           if p1[i].get(a.clave_validez) and p2[i].get(a.clave_validez)]

    print('== %s: %d mensajes codificados por los dos pases ==\n' % (a.etiqueta, len(ids)))
    print('%-12s %14s %10s' % ('eje', 'acuerdo bruto', 'kappa'))
    acuerdo = {}
    for eje in ejes:
        x = [p1[i].get(eje) for i in ids]
        y = [p2[i].get(eje) for i in ids]
        k = kappa(x, y)
        bruto = sum(1 for u, v in zip(x, y) if u == v) / len(ids) * 100
        acuerdo[eje] = [i for i, u, v in zip(ids, x, y) if u == v]
        print('%-12s %13.1f%% %10s' % (eje, bruto, '%.2f' % k if k is not None else 'n/a'))

    print('\n-- tasas sobre los mensajes en que ambos pases coinciden --')
    for eje in ejes:
        ok = acuerdo[eje]
        disp = len(ids) - len(ok)
        cnt = Counter(p1[i][eje] for i in ok)
        print('\n%s  (n=%d coincidentes, %d disputados excluidos)' % (eje, len(ok), disp))
        for k, v in cnt.most_common():
            print('   %-14s %4d  %5.1f %%' % (k, v, v / len(ok) * 100))

    return 0


if __name__ == '__main__':
    sys.exit(main())
