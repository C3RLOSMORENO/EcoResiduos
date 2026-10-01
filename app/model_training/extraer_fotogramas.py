"""Convierte videos cortos de residuos en fotos para el dataset.

Graba con el celular un video de 20-30 s por objeto, girándolo y cambiando de
fondo y de luz, y guárdalo en videos/<CATEGORIA>/. Cada video aporta ~40 fotos
distintas; se descartan los fotogramas movidos y los casi repetidos.

    python extraer_fotogramas.py            # todos los videos
    python extraer_fotogramas.py --por-segundo 3
"""

import argparse
import sys
from pathlib import Path

import cv2

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
VIDEOS_DIR = SCRIPT_DIR / 'videos'
DATASET_DIR = SCRIPT_DIR / 'dataset'
EXTENSIONES = {'.mp4', '.mov', '.3gp', '.mkv', '.avi', '.webm'}

LADO_MAXIMO = 640
NITIDEZ_MINIMA = 60.0
DIFERENCIA_MINIMA = 12.0


def nitidez(gris):
    return cv2.Laplacian(gris, cv2.CV_64F).var()


def reducir(frame):
    alto, ancho = frame.shape[:2]
    escala = LADO_MAXIMO / max(alto, ancho)
    if escala >= 1:
        return frame
    return cv2.resize(frame, (int(ancho * escala), int(alto * escala)), interpolation=cv2.INTER_AREA)


def extraer(video, destino, por_segundo):
    captura = cv2.VideoCapture(str(video))
    fps = captura.get(cv2.CAP_PROP_FPS) or 30
    salto = max(1, round(fps / por_segundo))
    anterior = None
    guardadas = descartadas = indice = 0

    while True:
        ok, frame = captura.read()
        if not ok:
            break
        indice += 1
        if indice % salto:
            continue

        frame = reducir(frame)
        gris = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        miniatura = cv2.resize(gris, (32, 32))
        movido = nitidez(gris) < NITIDEZ_MINIMA
        repetido = anterior is not None and cv2.absdiff(miniatura, anterior).mean() < DIFERENCIA_MINIMA
        if movido or repetido:
            descartadas += 1
            continue

        anterior = miniatura
        cv2.imwrite(str(destino / f'{video.stem}_{indice:05d}.jpg'), frame, [cv2.IMWRITE_JPEG_QUALITY, 90])
        guardadas += 1

    captura.release()
    return guardadas, descartadas


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--por-segundo', type=float, default=2, help='fotogramas a revisar por segundo de video')
    args = parser.parse_args()

    if not VIDEOS_DIR.exists():
        print(f"❌ Crea la carpeta '{VIDEOS_DIR}' con una subcarpeta por categoría (APROVECHABLE, RAEE, ...).")
        return

    total = 0
    for carpeta in sorted(d for d in VIDEOS_DIR.iterdir() if d.is_dir()):
        destino = DATASET_DIR / carpeta.name
        destino.mkdir(parents=True, exist_ok=True)
        for video in sorted(v for v in carpeta.iterdir() if v.suffix.lower() in EXTENSIONES):
            guardadas, descartadas = extraer(video, destino, args.por_segundo)
            total += guardadas
            print(f'  {carpeta.name}/{video.name}: {guardadas} fotos ({descartadas} movidas o repetidas)')

    print(f'✅ {total} fotos nuevas en {DATASET_DIR}')


if __name__ == '__main__':
    main()
