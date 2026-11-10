"""Arma una hoja de contactos numerada por objeto para revisar las candidatas a ojo.

Cada hoja muestra las fotos de descargas_crudas/por_objeto/<CATEGORIA>/<objeto>/
con el número del archivo en la esquina. Quedan en por_objeto/_hojas/.

    python generar_hojas_objeto.py [--desde 41] [--objetos teja drywall] [--categoria RCD] [--sin-revisar]
"""

import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
BASE = SCRIPT_DIR / 'descargas_crudas' / 'por_objeto'
HOJAS = BASE / '_hojas'
LADO = 260
COLUMNAS = 6


def fuente(tam):
    """Fuente legible si existe; la de PIL si no."""
    for nombre in ('arialbd.ttf', 'arial.ttf', 'DejaVuSans-Bold.ttf'):
        try:
            return ImageFont.truetype(nombre, tam)
        except OSError:
            pass
    return ImageFont.load_default()


def hoja(categoria, objeto, fotos):
    """Imagen con las fotos en cuadrícula y su número en la esquina superior izquierda."""
    filas = (len(fotos) + COLUMNAS - 1) // COLUMNAS
    lienzo = Image.new('RGB', (COLUMNAS * LADO, filas * LADO + 40), 'white')
    dibujo = ImageDraw.Draw(lienzo)
    dibujo.text((10, 8), f'{categoria} / {objeto}', fill='black', font=fuente(24))
    letra = fuente(26)
    for i, ruta in enumerate(fotos):
        foto = Image.open(ruta).convert('RGB')
        foto.thumbnail((LADO - 6, LADO - 6))
        x, y = (i % COLUMNAS) * LADO, (i // COLUMNAS) * LADO + 40
        lienzo.paste(foto, (x + (LADO - foto.width) // 2, y + (LADO - foto.height) // 2))
        numero = re.search(r'_(\d+)\.jpg$', ruta.name).group(1).lstrip('0')
        dibujo.rectangle((x + 2, y + 2, x + 46, y + 34), fill='yellow', outline='black')
        dibujo.text((x + 6, y + 3), numero, fill='black', font=letra)
    return lienzo


def main():
    """Genera una hoja por cada carpeta de objeto que tenga fotos.

    Con --desde N solo entran las fotos con número mayor o igual a N (las de
    una ronda nueva), y la hoja lleva el sufijo _desdeN.
    """
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--desde', type=int, default=1)
    parser.add_argument('--objetos', nargs='*')
    parser.add_argument('--categoria')
    parser.add_argument('--sin-revisar', action='store_true',
                        help='solo las fotos que aún no están en el veredicto de _revision/')
    args = parser.parse_args()
    HOJAS.mkdir(parents=True, exist_ok=True)
    total = 0
    for carpeta in sorted(BASE.glob('*/*')):
        if carpeta.parent.name.startswith('_') or not carpeta.is_dir():
            continue
        if args.objetos and carpeta.name not in args.objetos:
            continue
        if args.categoria and carpeta.parent.name != args.categoria:
            continue
        numero = lambda f: int(re.search(r'_(\d+)\.jpg$', f.name).group(1))
        fotos = [f for f in sorted(carpeta.glob('*.jpg')) if numero(f) >= args.desde]
        sufijo = f'_desde{args.desde}' if args.desde > 1 else ''
        if args.sin_revisar:
            veredicto = BASE / '_revision' / f'{carpeta.parent.name}__{carpeta.name}.json'
            vistos = set()
            if veredicto.exists():
                d = json.loads(veredicto.read_text(encoding='utf-8'))
                vistos = set(d['aceptadas']) | set(d['rechazadas'])
            fotos = [f for f in fotos if numero(f) not in vistos]
            sufijo = f'_desde{numero(fotos[0])}' if fotos else ''
        if fotos:
            hoja(carpeta.parent.name, carpeta.name, fotos).save(
                HOJAS / f'{carpeta.parent.name}__{carpeta.name}{sufijo}.jpg', quality=85)
            total += 1
    print(f'{total} hojas en {HOJAS}')


if __name__ == '__main__':
    main()
