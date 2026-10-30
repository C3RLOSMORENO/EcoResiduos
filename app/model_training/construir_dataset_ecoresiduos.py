"""Arma dataset/ desde las fuentes descargadas en descargas_crudas/.

Vacía dataset/, descarta las fotos de baja calidad, las duplicadas y las que
ya están en dataset_prueba/, y copia hasta LIMITS fotos por categoría.
construir_dataset_v2.py hace lo mismo con más filtros y reparte cada
categoría entre fuentes.

    python construir_dataset_ecoresiduos.py
"""

import os
import sys
import shutil
import random
from pathlib import Path
from PIL import Image
import imagehash
import numpy as np
import cv2
from tqdm import tqdm

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
RAW_DIR = SCRIPT_DIR / "descargas_crudas"
TARGET_DATASET = SCRIPT_DIR / "dataset"
PRUEBA_DIR = SCRIPT_DIR / "dataset_prueba"

CATEGORIES = [
    "APROVECHABLE",
    "ORGANICO",
    "ORDINARIO",
    "PELIGROSO",
    "RAEE",
    "RCD",
    "RIESGO_BIOLOGICO",
    "FONDO"
]

LIMITS = {
    "APROVECHABLE": 650,
    "ORGANICO": 650,
    "ORDINARIO": 650,
    "PELIGROSO": 650,
    "RAEE": 650,
    "RCD": 650,
    "RIESGO_BIOLOGICO": 650,
    "FONDO": 400
}

MIN_SHORT_SIDE = 224
MAX_LONG_SIDE = 800
JPEG_QUALITY = 90
HAMMING_THRESHOLD = 6
MIN_LAPLACIAN_VAR = 35.0

def check_quality(img_path):
    """Revisa resolución, brillo y contraste.

    Devuelve ((imagen, hash perceptual), "ok") o (None, motivo del descarte).
    """
    try:
        with Image.open(img_path) as im:
            im = im.convert("RGB")
            w, h = im.size
            if min(w, h) < MIN_SHORT_SIDE:
                return None, "resolucion_baja"
                
            arr = np.array(im)
            mean_val = arr.mean()
            std_val = arr.std()
            
            # Descartar fotos casi negras o quemadas/blancas
            if mean_val < 18 or mean_val > 248 or std_val < 8:
                return None, "iluminacion_anomala"
                
            # Descartar fotos extremadamente borrosas
            gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)
            lap_var = cv2.Laplacian(gray, cv2.CV_64F).var()
            if lap_var < MIN_LAPLACIAN_VAR:
                return None, "desenfocada"
                
            max_dim = max(w, h)
            if max_dim > MAX_LONG_SIDE:
                scale = MAX_LONG_SIDE / float(max_dim)
                new_w = int(w * scale)
                new_h = int(h * scale)
                im = im.resize((new_w, new_h), Image.Resampling.LANCZOS)
                
            h_obj = imagehash.phash(im)
            return (im, h_obj), "ok"
    except Exception as e:
        return None, f"error_lectura: {e}"

def is_duplicate(candidate_hash, hash_list):
    """True si el hash está a HAMMING_THRESHOLD bits o menos de alguno de la lista."""
    for h in hash_list:
        if (candidate_hash - h) <= HAMMING_THRESHOLD:
            return True
    return False

