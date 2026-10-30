"""Verifica que dataset/ cumpla los requisitos antes de entrenar.

    python verificar_dataset.py

Revisa carpetas, cantidades, mezcla de fuentes, tamaño, proporción, fotos de
catálogo sobre fondo blanco, fuentes prohibidas y duplicados (dentro de una
categoría, entre categorías y contra dataset_prueba/). Escribe el detalle en
revision/verificacion.md y termina con código 1 si algo no cumple.

El prefijo del nombre de archivo (hasta el primer «_») identifica la fuente:
realwaste_metal_0001.jpg → realwaste.
"""

import sys
from collections import Counter, defaultdict
from pathlib import Path

import imagehash
import numpy as np
from PIL import Image

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
DATASET_DIR = SCRIPT_DIR / 'dataset'
PRUEBA_DIR = SCRIPT_DIR / 'dataset_prueba'
REPORTE = SCRIPT_DIR / 'revision' / 'verificacion.md'

CATEGORIAS = {'APROVECHABLE', 'FONDO', 'ORDINARIO', 'ORGANICO', 'PELIGROSO', 'RAEE', 'RCD', 'RIESGO_BIOLOGICO'}
MINIMO = {c: 500 for c in CATEGORIAS} | {'FONDO': 300}
MAXIMO = 800
FUENTES_PROHIBIDAS = {'dtd', 'demolition'}
# Imágenes de miles de sitios distintos (búsqueda web filtrada por Gemini) o
# propias: no cuentan como una sola fuente con un estilo único.
FUENTES_DIVERSAS = {'web', 'propia'}
MAX_FUENTE_UNICA = 0.6
MIN_FUENTES = 2
MIN_LADO = 224
MAX_PROPORCION = 2.5
MAX_CATALOGO = 0.15
DISTANCIA_DUPLICADO = 6
EXTENSIONES = {'.jpg', '.jpeg', '.png', '.webp'}


def fuente(archivo):
    """Fuente de la imagen según el prefijo de su nombre (hasta el primer «_»)."""
    return archivo.stem.split('_', 1)[0].lower()


def es_catalogo(imagen):
    """Foto de producto sobre fondo blanco: casi todo el borde es blanco."""
    gris = np.asarray(imagen.convert('L').resize((96, 96)))
    borde = np.concatenate([gris[:6].ravel(), gris[-6:].ravel(), gris[:, :6].ravel(), gris[:, -6:].ravel()])
    return (borde > 235).mean() > 0.85


def imagenes(carpeta):
    """Imágenes de la carpeta con extensión admitida, en orden alfabético."""
    return sorted(f for f in carpeta.iterdir() if f.suffix.lower() in EXTENSIONES)


