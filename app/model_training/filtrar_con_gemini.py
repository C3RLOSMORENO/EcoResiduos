"""Gemini revisa UNA POR UNA las imágenes y solo deja las que muestran el residuo.

    python filtrar_con_gemini.py                      # candidatas de la web → dataset
    python filtrar_con_gemini.py --revisar-dataset    # limpia lo que ya está en dataset/
    python filtrar_con_gemini.py --categorias RCD --limite 24

Envía las imágenes en lotes (cada una con su propio veredicto) y, cuando un
modelo agota su cuota diaria, sigue con el siguiente. Con las candidatas, las
aceptadas se copian a dataset/<CATEGORIA>/ hasta el máximo por categoría. Con
--revisar-dataset, las rechazadas se mueven a rechazadas/<CATEGORIA>/ (no se
borran). Cada decisión queda en revision/decisiones_gemini.csv: si se corta o se
acaba la cuota, al volver a ejecutar sigue donde iba.
"""

import argparse
import base64
import csv
import hashlib
import io
import json
import re
import shutil
import sys
import time
from pathlib import Path

import requests
from PIL import Image

from auditar_dataset_con_gemini import get_api_key
from verificar_dataset import CATEGORIAS, DATASET_DIR, EXTENSIONES, MAXIMO

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
CANDIDATAS_DIR = SCRIPT_DIR / 'descargas_crudas' / 'web'
RECHAZADAS_DIR = SCRIPT_DIR / 'rechazadas'
DECISIONES = SCRIPT_DIR / 'revision' / 'decisiones_gemini.csv'
API = 'https://generativelanguage.googleapis.com/v1beta'
CONFIANZA_MINIMA = 75
LOTE = 24
CAMPOS = ['sha1', 'ruta', 'esperada', 'decision', 'categoria', 'objeto', 'confianza', 'motivo', 'modelo', 'version']
# Sube al endurecer el criterio: lo aceptado con una versión anterior se vuelve
# a revisar; lo rechazado sigue rechazado.
VERSION_CRITERIO = '2'

DEFINICIONES = """
- APROVECHABLE: botellas y envases plásticos, latas de aluminio o acero, cartón, papel limpio, periódico, frascos y botellas de vidrio, tetra pak. Vacíos, usados o aplastados.
- ORGANICO: cáscaras de fruta, restos de verduras, restos de comida, borra de café, bolsitas de té, cáscaras de huevo, hojas y pasto cortado.
- ORDINARIO: servilletas, papel higiénico o toallas de papel usadas, pañales usados, empaques metalizados de paquetes o dulces, colillas de cigarrillo, icopor sucio.
- PELIGROSO: pilas y baterías (sueltas, no dentro de un aparato), baterías de carro, aerosoles, tarros de pintura, solventes, aceite de motor, plaguicidas, bombillos ahorradores y tubos fluorescentes, medicamentos.
- RAEE: aparatos eléctricos o electrónicos completos o sus partes: celulares, cargadores, cables, computadores, teclados, mouse, televisores, electrodomésticos, placas de circuito.
- RCD: escombros de construcción y demolición: ladrillo roto, trozos de concreto o mortero, baldosa o cerámica rota, tejas rotas, drywall roto, montones de escombro, costales o contenedores llenos de escombro.
- RIESGO_BIOLOGICO: jeringas y agujas, guardianes, gasas o algodones con sangre, guantes de látex o nitrilo usados, tapabocas usados, bolsas rojas de residuos hospitalarios.
- FONDO: superficies SIN ningún residuo: mesa, mesón, piso, andén, pasto, mano vacía, caneca vacía.
"""