def collect_candidate_files():
    """Candidatas de cada categoría a partir de las fuentes descargadas en descargas_crudas/."""
    candidates = {cat: [] for cat in CATEGORIES}
    
    # 1. RealWaste
    realwaste_dir = RAW_DIR / "realwaste" / "extracted" / "realwaste-main" / "RealWaste"
    if realwaste_dir.exists():
        mapping_rw = {
            "Cardboard": "APROVECHABLE",
            "Glass": "APROVECHABLE",
            "Metal": "APROVECHABLE",
            "Paper": "APROVECHABLE",
            "Plastic": "APROVECHABLE",
            "Food Organics": "ORGANICO",
            "Vegetation": "ORGANICO",
            "Miscellaneous Trash": "ORDINARIO"
        }
        for folder_name, cat in mapping_rw.items():
            fpath = realwaste_dir / folder_name
            if fpath.exists():
                for f in fpath.glob("*.*"):
                    if f.suffix.lower() in ('.jpg', '.jpeg', '.png'):
                        candidates[cat].append({
                            "path": f,
                            "fuente": "realwaste",
                            "clase_original": folder_name.lower().replace(" ", "_")
                        })
                        
    # 2. TACO
    taco_dir = RAW_DIR / "taco" / "crops"
    if taco_dir.exists():
        for cat_dir in taco_dir.iterdir():
            if cat_dir.is_dir() and cat_dir.name in candidates:
                for f in cat_dir.glob("*.jpg"):
                    candidates[cat_dir.name].append({
                        "path": f,
                        "fuente": "taco",
                        "clase_original": f.stem.split("_")[1] if len(f.stem.split("_")) > 1 else "litter"
                    })
                    
    # 3. TrashBox (Medical & E-waste)
    trashbox_dir = RAW_DIR / "trashbox"
    if trashbox_dir.exists():
        for cat_dir in trashbox_dir.iterdir():
            if cat_dir.is_dir() and cat_dir.name in candidates:
                for f in cat_dir.glob("*.jpg"):
                    parts = f.stem.split("_")
                    subclass = parts[1] if len(parts) > 1 else "item"
                    candidates[cat_dir.name].append({
                        "path": f,
                        "fuente": "trashbox",
                        "clase_original": subclass
                    })
                    
    # 4. Battery Hazard (HF)
    battery_dir = RAW_DIR / "battery_hazard"
    if battery_dir.exists():
        for f in battery_dir.glob("*.jpg"):
            candidates["PELIGROSO"].append({
                "path": f,
                "fuente": "hf_battery",
                "clase_original": "battery"
            })
            
    # 5. RCD Demolition Scrap (HF)
    rcd_hf_dir = RAW_DIR / "rcd_hf"
    if rcd_hf_dir.exists():
        for f in rcd_hf_dir.glob("*.*"):
            if f.suffix.lower() in ('.jpg', '.jpeg', '.png'):
                name_lower = f.name.lower()
                if any(bad in name_lower for bad in ["tire", "bottle", "can"]):
                    continue
                candidates["RCD"].append({
                    "path": f,
                    "fuente": "demolition_scrap",
                    "clase_original": "debris"
                })
                
    # 6. DTD (Textures: RCD y FONDO)
    dtd_dir = RAW_DIR / "dtd_extracted"
    if dtd_dir.exists():
        # RCD
        for sub in ["cracked", "potholed", "stratified", "grooved"]:
            sub_p = dtd_dir / sub
            if sub_p.exists():
                for f in sub_p.glob("*.jpg"):
                    candidates["RCD"].append({
                        "path": f,
                        "fuente": "dtd",
                        "clase_original": sub
                    })
                    
        # FONDO: pisos, mármol, madera, superficies limpias
        for sub in ["tiled", "marbled", "banded", "fibrous", "grid", "lined", "striped", "stained", "cobwebbed"]:
            sub_p = dtd_dir / sub
            if sub_p.exists():
                for f in sub_p.glob("*.jpg"):
                    candidates["FONDO"].append({
                        "path": f,
                        "fuente": "dtd",
                        "clase_original": sub
                    })
                    
    # 7. Wikimedia
    for wm_root in [RAW_DIR / "wikimedia", RAW_DIR / "wikimedia_expanded"]:
        if wm_root.exists():
            for cat_dir in wm_root.iterdir():
                if cat_dir.is_dir() and cat_dir.name in candidates:
                    for f in cat_dir.glob("*.jpg"):
                        candidates[cat_dir.name].append({
                            "path": f,
                            "fuente": "wikimedia",
                            "clase_original": cat_dir.name.lower()
                        })
                        
    return candidates

def main():
    """Vacía dataset/ y lo vuelve a armar sin duplicados ni fotos de dataset_prueba/, hasta LIMITS por categoría."""
    print("CONSTRUCCIÓN DEL DATASET FINAL DE ECORESIDUOS...")
    
    for cat in CATEGORIES:
        d = TARGET_DATASET / cat
        d.mkdir(parents=True, exist_ok=True)
        for f in d.glob("*.*"):
            f.unlink()
            
    test_hashes = []
    if PRUEBA_DIR.exists():
        for f in PRUEBA_DIR.rglob("*.*"):
            if f.suffix.lower() in ('.jpg', '.jpeg', '.png'):
                try:
                    with Image.open(f) as im:
                        test_hashes.append(imagehash.phash(im))
                except Exception:
                    pass
                    
    candidates = collect_candidate_files()
    
    stats = {
        cat: {
            "aceptadas": 0,
            "descartadas_calidad": 0,
            "descartadas_duplicado": 0,
            "por_fuente": {}
        }
        for cat in CATEGORIES
    }
    
    global_hashes = list(test_hashes)
    random.seed(42)
    
    for cat in CATEGORIES:
        items = candidates[cat]
        random.shuffle(items)
        
        target_dir = TARGET_DATASET / cat
        limit = LIMITS[cat]
        
        pbar = tqdm(items, desc=f"Procesando {cat}")
        for item in pbar:
            if stats[cat]["aceptadas"] >= limit:
                break
                
            res, reason = check_quality(item["path"])
            if res is None:
                stats[cat]["descartadas_calidad"] += 1
                continue
                
            im_processed, h_obj = res
            
            if is_duplicate(h_obj, global_hashes):
                stats[cat]["descartadas_duplicado"] += 1
                continue
                
            idx = stats[cat]["aceptadas"]
            src_name = item["fuente"]
            orig_cls = item["clase_original"]
            out_filename = f"{src_name}_{orig_cls}_{idx:04d}.jpg"
            out_path = target_dir / out_filename
            
            im_processed.save(out_path, "JPEG", quality=JPEG_QUALITY)
            
            global_hashes.append(h_obj)
            stats[cat]["aceptadas"] += 1
            stats[cat]["por_fuente"][src_name] = stats[cat]["por_fuente"].get(src_name, 0) + 1
            
        print(f"  {cat}: {stats[cat]['aceptadas']} admitidas | {stats[cat]['descartadas_calidad']} desc. calidad | {stats[cat]['descartadas_duplicado']} desc. duplicados")
        
    print("\n" + "=" * 65)
    print("RESUMEN FINAL DEL DATASET PROCESADO (app/model_training/dataset/)")
    print("=" * 65)
    total_final = 0
    for cat in CATEGORIES:
        count = stats[cat]["aceptadas"]
        total_final += count
        src_breakdown = ", ".join(f"{k}: {v}" for k, v in stats[cat]["por_fuente"].items())
        print(f"  {cat:18s}: {count:4d} fotos  [{src_breakdown}]")
    print("-" * 65)
    print(f"  TOTAL GENERAL   : {total_final:4d} imágenes")
    print("=" * 65)

if __name__ == "__main__":
    main()
