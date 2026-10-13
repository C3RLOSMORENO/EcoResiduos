"""Descarga candidatas de la web para cada categoría con búsquedas específicas.

Las imágenes quedan en descargas_crudas/web/<CATEGORIA>/ y NO entran al dataset
hasta pasar por filtrar_con_gemini.py, que revisa una por una. Aquí solo se
descartan las que no abren, las pequeñas, las muy alargadas, las de catálogo con
fondo blanco y las repetidas.

    python buscar_imagenes_web.py                          # categorías bajo el mínimo
    python buscar_imagenes_web.py --categorias RCD PELIGROSO --por-consulta 80
"""

import argparse
import csv
import hashlib
import html
import io
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from threading import Lock

import imagehash
import requests
from ddgs import DDGS
from PIL import Image

from verificar_dataset import DATASET_DIR, EXTENSIONES, MAX_PROPORCION, MIN_LADO, MINIMO, es_catalogo

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
CRUDAS_DIR = SCRIPT_DIR / 'descargas_crudas' / 'web'
REGISTRO = CRUDAS_DIR / 'origen.csv'
CABECERAS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0 Safari/537.36'
}
LADO_MAXIMO = 800

# Bancos de imágenes cuyas vistas previas traen marca de agua.
DOMINIOS_CON_MARCA_DE_AGUA = (
    'dreamstime', 'depositphotos', 'shutterstock', 'alamy', '123rf', 'istockphoto', 'gettyimages',
    'canstockphoto', 'bigstockphoto', 'stock.adobe', 'agefotostock', 'megapixl', 'colourbox', 'pond5', 'vecteezy',
)
MARCAS_DE_IA = ('ai-image', 'ai-generated', 'ai-art', 'generated-ai', 'midjourney', 'stable-diffusion', 'lexica', 'openart')
BYTES_MAXIMOS = 10 * 1024 * 1024

