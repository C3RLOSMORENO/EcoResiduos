"""Pasa al dataset las candidatas aprobadas en la revisión visual.

Lee los veredictos de descargas_crudas/por_objeto/_revision/<CATEGORIA>__<objeto>.json
({"aceptadas": [números], "rechazadas": [números], ...}), copia las aceptadas a
dataset/<CATEGORIA>/objeto_<objeto>_<n>.jpg y anota URL, autor y licencia de
cada una en fuentes_individuales.csv. Un objeto sin veredicto no se toca.

    python integrar_por_objeto.py            muestra qué haría
    python integrar_por_objeto.py --aplicar  copia y registra
"""

import argparse
import csv
import json
import shutil
import sys
from collections import Counter
from pathlib import Path

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
BASE = SCRIPT_DIR / 'descargas_crudas' / 'por_objeto'
REVISION = BASE / '_revision'
DATASET = SCRIPT_DIR / 'dataset'
FUENTES = SCRIPT_DIR / 'fuentes_individuales.csv'
COLUMNAS = ['archivo', 'categoria', 'url', 'autor', 'licencia', 'titulo']


def main():
    """Copia las aceptadas al dataset y registra su atribución."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--aplicar', action='store_true')
    args = parser.parse_args()

    metadatos = {}
    for linea in (BASE / 'candidatas.jsonl').read_text(encoding='utf-8').splitlines():
        if linea.strip():
            d = json.loads(linea)
            metadatos[(d['categoria'], d['archivo'])] = d

    ya_registradas = set()
    if FUENTES.exists():
        with open(FUENTES, encoding='utf-8', newline='') as f:
            ya_registradas = {fila['archivo'] for fila in csv.DictReader(f)}

    filas, por_objeto, por_categoria = [], {}, Counter()
    for veredicto in sorted(REVISION.glob('*.json')):
        categoria, objeto = veredicto.stem.split('__')
        aceptadas = json.loads(veredicto.read_text(encoding='utf-8'))['aceptadas']
        por_objeto[f'{categoria}/{objeto}'] = len(aceptadas)
        for n in aceptadas:
            origen = BASE / categoria / objeto / f'{objeto}_{n:03d}.jpg'
            meta = metadatos.get((categoria, origen.name))
            if not origen.exists() or meta is None:
                print(f'  falta {origen.relative_to(BASE)} o su registro; se omite')
                continue
            destino = f'objeto_{objeto}_{n:03d}.jpg'
            if destino in ya_registradas:
                continue
            por_categoria[categoria] += 1
            filas.append((origen, DATASET / categoria / destino, {
                'archivo': destino, 'categoria': categoria, 'url': meta['pagina'] or meta['url'],
                'autor': meta['autor'], 'licencia': meta['licencia'], 'titulo': meta['titulo'],
            }))

    for clave, n in por_objeto.items():
        print(f'{clave}: {n} aprobadas{"  << menos de 2" if n < 2 else ""}')
    print(f'\nNuevas por categoría: {dict(por_categoria)}  (total {sum(por_categoria.values())})')

    if not args.aplicar:
        print('\nSin --aplicar no se copió nada.')
        return
    with open(FUENTES, 'a', encoding='utf-8', newline='') as f:
        escritor = csv.DictWriter(f, fieldnames=COLUMNAS)
        for origen, destino, fila in filas:
            shutil.copy2(origen, destino)
            escritor.writerow(fila)
    print(f'Copiadas {len(filas)} fotos y registradas en {FUENTES.name}')


if __name__ == '__main__':
    main()
