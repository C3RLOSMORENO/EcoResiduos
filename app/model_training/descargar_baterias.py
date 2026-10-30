"""Descarga las fotos de baterías de Garbage_Classification_YOLO (Hugging Face).

Quedan en descargas_crudas/battery_hazard/ para la categoría PELIGROSO.

    python descargar_baterias.py
"""

import os
import sys
import time
import requests
from pathlib import Path
from PIL import Image
import io
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
TARGET_DIR = SCRIPT_DIR / "descargas_crudas" / "battery_hazard"
TARGET_DIR.mkdir(parents=True, exist_ok=True)

HEADERS = {'User-Agent': 'Mozilla/5.0'}

def get_battery_file_list():
    """Rutas de las fotos de la clase battery en Garbage_Classification_YOLO (Hugging Face)."""
    url = "https://huggingface.co/api/datasets/khoaliamle/Garbage_Classification_YOLO"
    r = requests.get(url, timeout=10)
    files = []
    if r.status_code == 200:
        data = r.json()
        for s in data.get('siblings', []):
            fn = s.get('rfilename', '')
            if '/battery/' in fn and fn.lower().endswith(('.jpg', '.jpeg', '.png')):
                files.append(fn)
    return files

def download_image(hf_path, idx):
    """Descarga una foto y la guarda si mide al menos 224 px. True si quedó guardada."""
    raw_url = f"https://huggingface.co/datasets/khoaliamle/Garbage_Classification_YOLO/resolve/main/{hf_path}"
    out_file = TARGET_DIR / f"hf_battery_{idx:04d}.jpg"
    if out_file.exists():
        return True
    try:
        r = requests.get(raw_url, headers=HEADERS, timeout=15)
        if r.status_code != 200:
            return False
        im = Image.open(io.BytesIO(r.content)).convert("RGB")
        w, h = im.size
        if min(w, h) < 224:
            return False
        max_dim = max(w, h)
        if max_dim > 800:
            scale = 800.0 / max_dim
            im = im.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)
        im.save(out_file, "JPEG", quality=90)
        return True
    except Exception:
        return False

def main():
    """Descarga todas las fotos de baterías a descargas_crudas/battery_hazard/."""
    print("Descargando imágenes de baterías para PELIGROSO...")
    files = get_battery_file_list()
    print(f"Total imágenes de baterías encontradas: {len(files)}")
    
    saved = 0
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {executor.submit(download_image, fn, idx): idx for idx, fn in enumerate(files)}
        for f in tqdm(as_completed(futures), total=len(futures), desc="Descargando baterías"):
            if f.result():
                saved += 1
                
    print(f"Descargadas {saved} fotos de baterías en {TARGET_DIR}")

if __name__ == "__main__":
    main()
