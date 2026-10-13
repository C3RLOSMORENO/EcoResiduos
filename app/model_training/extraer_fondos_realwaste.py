"""Saca recortes de piso vacío de las fotos de RealWaste para la categoría FONDO.

    python extraer_fondos_realwaste.py
"""

import os
import sys
import random
from pathlib import Path
from PIL import Image
import numpy as np

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
RAW_DIR = SCRIPT_DIR / "descargas_crudas"
RW_BASE = RAW_DIR / "realwaste" / "extracted" / "realwaste-main" / "RealWaste"
OUT_DIR = RAW_DIR / "realwaste_fondos"
OUT_DIR.mkdir(parents=True, exist_ok=True)

def is_uniform_floor(im_crop):
    """True si el recorte parece el piso de concreto de RealWaste: brillo medio y poca variación."""
    arr = np.array(im_crop)
    # Piso gris de RealWaste tiene baja saturación y brillo medio
    gray = np.array(im_crop.convert("L"))
    mean_val = gray.mean()
    std_val = gray.std()
    
    # Textura de concreto típica de RealWaste: media entre 80 y 180, std moderada < 25
    if 80 < mean_val < 180 and std_val < 25:
        return True
    return False

def extract_realwaste_backgrounds(target_count=100):
    """Guarda recortes de piso vacío de RealWaste como FONDO y devuelve cuántos guardó."""
    if not RW_BASE.exists():
        print(f"No existe {RW_BASE}")
        return 0
        
    all_rw_images = list(RW_BASE.rglob("*.jpg")) + list(RW_BASE.rglob("*.png"))
    random.seed(42)
    random.shuffle(all_rw_images)
    
    saved = 0
    CROP_SIZE = 256
    
    for img_p in all_rw_images:
        if saved >= target_count:
            break
        try:
            with Image.open(img_p) as im:
                im = im.convert("RGB")
                w, h = im.size
                if w < 300 or h < 300:
                    continue
                # Las esquinas suelen ser fondo limpio en fotos centradas de RealWaste
                corners = [
                    (0, 0, CROP_SIZE, CROP_SIZE),
                    (w - CROP_SIZE, 0, w, CROP_SIZE),
                    (0, h - CROP_SIZE, CROP_SIZE, h),
                    (w - CROP_SIZE, h - CROP_SIZE, w, h),
                ]
                for box in corners:
                    crop = im.crop(box)
                    if is_uniform_floor(crop):
                        out_path = OUT_DIR / f"realwaste_fondo_{saved:04d}.jpg"
                        crop.save(out_path, "JPEG", quality=90)
                        saved += 1
                        if saved >= target_count:
                            break
        except Exception:
            continue
            
    print(f"✅ Extraídos {saved} recortes de fondo de piso limpio desde RealWaste en {OUT_DIR}")
    return saved

if __name__ == "__main__":
    extract_realwaste_backgrounds(100)
