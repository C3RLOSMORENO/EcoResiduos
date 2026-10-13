"""Descarga carpetas de TrashBox desde GitHub para RAEE, PELIGROSO y RIESGO_BIOLOGICO.

MAPPING indica a qué categoría va cada carpeta.

    python descargar_trashbox.py
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
RAW_DIR = SCRIPT_DIR / "descargas_crudas" / "trashbox"
RAW_DIR.mkdir(parents=True, exist_ok=True)

HEADERS = {'User-Agent': 'EcoResiduos-Researcher/1.0'}

# Mapeo de carpetas de TrashBox a nuestras categorías oficiales
MAPPING = {
    # Medical -> RIESGO_BIOLOGICO y PELIGROSO
    ("medical", "gloves"): ("RIESGO_BIOLOGICO", "trashbox_gloves"),
    ("medical", "masks"): ("RIESGO_BIOLOGICO", "trashbox_masks"),
    ("medical", "syringe"): ("RIESGO_BIOLOGICO", "trashbox_syringe"),
    ("medical", "medicines"): ("PELIGROSO", "trashbox_medicines"),
    
    # E-waste -> RAEE
    ("e-waste", "electrical cables"): ("RAEE", "trashbox_cables"),
    ("e-waste", "electronic chips"): ("RAEE", "trashbox_chips"),
    ("e-waste", "laptops"): ("RAEE", "trashbox_laptops"),
    ("e-waste", "small appliances"): ("RAEE", "trashbox_appliances"),
    ("e-waste", "smartphones"): ("RAEE", "trashbox_smartphones"),
}

def get_folder_files(parent, folder):
    """Archivos de una carpeta de TrashBox en GitHub, o [] si la API no responde."""
    encoded_folder = requests.utils.quote(folder)
    url = f"https://api.github.com/repos/nikhilvenkatkumsetty/TrashBox/contents/TrashBox_train_dataset_subfolders/{parent}/{encoded_folder}"
    try:
        r = requests.get(url, headers=HEADERS, timeout=15)
        if r.status_code == 200:
            return r.json()
    except Exception as e:
        print(f"Error listing {parent}/{folder}: {e}")
    return []

def download_and_save_image(file_info, target_path):
    """Descarga la imagen, la reduce y la guarda si mide al menos 224 px. True si quedó guardada."""
    download_url = file_info.get("download_url")
    if not download_url:
        return False
        
    try:
        r = requests.get(download_url, headers=HEADERS, timeout=15)
        if r.status_code != 200:
            return False
            
        im = Image.open(io.BytesIO(r.content)).convert("RGB")
        w, h = im.size
        
        # Validar tamaño mínimo de 224px en lado corto
        if min(w, h) < 224:
            # Redimensionar al alza manteniendo relación de aspecto si es mayor a 180px
            if min(w, h) >= 160:
                scale = 250.0 / min(w, h)
                im = im.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)
            else:
                return False
                
        # Redimensionar a máximo 800px en lado mayor
        w, h = im.size
        max_dim = max(w, h)
        if max_dim > 800:
            scale = 800.0 / max_dim
            im = im.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)
            
        im.save(target_path, "JPEG", quality=90)
        return True
    except Exception:
        return False

def main():
    """Descarga las carpetas de TrashBox listadas en MAPPING a su categoría."""
    print("🚀 DESCARGANDO DATASET TRASHBOX (Medical Waste y E-Waste)...")
    summary = {}
    
    for (parent, subfolder), (target_cat, prefix) in MAPPING.items():
        print(f"\n📂 Obteniendo lista de archivos para {parent}/{subfolder} -> {target_cat}...")
        files = get_folder_files(parent, subfolder)
        print(f"  Encontrados: {len(files)} archivos")
        
        target_dir = RAW_DIR / target_cat
        target_dir.mkdir(parents=True, exist_ok=True)
        
        saved = 0
        with ThreadPoolExecutor(max_workers=8) as executor:
            futures = {}
            for idx, f in enumerate(files):
                if f.get("type") == "file" and f.get("name", "").lower().endswith(('.jpg', '.jpeg', '.png')):
                    out_path = target_dir / f"{prefix}_{idx:04d}.jpg"
                    futures[executor.submit(download_and_save_image, f, out_path)] = out_path
                    
            for fut in tqdm(as_completed(futures), total=len(futures), desc=f"Descargando {subfolder}"):
                if fut.result():
                    saved += 1
                    
        print(f"  ✅ Guardadas: {saved} fotos en {target_cat}")
        summary[f"{target_cat} ({subfolder})"] = saved
        time.sleep(1)
        
    print("\n📊 Resumen TrashBox:")
    for k, v in summary.items():
        print(f"  {k}: {v} fotos")

if __name__ == "__main__":
    main()