PROMPT = """Eres un revisor estricto de un dataset para un clasificador de residuos que usa fotos tomadas con celular en Colombia.
Categorías (Resolución 2184 de 2019):
{definiciones}
Recibirás {n} imágenes numeradas del 1 al {n}, propuestas para la categoría {esperada}. Juzga CADA imagen por separado.
Responde SOLO con un arreglo JSON de {n} objetos, en el mismo orden, cada uno así:
{{
  "n": número de la imagen,
  "es_foto_real": true si es una fotografía real; false si es dibujo, ícono, render 3D, imagen generada por IA, textura sintética, collage, captura de pantalla o infografía,
  "texto_o_marca_de_agua": true si tiene texto superpuesto, banners, logos de bancos de imágenes o marcas de agua,
  "personas_protagonistas": true si una persona, cara o cuerpo es lo principal (una mano sosteniendo el objeto o un trabajador al fondo sí se permiten),
  "objeto_principal": "qué se ve, en pocas palabras",
  "ocupa_suficiente": true si el residuo ocupa al menos un 30 % de la imagen y está enfocado,
  "es_residuo": true si se ve usado, roto, vacío, desechado o listo para botar; false si es un producto nuevo en tienda, empaque o catálogo,
  "instalado": true si el material sigue puesto en su lugar aunque esté dañado: pared con hueco, techo con tejas, piso o andén agrietado, baldosa pegada, aparato conectado en uso,
  "desastre": true si es un edificio colapsado, terremoto, guerra, bombardeo, incendio, inundación o accidente, o hay multitudes o rescatistas,
  "categoria": una de APROVECHABLE, ORGANICO, ORDINARIO, PELIGROSO, RAEE, RCD, RIESGO_BIOLOGICO, FONDO, o "NINGUNA" si no es ninguna, o "AMBIGUA" si hay residuos de varias categorías o no se puede saber,
  "confianza": 0 a 100,
  "motivo": "una frase"
}}
Sé exigente: el residuo debe estar SUELTO y separado de donde estaba (en el piso, en un montón, en un costal, contenedor o volqueta). Casas o edificios en pie, obras en construcción sin escombro, maquinaria sola, vehículos, paisajes, animales, retratos, trenes, obras de arte, portadas o fotos históricas son "NINGUNA"."""


class CuotaAgotada(Exception):
    pass


class Modelos:
    """Modelos disponibles en orden de preferencia; descarta los que agotan su cuota del día."""

    def __init__(self, clave, forzado=None):
        self.lista = [forzado] if forzado else self._disponibles(clave)
        if not self.lista:
            raise SystemExit('❌ La API no ofrece ningún modelo «flash». Pasa uno con --modelo.')

    @staticmethod
    def _disponibles(clave):
        r = requests.get(f'{API}/models', params={'key': clave, 'pageSize': 1000}, timeout=20)
        r.raise_for_status()
        candidatos = []
        for m in r.json().get('models', []):
            nombre = m['name'].removeprefix('models/')
            if 'generateContent' not in m.get('supportedGenerationMethods', []) or 'flash' not in nombre:
                continue
            if 'latest' in nombre or any(x in nombre for x in ('image', 'tts', 'live', 'audio', 'thinking', 'exp', 'omni')):
                continue
            version = tuple(int(n) for n in re.findall(r'\d+', nombre.split('flash')[0])) or (0,)
            candidatos.append(('lite' not in nombre, 'preview' not in nombre, version, nombre))
        return [c[-1] for c in sorted(candidatos, reverse=True)]

    @property
    def actual(self):
        if not self.lista:
            raise CuotaAgotada()
        return self.lista[0]

    def descartar(self, modelo):
        if modelo in self.lista:
            self.lista.remove(modelo)
            print(f'  🔁 {modelo} no está disponible hoy' + (f'; sigo con {self.lista[0]}' if self.lista else ''))

    def rotar(self, modelo):
        """Pasa un modelo saturado al final de la fila sin descartarlo."""
        if modelo in self.lista and len(self.lista) > 1:
            self.lista.remove(modelo)
            self.lista.append(modelo)


def preparar(ruta):
    with Image.open(ruta) as im:
        im = im.convert('RGB')
        im.thumbnail((512, 512))
        buf = io.BytesIO()
        im.save(buf, format='JPEG', quality=85)
    return base64.b64encode(buf.getvalue()).decode()


