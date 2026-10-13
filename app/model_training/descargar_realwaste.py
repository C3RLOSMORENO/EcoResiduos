"""Descarga y extrae RealWaste (UCI Machine Learning Repository, CC BY 4.0).

Queda en descargas_crudas/realwaste/.

    python descargar_realwaste.py
"""

import os
import sys
import requests
import zipfile
from pathlib import Path
from tqdm import tqdm

SCRIPT_DIR = Path(__file__).resolve().parent
RAW_DIR = SCRIPT_DIR / "descargas_crudas" / "realwaste"
RAW_DIR.mkdir(parents=True, exist_ok=True)
ZIP_PATH = RAW_DIR / "realwaste.zip"
EXTRACT_DIR = RAW_DIR / "extracted"

URL = "https://archive.ics.uci.edu/static/public/908/realwaste.zip"

def download_file(url, target_path):
    """Descarga el archivo por partes mostrando el progreso."""
    print(f"Descargando RealWaste desde {url}...")
    headers = {'User-Agent': 'Mozilla/5.0'}
    response = requests.get(url, stream=True, headers=headers, timeout=30)
    response.raise_for_status()
    total_size = int(response.headers.get('content-length', 0))
    
    with open(target_path, 'wb') as f, tqdm(
        desc=target_path.name,
        total=total_size,
        unit='iB',
        unit_scale=True,
        unit_divisor=1024,
    ) as bar:
        for data in response.iter_content(chunk_size=1024*1024):
            size = f.write(data)
            bar.update(size)
    print("Descarga completa.")

def extract_zip(zip_path, extract_dir):
    """Extrae el .zip completo en extract_dir."""
    print(f"Extrayendo {zip_path} en {extract_dir}...")
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(extract_dir)
    print("Extracción completa.")

def main():
    """Descarga y extrae RealWaste si aún no está en descargas_crudas/realwaste/."""
    if not ZIP_PATH.exists() or ZIP_PATH.stat().st_size < 1000:
        download_file(URL, ZIP_PATH)
    else:
        print(f"El archivo zip ya existe: {ZIP_PATH} ({ZIP_PATH.stat().st_size / 1024 / 1024:.2f} MB)")
        
    if not EXTRACT_DIR.exists() or not any(EXTRACT_DIR.iterdir()):
        extract_zip(ZIP_PATH, EXTRACT_DIR)
    else:
        print(f"El directorio extraído ya existe: {EXTRACT_DIR}")

if __name__ == "__main__":
    main()