def main():
    """Hace todas las revisiones, escribe revision/verificacion.md y sale con 1 si hay errores."""
    if not DATASET_DIR.exists():
        print(f"No existe '{DATASET_DIR}'.")
        sys.exit(1)

    errores, avisos, lineas = [], [], ['# Verificación del dataset', '']
    carpetas = sorted(d for d in DATASET_DIR.iterdir() if d.is_dir())

    for d in carpetas:
        if d.name not in CATEGORIAS:
            errores.append(f'Carpeta no válida: {d.name}')
    for c in sorted(CATEGORIAS - {d.name for d in carpetas}):
        errores.append(f'Falta la carpeta {c}')

    hashes = []
    lineas += ['| Categoría | Total | Fuentes | Fuente mayor | Catálogo | Pequeñas | Alargadas |', '|---|---|---|---|---|---|---|']

    for d in carpetas:
        if d.name not in CATEGORIAS:
            continue
        archivos = imagenes(d)
        total = len(archivos)
        fuentes = Counter(fuente(f) for f in archivos)
        catalogo, pequenas, alargadas = [], [], []

        for f in archivos:
            try:
                with Image.open(f) as im:
                    im = im.convert('RGB')
                    ancho, alto = im.size
                    if min(ancho, alto) < MIN_LADO:
                        pequenas.append(f.name)
                    if max(ancho, alto) / min(ancho, alto) > MAX_PROPORCION:
                        alargadas.append(f.name)
                    if es_catalogo(im):
                        catalogo.append(f.name)
                    hashes.append((imagehash.phash(im), d.name, f.name))
            except Exception as e:
                errores.append(f'{d.name}/{f.name} no se puede abrir: {e}')

        unicas = Counter({k: v for k, v in fuentes.items() if k not in FUENTES_DIVERSAS})
        mayor, n_mayor = unicas.most_common(1)[0] if unicas else ('-', 0)
        cuota = n_mayor / total if total else 0
        lineas.append(
            f'| {d.name} | {total} | {dict(fuentes.most_common())} | {mayor} {cuota:.0%} | '
            f'{len(catalogo)} ({len(catalogo) / max(total, 1):.0%}) | {len(pequenas)} | {len(alargadas)} |'
        )

        if total < MINIMO[d.name]:
            avisos.append(f'{d.name}: {total} imágenes, faltan {MINIMO[d.name] - total} para el mínimo de {MINIMO[d.name]}')
        if total > MAXIMO:
            errores.append(f'{d.name}: {total} imágenes, supera el máximo de {MAXIMO}')
        prohibidas = {k: v for k, v in fuentes.items() if k in FUENTES_PROHIBIDAS}
        if prohibidas:
            errores.append(f'{d.name}: fuentes prohibidas {prohibidas}')
        if total and cuota > MAX_FUENTE_UNICA:
            errores.append(f'{d.name}: la fuente «{mayor}» aporta el {cuota:.0%} (máximo {MAX_FUENTE_UNICA:.0%})')
        if len(fuentes) < MIN_FUENTES and not set(fuentes) & FUENTES_DIVERSAS:
            errores.append(f'{d.name}: solo {len(fuentes)} fuente(s), mínimo {MIN_FUENTES}')
        if total and len(catalogo) / total > MAX_CATALOGO:
            errores.append(f'{d.name}: {len(catalogo)} fotos de catálogo con fondo blanco ({len(catalogo) / total:.0%}, máximo {MAX_CATALOGO:.0%})')
        if pequenas:
            errores.append(f'{d.name}: {len(pequenas)} imágenes con lado corto < {MIN_LADO}px, ej. {pequenas[:3]}')
        if alargadas:
            errores.append(f'{d.name}: {len(alargadas)} recortes demasiado alargados (> {MAX_PROPORCION}:1), ej. {alargadas[:3]}')
        if catalogo:
            lineas.append(f'  - Catálogo en {d.name}: {", ".join(catalogo[:40])}{" …" if len(catalogo) > 40 else ""}')

    duplicados = defaultdict(list)
    bits = np.array([h.hash.ravel() for h, _, _ in hashes], dtype=bool)
    for i in range(len(hashes) - 1):
        distancias = (bits[i + 1:] != bits[i]).sum(axis=1)
        for j in np.nonzero(distancias <= DISTANCIA_DUPLICADO)[0] + i + 1:
            _, cat, nombre = hashes[i]
            _, cat2, nombre2 = hashes[j]
            clave = 'entre categorías' if cat != cat2 else 'misma categoría'
            duplicados[clave].append(f'{cat}/{nombre} ↔ {cat2}/{nombre2}')

    for clave, pares in duplicados.items():
        errores.append(f'{len(pares)} duplicados ({clave}), ej. {pares[:3]}')
        lineas += ['', f'## Duplicados ({clave})', *[f'- {p}' for p in pares[:200]]]

    if PRUEBA_DIR.exists():
        fugas = []
        for f in (p for p in PRUEBA_DIR.rglob('*') if p.suffix.lower() in EXTENSIONES):
            with Image.open(f) as im:
                hp = imagehash.phash(im.convert('RGB'))
            fugas += [f'{f.name} ↔ {cat}/{nombre}' for h, cat, nombre in hashes if hp - h <= DISTANCIA_DUPLICADO]
        if fugas:
            errores.append(f'{len(fugas)} fotos de dataset_prueba repetidas en dataset, ej. {fugas[:3]}')
    else:
        avisos.append('No existe dataset_prueba/: no hay forma de medir el modelo con fotos reales propias')

    lineas += ['', '## Errores', *([f'- {e}' for e in errores] or ['- Ninguno'])]
    lineas += ['', '## Avisos', *([f'- {a}' for a in avisos] or ['- Ninguno'])]
    REPORTE.parent.mkdir(exist_ok=True)
    REPORTE.write_text('\n'.join(lineas) + '\n', encoding='utf-8')

    print('\n'.join(lineas))
    print(f'\nDetalle en {REPORTE}')
    if errores:
        print(f'\nEl dataset NO cumple: {len(errores)} error(es).')
        sys.exit(1)
    print('\nEl dataset cumple los requisitos verificables. Falta la revisión visual y la auditoría con Gemini.')


if __name__ == '__main__':
    main()