CONSULTAS = {
    'RCD': [
        'escombros de construcción', 'montón de escombros en la calle', 'escombros de ladrillo roto', 'cascajo de obra',
        'pedazos de concreto demolición', 'escombros de obra en costales', 'escombros en lona', 'baldosa rota escombro',
        'teja de barro rota', 'restos de mortero', 'retal de ladrillo', 'escombros en el andén Bogotá',
        'escombros arrojados en lote', 'volqueta con escombros', 'demolición de pared escombros',
        'escombros de remodelación de baño', 'residuos de construcción y demolición RCD', 'escombros de concreto con varilla',
        'drywall roto residuos', 'bloque de concreto roto', 'escombros mezclados arena y ladrillo',
        'construction debris pile', 'broken bricks rubble', 'concrete rubble pieces', 'demolition debris pile',
        'broken ceramic tiles waste', 'construction waste in bags', 'rubble dumped on sidewalk', 'broken concrete chunks',
        'construction and demolition waste', 'bathroom renovation debris tiles', 'rubble skip dumpster',
        'broken cinder blocks', 'crushed concrete rubble', 'demolished brick wall rubble', 'broken roof tiles pile',
        'plaster debris renovation', 'broken drywall pieces', 'illegal dumping construction waste',
        'concrete with rebar rubble', 'broken terracotta tiles', 'debris from wall demolition',
    ],
    'RIESGO_BIOLOGICO': [
        'jeringas tiradas en la calle',
        'tapabocas botados en el piso',
        'guantes desechables tirados',
        'residuos hospitalarios mal dispuestos',
        'bolsa roja llena hospital',
        'guardián lleno de agujas',
        'jeringas en la playa',
        'tapabocas en la basura',
        'used syringes on the ground',
        'needles littered in park',
        'discarded syringe on beach',
        'face masks littered on street',
        'used masks in trash can',
        'disposable gloves littered parking lot',
        'medical waste dumped illegally',
        'overflowing medical waste bin hospital',
        'sharps container full of needles',
        'red biohazard bag full',
        'bloody bandage in trash',
        'discarded covid masks pile',
        'used gauze pads blood',
        'used face mask on sidewalk',
        'syringe needle in grass',
        'pile of used medical gloves',
    ],
    'PELIGROSO': [
        'pilas usadas en la mano',
        'baterías viejas en el piso',
        'latas de pintura viejas',
        'tarros de aceite de motor usados',
        'bombillos ahorradores dañados',
        'medicamentos vencidos para desechar',
        'punto de recolección de pilas lleno',
        'aerosoles vacíos en la basura',
        'used batteries collection box full',
        'pile of used AA batteries',
        'old batteries in hand',
        'dead batteries on table',
        'used car batteries pile scrapyard',
        'empty spray paint cans pile',
        'empty aerosol cans in trash bin',
        'old paint cans in garage',
        'used paint cans disposal',
        'used motor oil bottles',
        'broken fluorescent tubes pile',
        'used CFL light bulbs pile',
        'expired medicines pile',
        'leaking alkaline batteries',
        'corroded batteries',
        'old pesticide containers',
    ],
    'ORDINARIO': [
        'servilletas usadas basura', 'papel higiénico usado', 'pañal desechable usado', 'empaque de paquete de papas',
        'colillas de cigarrillo', 'icopor sucio con comida', 'toallas de papel sucias', 'barrido basura',
        'used napkins trash', 'crumpled dirty tissues', 'used diaper trash', 'empty chip bags litter',
        'cigarette butts ground', 'dirty styrofoam food container', 'candy wrappers trash', 'used paper towels bin',
        'snack wrappers litter', 'dirty food wrappers',
    ],
    'ORGANICO': [
        'cáscaras de fruta basura', 'restos de comida', 'borra de café usada', 'cáscaras de huevo',
        'cáscaras de plátano', 'restos de verduras cocina', 'fruit peels waste', 'food scraps bin',
        'vegetable peelings kitchen', 'rotten fruit', 'used coffee grounds', 'eggshells waste',
        'leftover food plate', 'compost food scraps', 'banana peel on ground', 'orange peels',
    ],
    'APROVECHABLE': [
        'botella plástica vacía aplastada', 'latas de aluminio aplastadas', 'cartón para reciclar',
        'botellas de vidrio vacías', 'periódicos viejos para reciclar', 'envase tetra pak vacío',
        'crushed plastic bottle', 'crushed soda can', 'flattened cardboard boxes', 'empty glass bottles recycling',
        'old newspapers pile', 'empty tetra pak carton', 'recyclable plastic containers', 'scrap metal cans',
    ],
    'RAEE': [
        'celular dañado', 'cargadores viejos', 'residuos electrónicos', 'teclado viejo dañado', 'mouse de computador viejo',
        'computador portátil dañado', 'televisor viejo desechado', 'licuadora dañada', 'broken smartphone',
        'old phone chargers pile', 'e-waste pile', 'broken keyboard', 'old computer mouse', 'broken laptop',
        'discarded old television', 'broken small appliances', 'old remote controls', 'tangled old cables',
    ],
    'FONDO': [
        'mesa de madera vacía', 'mesón de cocina vacío', 'piso de baldosa', 'piso de cemento', 'andén vacío',
        'palma de la mano abierta', 'caneca vacía por dentro', 'empty wooden table top', 'empty kitchen countertop',
        'tile floor top view', 'concrete floor texture photo', 'empty sidewalk', 'open empty hand palm',
        'empty plastic table', 'grass lawn top view', 'empty trash can inside',
    ],
}


def _slug(texto):
    """Texto en minúsculas con guiones, para nombrar los archivos por consulta."""
    return re.sub(r'[^a-z0-9]+', '-', texto.lower()).strip('-')[:40]


def _util(resultado):
    """False si la imagen viene de un sitio con marca de agua o de un generador de imágenes."""
    texto = f"{resultado['image']} {resultado.get('url', '')}".lower()
    return not any(d in texto for d in DOMINIOS_CON_MARCA_DE_AGUA + MARCAS_DE_IA)


