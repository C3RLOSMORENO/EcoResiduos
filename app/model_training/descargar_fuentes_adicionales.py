"""Descarga GIZ E-Waste Database (RAEE) y Voxel51 Food Waste (ORGANICO).

Quedan en descargas_crudas/gizewaste/ y descargas_crudas/voxel51_foodwaste/.

    python descargar_fuentes_adicionales.py
"""

import os
import sys
import requests
from pathlib import Path
from PIL import Image
import io
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor, as_completed

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
RAW_DIR = SCRIPT_DIR / "descargas_crudas"
RAW_DIR.mkdir(parents=True, exist_ok=True)

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
}

def download_giz_ewaste(max_images=300):
    """Descarga una muestra repartida de GIZ E-Waste Database (CC BY 4.0) para RAEE."""
    target_dir = RAW_DIR / "gizewaste"
    target_dir.mkdir(parents=True, exist_ok=True)
    
    print("\n📦 Descargando GIZ/E-Waste-Database (CC BY 4.0)...")
    r = requests.get('https://huggingface.co/api/datasets/GIZ/E-Waste-Database', headers=HEADERS)
    if r.status_code != 200:
        print("Error al consultar API de GIZ E-Waste")
        return
        
    data = r.json()
    files = [s.get('rfilename') for s in data.get('siblings', []) if s.get('rfilename', '').lower().endswith(('.jpg', '.jpeg', '.png'))]
    print(f"Total imágenes disponibles en GIZ: {len(files)}")
    
    # Seleccionar una muestra diversa
    step = max(1, len(files) // max_images)
    selected_files = files[::step][:max_images]
    
    base_url = "https://huggingface.co/datasets/GIZ/E-Waste-Database/resolve/main/"
    
    def fetch_img(fname, idx):
        url = base_url + fname
        out_path = target_dir / f"gizewaste_item_{idx:04d}.jpg"
        if out_path.exists():
            return True
        try:
            resp = requests.get(url, headers=HEADERS, timeout=15)
            if resp.status_code == 200:
                im = Image.open(io.BytesIO(resp.content)).convert("RGB")
                w, h = im.size
                if min(w, h) < 224 or (max(w, h) / float(min(w, h))) > 2.5:
                    return False
                max_dim = max(w, h)
                if max_dim > 800:
                    scale = 800.0 / max_dim
                    new_w = int(w * scale)
                    new_h = int(h * scale)
                    im = im.resize((new_w, new_h), Image.Resampling.LANCZOS)
                im.save(out_path, "JPEG", quality=90)
                return True
        except Exception:
            pass
        return False

    saved = 0
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = [executor.submit(fetch_img, f, i) for i, f in enumerate(selected_files)]
        for f in tqdm(as_completed(futures), total=len(futures), desc="Descargando GIZ E-Waste"):
            if f.result():
                saved += 1
                
    print(f"✅ Descargadas {saved} imágenes de GIZ E-Waste en {target_dir}")

def download_voxel51_foodwaste(max_images=300):
    """Descarga una muestra de Voxel51 Food Waste (MIT) para ORGANICO."""
    target_dir = RAW_DIR / "voxel51_foodwaste"
    target_dir.mkdir(parents=True, exist_ok=True)
    
    print("\n🥗 Descargando Voxel51/food-waste-dataset (MIT)...")
    r = requests.get('https://huggingface.co/api/datasets/Voxel51/food-waste-dataset', headers=HEADERS)
    if r.status_code != 200:
        print("Error al consultar API de Voxel51")
        return
        
    data = r.json()
    files = [s.get('rfilename') for s in data.get('siblings', []) if s.get('rfilename', '').endswith('.jpg')]
    print(f"Total imágenes disponibles en Voxel51: {len(files)}")
    
    step = max(1, len(files) // max_images)
    selected_files = files[::step][:max_images]
    
    base_url = "https://huggingface.co/datasets/Voxel51/food-waste-dataset/resolve/main/"
    
    def fetch_img(fname, idx):
        url = base_url + fname
        out_path = target_dir / f"voxel51_foodwaste_{idx:04d}.jpg"
        if out_path.exists():
            return True
        try:
            resp = requests.get(url, headers=HEADERS, timeout=15)
            if resp.status_code == 200:
                im = Image.open(io.BytesIO(resp.content)).convert("RGB")
                w, h = im.size
                if min(w, h) < 224 or (max(w, h) / float(min(w, h))) > 2.5:
                    return False
                max_dim = max(w, h)
                if max_dim > 800:
                    scale = 800.0 / max_dim
                    new_w = int(w * scale)
                    new_h = int(h * scale)
                    im = im.resize((new_w, new_h), Image.Resampling.LANCZOS)
                im.save(out_path, "JPEG", quality=90)
                return True
        except Exception:
            pass
        return False

    saved = 0
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = [executor.submit(fetch_img, f, i) for i, f in enumerate(selected_files)]
        for f in tqdm(as_completed(futures), total=len(futures), desc="Descargando Voxel51 Food Waste"):
            if f.result():
                saved += 1
                
    print(f"✅ Descargadas {saved} imágenes de Voxel51 Food Waste en {target_dir}")

def main():
    """Descarga las dos fuentes a descargas_crudas/."""
    download_giz_ewaste(300)
    download_voxel51_foodwaste(300)

if __name__ == "__main__":
    main()