def consultar_lote(clave, modelos, rutas, esperada):
    partes = [{'text': PROMPT.format(definiciones=DEFINICIONES, esperada=esperada, n=len(rutas))}]
    for i, ruta in enumerate(rutas, 1):
        partes += [{'text': f'Imagen {i}:'}, {'inline_data': {'mime_type': 'image/jpeg', 'data': preparar(ruta)}}]
    cuerpo = {'contents': [{'parts': partes}], 'generationConfig': {'response_mime_type': 'application/json', 'temperature': 0}}

    for intento in range(20):
        modelo = modelos.actual
        try:
            r = requests.post(f'{API}/models/{modelo}:generateContent', params={'key': clave}, json=cuerpo, timeout=120)
        except requests.RequestException:
            time.sleep(5 * (intento + 1))
            continue
        if r.status_code == 200:
            try:
                veredictos = json.loads(r.json()['candidates'][0]['content']['parts'][0]['text'])
                por_numero = {int(v.get('n', i + 1)): v for i, v in enumerate(veredictos)}
                return modelo, [por_numero.get(i, {}) for i in range(1, len(rutas) + 1)]
            except (KeyError, IndexError, ValueError, TypeError):
                time.sleep(2)
                continue
        if r.status_code == 429 and 'PerDay' in r.text:
            modelos.descartar(modelo)
            continue
        if r.status_code == 404:
            modelos.descartar(modelo)
            continue
        if r.status_code in (500, 503):
            modelos.rotar(modelo)
            time.sleep(3)
            continue
        if r.status_code == 429:
            m = re.search(r'"retryDelay":\s*"(\d+)', r.text)
            modelos.rotar(modelo)
            time.sleep(min(60, int(m.group(1)) + 1) if m and len(modelos.lista) == 1 else 3)
            continue
        raise RuntimeError(f'HTTP {r.status_code}: {r.text[:200]}')
    raise RuntimeError('La API no respondió después de varios intentos')


def aceptada(v, esperada):
    try:
        confianza = int(v.get('confianza', 0))
    except (TypeError, ValueError):
        confianza = 0
    if v.get('categoria') != esperada or confianza < CONFIANZA_MINIMA:
        return False
    if not v.get('es_foto_real') or v.get('texto_o_marca_de_agua') or v.get('personas_protagonistas'):
        return False
    if v.get('desastre'):
        return False
    if esperada == 'FONDO':
        return True
    if v.get('instalado'):
        return False
    return bool(v.get('ocupa_suficiente')) and bool(v.get('es_residuo'))


def sha1(ruta):
    return hashlib.sha1(ruta.read_bytes()).hexdigest()


def cargar_decisiones(archivo):
    if not archivo.exists():
        return {}
    with open(archivo, encoding='utf-8') as f:
        return {
            (fila['sha1'], fila['esperada']): fila
            for fila in csv.DictReader(f)
            if fila.get('version') == VERSION_CRITERIO or fila['decision'] == 'rechazada'
        }


def contar(categoria):
    carpeta = DATASET_DIR / categoria
    return len([f for f in carpeta.glob('*') if f.suffix.lower() in EXTENSIONES]) if carpeta.exists() else 0