def buscar(consulta, cantidad):
    """Hasta cantidad URL de imágenes distintas para la consulta, pidiendo varias páginas."""
    urls, vistas = [], set()
    for pagina in range(1, 11):
        for intento in range(4):
            try:
                resultados = DDGS().images(consulta, max_results=50, page=pagina)
                break
            except Exception:
                time.sleep(8 * (intento + 1))
        else:
            break
        nuevos = [r for r in resultados if r['image'] not in vistas]
        if not nuevos:
            break
        for r in nuevos:
            vistas.add(r['image'])
            if _util(r):
                urls.append((r['image'], r.get('url', '')))
        if len(urls) >= cantidad:
            break
        time.sleep(1)
    return urls[:cantidad]


class Descargador:
    def __init__(self, categoria):
        self.destino = CRUDAS_DIR / categoria
        self.destino.mkdir(parents=True, exist_ok=True)
        self.categoria = categoria
        self.lock = Lock()
        self.hashes = []
        for carpeta in (self.destino, DATASET_DIR / categoria):
            if carpeta.exists():
                for f in carpeta.iterdir():
                    if f.suffix.lower() in EXTENSIONES:
                        try:
                            with Image.open(f) as im:
                                self.hashes.append(imagehash.phash(im.convert('RGB')))
                        except Exception:
                            pass
        self.guardadas = len(list(self.destino.glob('*.jpg')))

    def bajar(self, url, pagina, consulta):
        try:
            r = requests.get(url, headers=CABECERAS, timeout=12, stream=True)
            if r.status_code != 200 or 'image' not in r.headers.get('Content-Type', 'image'):
                return None
            datos = r.raw.read(BYTES_MAXIMOS + 1, decode_content=True)
            if len(datos) > BYTES_MAXIMOS:
                return None
            im = Image.open(io.BytesIO(datos))
            im.load()
            im = im.convert('RGB')
        except Exception:
            return None

        ancho, alto = im.size
        if min(ancho, alto) < MIN_LADO or max(ancho, alto) / min(ancho, alto) > MAX_PROPORCION or es_catalogo(im):
            return None
        h = imagehash.phash(im)

        with self.lock:
            if any(h - otro <= 6 for otro in self.hashes):
                return None
            self.hashes.append(h)
            self.guardadas += 1
            nombre = f'web_{_slug(consulta)}_{hashlib.sha1(url.encode()).hexdigest()[:10]}.jpg'

        im.thumbnail((LADO_MAXIMO, LADO_MAXIMO))
        im.save(self.destino / nombre, quality=90)
        return {'archivo': f'{self.categoria}/{nombre}', 'url': url, 'pagina': pagina, 'consulta': consulta}


def main():
    """Busca y descarga candidatas para las categorías que están bajo el mínimo."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--categorias', nargs='*', choices=sorted(CONSULTAS))
    parser.add_argument('--por-consulta', type=int, default=60, help='resultados a pedir por búsqueda')
    args = parser.parse_args()

    categorias = args.categorias or [
        c for c in CONSULTAS
        if len([f for f in (DATASET_DIR / c).glob('*') if f.suffix.lower() in EXTENSIONES]) < MINIMO[c]
    ]
    if not categorias:
        print('✅ Todas las categorías tienen el mínimo. Usa --categorias para buscar igual.')
        return

    CRUDAS_DIR.mkdir(parents=True, exist_ok=True)
    nuevo = not REGISTRO.exists()
    with open(REGISTRO, 'a', newline='', encoding='utf-8') as salida:
        registro = csv.DictWriter(salida, fieldnames=['archivo', 'url', 'pagina', 'consulta'])
        if nuevo:
            registro.writeheader()

        for categoria in categorias:
            descargador = Descargador(categoria)
            antes = descargador.guardadas
            print(f'\n🔎 {categoria} ({len(CONSULTAS[categoria])} búsquedas)')
            for consulta in CONSULTAS[categoria]:
                urls = buscar(consulta, args.por_consulta)
                with ThreadPoolExecutor(max_workers=12) as pool:
                    resultados = [r for r in pool.map(lambda u: descargador.bajar(u[0], u[1], consulta), urls) if r]
                registro.writerows(resultados)
                salida.flush()
                print(f'  «{consulta}»: {len(resultados)} de {len(urls)}')
            print(f'  ✅ {descargador.guardadas - antes} candidatas nuevas en {descargador.destino}')

    print('\nSiguiente paso: python filtrar_con_gemini.py')


if __name__ == '__main__':
    main()
