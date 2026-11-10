"""Descarga fotos candidatas de cada objeto de taxonomia_objetos.py.

Fuentes: las categorías de Wikimedia Commons de taxonomia_objetos.py (curadas por
personas) y búsquedas en Openverse (Flickr y otros repositorios con licencia
Creative Commons). Solo se aceptan licencias que
permiten obras derivadas: CC0, dominio público, BY, BY-SA, BY-NC y BY-NC-SA.

Las fotos quedan en descargas_crudas/por_objeto/<CATEGORIA>/<objeto>/ y su
URL, autor, licencia y título en candidatas.jsonl. Son candidatas: hay que
revisarlas a ojo (generar_hojas_objeto.py) antes de pasarlas al dataset.

    python descargar_por_objeto.py [--por-objeto 40] [--categoria RCD] [--objetos teja drywall]
"""

import argparse
import io
import json
import random
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import imagehash
import requests
from PIL import Image

from taxonomia_objetos import TAXONOMIA

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
SALIDA = SCRIPT_DIR / 'descargas_crudas' / 'por_objeto'
REGISTRO = SALIDA / 'candidatas.jsonl'
HEADERS = {'User-Agent': 'EcoResiduos-Dataset/3.0 (proyecto academico de clasificacion de residuos)'}

LICENCIAS_OPENVERSE = 'cc0,pdm,by,by-sa,by-nc,by-nc-sa'
LICENCIAS_WIKIMEDIA = re.compile(r'^(cc0|public domain|pd|cc by(-sa)? [0-9.]+|cc by(-sa)?)', re.I)
LADO_MINIMO = 224
LADO_MAXIMO = 800


def buscar_openverse(consulta, cantidad=20, paginas=3):
    """Fotos de Openverse para la consulta (hasta `paginas` páginas), con su atribución."""
    resultados = []
    for pagina in range(1, paginas + 1):
        lote = _pagina_openverse(consulta, cantidad, pagina)
        resultados += lote
        if len(lote) < cantidad:
            break
    return resultados


def _pagina_openverse(consulta, cantidad, pagina):
    """Una página de resultados de Openverse."""
    params = {
        'q': consulta,
        'license': LICENCIAS_OPENVERSE,
        'category': 'photograph',
        'page_size': cantidad,
        'page': pagina,
        'mature': 'false',
    }
    for intento in range(5):
        try:
            r = requests.get('https://api.openverse.org/v1/images/', params=params, headers=HEADERS, timeout=30)
        except requests.RequestException:
            time.sleep(10)
            continue
        if r.status_code == 429 or r.status_code >= 500:
            time.sleep(20 * (intento + 1))
            continue
        if r.status_code != 200:
            return []
        return [
            {
                'url': x['url'],
                'pagina': x.get('foreign_landing_url') or x['url'],
                'autor': x.get('creator') or 'desconocido',
                'licencia': f"CC {x['license'].upper()} {x.get('license_version') or ''}".strip()
                if x['license'] not in ('cc0', 'pdm') else x['license'].upper(),
                'titulo': x.get('title') or '',
                'fuente': f"openverse/{x.get('source') or x.get('provider')}",
            }
            for x in r.json().get('results', [])
            if x.get('url')
        ]
    return []


def api_commons(params):
    """Llamada a la API de Wikimedia Commons con reintentos si limita la velocidad."""
    for intento in range(6):
        try:
            r = requests.get('https://commons.wikimedia.org/w/api.php', params={**params, 'format': 'json'},
                             headers=HEADERS, timeout=30)
            time.sleep(0.5)
            return r.json()
        except (requests.RequestException, ValueError):
            time.sleep(10 * (intento + 1))
    return {}


def miembros_commons(categoria, cantidad, azar):
    """Fotos de una categoría de Wikimedia Commons, al azar, con su atribución."""
    titulos = []
    params = {'action': 'query', 'list': 'categorymembers', 'cmtitle': f'Category:{categoria}',
              'cmtype': 'file', 'cmlimit': '500'}
    while True:
        datos = api_commons(params)
        titulos += [m['title'] for m in datos.get('query', {}).get('categorymembers', [])
                    if m['title'].lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))]
        if 'continue' not in datos or len(titulos) > 1500:
            break
        params.update(datos['continue'])
    azar.shuffle(titulos)

    resultados = []
    for inicio in range(0, min(len(titulos), cantidad * 2), 50):
        datos = api_commons({'action': 'query', 'titles': '|'.join(titulos[inicio:inicio + 50]),
                             'prop': 'imageinfo', 'iiprop': 'url|extmetadata', 'iiurlwidth': str(LADO_MAXIMO)})
        for p in datos.get('query', {}).get('pages', {}).values():
            info = (p.get('imageinfo') or [{}])[0]
            meta = info.get('extmetadata', {})
            licencia = meta.get('LicenseShortName', {}).get('value', '').strip()
            if not LICENCIAS_WIKIMEDIA.match(licencia):
                continue
            autor = re.sub(r'<[^>]+>', '', meta.get('Artist', {}).get('value', '')).strip() or 'desconocido'
            resultados.append({
                'url': info.get('thumburl') or info.get('url'),
                'pagina': info.get('descriptionurl', ''),
                'autor': autor,
                'licencia': licencia,
                'titulo': p.get('title', ''),
                'fuente': f'wikimedia/Category:{categoria}',
            })
    return resultados