def aplicar(ruta, categoria, ok, revisar_dataset):
    if revisar_dataset and not ok and ruta.exists():
        destino = RECHAZADAS_DIR / categoria
        destino.mkdir(parents=True, exist_ok=True)
        shutil.move(str(ruta), destino / ruta.name)
    elif not revisar_dataset and ok and contar(categoria) < MAXIMO:
        destino = DATASET_DIR / categoria / ruta.name
        if not destino.exists():
            destino.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ruta, destino)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--revisar-dataset', action='store_true', help='revisar dataset/ en vez de las candidatas')
    parser.add_argument('--categorias', nargs='*', choices=sorted(CATEGORIAS))
    parser.add_argument('--modelo', help='usar solo este modelo de Gemini')
    parser.add_argument('--limite', type=int, help='revisar como máximo N imágenes por categoría (para probar)')
    parser.add_argument('--decisiones', type=Path, help='archivo de decisiones propio, para correr varias categorías en paralelo')
    args = parser.parse_args()

    clave = get_api_key()
    if not clave:
        raise SystemExit('❌ No se encontró GEMINI_API_KEY (en app/.env o como variable de entorno).')
    modelos = Modelos(clave, args.modelo)
    print(f'🤖 Modelos en orden: {", ".join(modelos.lista)}')

    origen = DATASET_DIR if args.revisar_dataset else CANDIDATAS_DIR
    categorias = args.categorias or sorted(c for c in CATEGORIAS if (origen / c).exists())
    archivo_decisiones = args.decisiones or DECISIONES
    decisiones = cargar_decisiones(DECISIONES)
    if archivo_decisiones != DECISIONES:
        decisiones |= cargar_decisiones(archivo_decisiones)
    archivo_decisiones.parent.mkdir(exist_ok=True)
    nuevo = not archivo_decisiones.exists()

    with open(archivo_decisiones, 'a', newline='', encoding='utf-8') as salida:
        escritor = csv.DictWriter(salida, fieldnames=CAMPOS)
        if nuevo:
            escritor.writeheader()

        try:
            for categoria in categorias:
                if not args.revisar_dataset and contar(categoria) >= MAXIMO:
                    print(f'\n⏭️  {categoria}: ya tiene {MAXIMO} imágenes')
                    continue
                archivos = sorted(f for f in (origen / categoria).glob('*') if f.suffix.lower() in EXTENSIONES)
                if args.limite:
                    archivos = archivos[: args.limite]
                pendientes = []
                stats = {'aceptadas': 0, 'rechazadas': 0, 'ya revisadas': 0}
                for ruta in archivos:
                    previa = decisiones.get((sha1(ruta), categoria))
                    if previa:
                        stats['ya revisadas'] += 1
                        aplicar(ruta, categoria, previa['decision'] == 'aceptada', args.revisar_dataset)
                    else:
                        pendientes.append(ruta)
                print(f'\n📂 {categoria}: {len(pendientes)} por revisar ({stats["ya revisadas"]} ya revisadas)')

                vistas = {}
                for inicio in range(0, len(pendientes), LOTE):
                    if not args.revisar_dataset and contar(categoria) >= MAXIMO:
                        break
                    lote = pendientes[inicio:inicio + LOTE]
                    modelo, veredictos = consultar_lote(clave, modelos, lote, categoria)
                    for ruta, v in zip(lote, veredictos):
                        ok = aceptada(v, categoria)
                        fila = {
                            'sha1': sha1(ruta), 'ruta': str(ruta.relative_to(SCRIPT_DIR)), 'esperada': categoria,
                            'decision': 'aceptada' if ok else 'rechazada', 'categoria': v.get('categoria', ''),
                            'objeto': v.get('objeto_principal', ''), 'confianza': v.get('confianza', ''),
                            'motivo': v.get('motivo', ''), 'modelo': modelo, 'version': VERSION_CRITERIO,
                        }
                        escritor.writerow(fila)
                        decisiones[(fila['sha1'], categoria)] = fila
                        stats['aceptadas' if ok else 'rechazadas'] += 1
                        if not ok:
                            vistas[fila['categoria'] or '?'] = vistas.get(fila['categoria'] or '?', 0) + 1
                        aplicar(ruta, categoria, ok, args.revisar_dataset)
                    salida.flush()
                    print(f'  … {min(inicio + LOTE, len(pendientes))}/{len(pendientes)} · {stats["aceptadas"]} aceptadas')

                print(f'  ✅ {stats} · rechazadas vistas como: {vistas} · ahora hay {contar(categoria)} en dataset/{categoria}')
        except CuotaAgotada:
            print('\n⏸️  Todos los modelos agotaron la cuota gratis de hoy. El avance quedó guardado: '
                  'vuelve a ejecutar mañana o activa la facturación en AI Studio para seguir ya.')

    print(f'\nDecisiones en {archivo_decisiones}')


if __name__ == '__main__':
    main()
