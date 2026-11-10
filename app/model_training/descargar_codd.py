"""Recorta fragmentos de RCD del dataset CODD como candidatas por objeto.

CODD (Construction and Demolition Waste Object Detection Dataset) tiene fotos de
una planta de reciclaje de RCD en Chipre con cada fragmento anotado por material.
Licencia CC BY 4.0. Cita: Demetriou, D., Mavromatidis, P., Petrou, M. y
Nicolaides, D. (2023). CODD. Mendeley Data, v3. doi:10.17632/wds85kt64j.3

Los recortes van a descargas_crudas/por_objeto/RCD/<objeto>/ con la numeración
que siga y se anotan en candidatas.jsonl, igual que descargar_por_objeto.py.
Pasan por la misma revisión visual antes de entrar al dataset.

    python descargar_codd.py [--por-objeto 60] [--objetos concreto] [--lado-minimo 200]
"""

import argparse
import io
import json
import random
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import requests
from PIL import Image

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
SALIDA = SCRIPT_DIR / 'descargas_crudas' / 'por_objeto'
REGISTRO = SALIDA / 'candidatas.jsonl'
API = 'https://data.mendeley.com/public-api/datasets/wds85kt64j'
PAGINA = 'https://data.mendeley.com/datasets/wds85kt64j/3'
AUTORES = 'Demetriou, D.; Mavromatidis, P.; Petrou, M.; Nicolaides, D.'
CARPETAS = {
    'testing': '613eaed1-79c4-4eae-b45c-6fcd48cc52bb',
    'validation': '8f5e9687-a8c8-4b59-9014-0f18b0731259',
    'training': 'd3875d12-efbb-4f8e-a776-64e167cf4872',
}
# Clase de CODD -> objeto de taxonomia_objetos.py
CLASES = {
    'brick': 'ladrillo',
    'concrete': 'concreto',
    'tile': 'ceramica_baldosa',
    'gypsum_board': 'drywall',
    'wood': 'madera_obra',
}
LADO_MINIMO = 200
MARGEN = 0.2


def archivos(carpeta):
    """{nombre: url de descarga} de una carpeta de CODD."""
    r = requests.get(f'{API}/files', params={'folder_id': carpeta, 'version': 3}, timeout=60)
    return {f['filename']: f['content_details']['download_url'] for f in r.json()}


def main():
    """Descarga anotaciones, elige fragmentos grandes y guarda sus recortes."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--por-objeto', type=int, default=60)
    parser.add_argument('--objetos', nargs='*', help='solo estos objetos')
    parser.add_argument('--lado-minimo', type=int, default=LADO_MINIMO)
    args = parser.parse_args()

    azar = random.Random(7)
    guardados = {o: 0 for o in set(CLASES.values()) if not args.objetos or o in args.objetos}
    numero = {o: len(list((SALIDA / 'RCD' / o).glob('*.jpg'))) for o in guardados}
    sesion = requests.Session()

    with open(REGISTRO, 'a', encoding='utf-8') as registro:
        for subconjunto, carpeta in CARPETAS.items():
            lista = archivos(carpeta)
            xmls = sorted(n for n in lista if n.endswith('.xml'))
            azar.shuffle(xmls)
            for nombre_xml in xmls:
                if all(n >= args.por_objeto for n in guardados.values()):
                    break
                raiz = ET.fromstring(sesion.get(lista[nombre_xml], timeout=60).content)
                cajas = []
                for obj in raiz.iter('object'):
                    objeto = CLASES.get(obj.findtext('name', '').strip().lower())
                    caja = obj.find('bndbox')
                    if objeto not in guardados or caja is None or guardados[objeto] >= args.por_objeto:
                        continue
                    x0, y0, x1, y1 = (int(float(caja.findtext(k))) for k in ('xmin', 'ymin', 'xmax', 'ymax'))
                    if min(x1 - x0, y1 - y0) >= args.lado_minimo:
                        cajas.append((objeto, x0, y0, x1, y1))
                if not cajas:
                    continue
                nombre_jpg = nombre_xml[:-4] + '.jpg'
                if nombre_jpg not in lista:
                    continue
                foto = Image.open(io.BytesIO(sesion.get(lista[nombre_jpg], timeout=60).content)).convert('RGB')
                # Un fragmento por foto y clase para no repetir la misma escena.
                vistos = set()
                for objeto, x0, y0, x1, y1 in cajas:
                    if objeto in vistos or guardados[objeto] >= args.por_objeto:
                        continue
                    vistos.add(objeto)
                    lado = max(x1 - x0, y1 - y0) * (1 + 2 * MARGEN)
                    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
                    recorte = foto.crop((
                        int(max(0, cx - lado / 2)), int(max(0, cy - lado / 2)),
                        int(min(foto.width, cx + lado / 2)), int(min(foto.height, cy + lado / 2)),
                    ))
                    guardados[objeto] += 1
                    numero[objeto] += 1
                    archivo = f'{objeto}_{numero[objeto]:03d}.jpg'
                    (SALIDA / 'RCD' / objeto).mkdir(parents=True, exist_ok=True)
                    recorte.save(SALIDA / 'RCD' / objeto / archivo, 'JPEG', quality=92)
                    registro.write(json.dumps({
                        'archivo': archivo, 'categoria': 'RCD', 'objeto': objeto,
                        'url': lista[nombre_jpg], 'pagina': PAGINA, 'autor': AUTORES,
                        'licencia': 'CC BY 4.0',
                        'titulo': f'CODD {subconjunto}/{nombre_jpg} (recorte de {objeto})',
                        'fuente': 'codd',
                    }, ensure_ascii=False) + '\n')
                    registro.flush()
            print(f'{subconjunto}: {guardados}')
    print(f'Recortes por objeto: {guardados}')


if __name__ == '__main__':
    main()