def descargar(candidata):
    """Imagen RGB reducida a LADO_MAXIMO, o None si no sirve."""
    try:
        r = requests.get(candidata['url'], headers=HEADERS, timeout=30)
        if r.status_code != 200:
            return None
        imagen = Image.open(io.BytesIO(r.content)).convert('RGB')
    except Exception:
        return None
    ancho, alto = imagen.size
    if min(ancho, alto) < LADO_MINIMO or max(ancho, alto) / min(ancho, alto) > 2.5:
        return None
    imagen.thumbnail((LADO_MAXIMO, LADO_MAXIMO), Image.Resampling.LANCZOS)
    return imagen


def hashes_existentes():
    """Hash perceptual de las fotos que ya están en dataset/, para no repetirlas."""
    hashes = set()
    for ruta in (SCRIPT_DIR / 'dataset').rglob('*'):
        if ruta.suffix.lower() in ('.jpg', '.jpeg', '.png', '.webp'):
            try:
                hashes.add(imagehash.phash(Image.open(ruta)))
            except Exception:
                pass
    return hashes


def main():
    """Busca, descarga y registra las candidatas de cada objeto."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--por-objeto', type=int, default=40)
    parser.add_argument('--categoria')
    parser.add_argument('--objetos', nargs='*', help='solo estos objetos')
    parser.add_argument('--extra', type=int, help='bajar N candidatas más de las que ya tiene cada objeto')
    args = parser.parse_args()

    SALIDA.mkdir(parents=True, exist_ok=True)
    registradas = set()
    if REGISTRO.exists():
        registradas = {json.loads(l)['url'] for l in REGISTRO.read_text(encoding='utf-8').splitlines() if l.strip()}
    print('Calculando hashes del dataset actual...')
    vistos = hashes_existentes()
    print(f'  {len(vistos)} fotos en dataset/')

    with open(REGISTRO, 'a', encoding='utf-8') as registro, ThreadPoolExecutor(8) as hilos:
        for categoria, objetos in TAXONOMIA.items():
            if args.categoria and categoria != args.categoria:
                continue
            for objeto, consultas in objetos.items():
                if args.objetos and objeto not in args.objetos:
                    continue
                carpeta = SALIDA / categoria / objeto
                carpeta.mkdir(parents=True, exist_ok=True)
                ya = len(list(carpeta.glob('*.jpg')))
                objetivo = ya + args.extra if args.extra else args.por_objeto
                if ya >= objetivo:
                    continue

                # Alterna fuentes y consultas para no llenar el objeto con una sola búsqueda.
                azar = random.Random(objeto)
                listas = [miembros_commons(c, objetivo, azar) for c in consultas['commons']]
                listas += [buscar_openverse(q) for q in consultas['openverse']]
                candidatas, urls = [], set()
                for i in range(max(map(len, listas), default=0)):
                    for lista in listas:
                        if i < len(lista) and lista[i]['url'] not in urls and lista[i]['url'] not in registradas:
                            urls.add(lista[i]['url'])
                            candidatas.append(lista[i])

                guardadas = ya
                for inicio in range(0, len(candidatas), 8):
                    if guardadas >= objetivo:
                        break
                    lote = candidatas[inicio:inicio + 8]
                    for candidata, imagen in zip(lote, hilos.map(descargar, lote)):
                        if imagen is None or guardadas >= objetivo:
                            continue
                        h = imagehash.phash(imagen)
                        if any(h - v <= 6 for v in vistos):
                            continue
                        vistos.add(h)
                        guardadas += 1
                        archivo = f'{objeto}_{guardadas:03d}.jpg'
                        imagen.save(carpeta / archivo, 'JPEG', quality=90)
                        registro.write(json.dumps(
                            {'archivo': archivo, 'categoria': categoria, 'objeto': objeto, **candidata},
                            ensure_ascii=False) + '\n')
                        registro.flush()
                print(f'{categoria}/{objeto}: {guardadas} candidatas ({len(candidatas)} encontradas)')


if __name__ == '__main__':
    main()
