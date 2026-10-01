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
from collections import defaultdict, Counter

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

MIN_LADO = 224
MAX_PROPORCION = 2.5
MAX_LONG_SIDE = 800
JPEG_QUALITY = 90
HAMMING_THRESHOLD = 6
MIN_LAPLACIAN_VAR = 35.0
MAX_FUENTE_UNICA = 0.58  # Máximo 58% para estar cómodamente bajo el 60%

def es_catalogo(imagen):
    """Foto de producto sobre fondo blanco: casi todo el borde es blanco."""
    gris = np.asarray(imagen.convert('L').resize((96, 96)))
    borde = np.concatenate([gris[:6].ravel(), gris[-6:].ravel(), gris[:, :6].ravel(), gris[:, -6:].ravel()])
    return (borde > 235).mean() > 0.85

def has_excessive_text(arr):
    # Detección simple de infografías con mucho contraste y bordes rectos binarios
    gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)
    # Si más del 20% de la imagen es texto blanco sobre negro o negro sobre blanco puro
    white_pct = (gray > 250).mean()
    black_pct = (gray < 5).mean()
    if white_pct > 0.40 and black_pct > 0.15:
        return True
    return False

def check_image_quality(img_path, allow_catalog=False):
    try:
        with Image.open(img_path) as im:
            im = im.convert("RGB")
            w, h = im.size
            if min(w, h) < MIN_LADO:
                return None, "lado_corto_menor_224"
            if (max(w, h) / float(min(w, h))) > MAX_PROPORCION:
                return None, "proporcion_excesiva"
                
            if not allow_catalog and es_catalogo(im):
                return None, "catalogo_fondo_blanco"
                
            arr = np.array(im)
            mean_val = arr.mean()
            std_val = arr.std()
            
            if mean_val < 18 or mean_val > 248 or std_val < 8:
                return None, "iluminacion_anomala"
                
            gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)
            lap_var = cv2.Laplacian(gray, cv2.CV_64F).var()
            if lap_var < MIN_LAPLACIAN_VAR:
                return None, "desenfocada"
                
            if has_excessive_text(arr):
                return None, "texto_infografia"
                
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
    for h in hash_list:
        if (candidate_hash - h) <= HAMMING_THRESHOLD:
            return True
    return False

def collect_candidates():
    candidates = defaultdict(lambda: defaultdict(list))
    
    # 1. RealWaste (Limpio)
    rw_dir = RAW_DIR / "realwaste" / "extracted" / "realwaste-main" / "RealWaste"
    if rw_dir.exists():
        # APROVECHABLE
        for sub in ["Cardboard", "Glass", "Paper", "Plastic"]:
            p = rw_dir / sub
            if p.exists():
                for f in p.glob("*.*"):
                    candidates["APROVECHABLE"]["realwaste"].append({
                        "path": f, "subclass": sub.lower()
                    })
        # Metal en RealWaste: separar aerosoles hacia PELIGROSO y excluir blísteres
        p_metal = rw_dir / "Metal"
        if p_metal.exists():
            for f in p_metal.glob("*.*"):
                name_l = f.name.lower()
                # Si es aerosol o similar, va a PELIGROSO
                if any(x in name_l for x in ["spray", "aerosol", "canister"]):
                    candidates["PELIGROSO"]["realwaste"].append({
                        "path": f, "subclass": "aerosol"
                    })
                elif any(x in name_l for x in ["blister", "pill", "medicine"]):
                    # Excluir blísteres
                    continue
                else:
                    candidates["APROVECHABLE"]["realwaste"].append({
                        "path": f, "subclass": "metal"
                    })
                    
        # ORGANICO
        for sub in ["Food Organics", "Vegetation"]:
            p = rw_dir / sub
            if p.exists():
                for f in p.glob("*.*"):
                    candidates["ORGANICO"]["realwaste"].append({
                        "path": f, "subclass": sub.lower().replace(" ", "_")
                    })
                    
        # ORDINARIO
        p_ord = rw_dir / "Miscellaneous Trash"
        if p_ord.exists():
            for f in p_ord.glob("*.*"):
                candidates["ORDINARIO"]["realwaste"].append({
                    "path": f, "subclass": "misc_trash"
                })
                
    # 2. RealWaste Fondos de Piso
    rw_fondos = RAW_DIR / "realwaste_fondos"
    if rw_fondos.exists():
        for f in rw_fondos.glob("*.jpg"):
            candidates["FONDO"]["realwaste"].append({
                "path": f, "subclass": "floor"
            })
            
    # 3. TACO v2 (Crops limpios)
    taco_crops_dir = RAW_DIR / "taco" / "crops_v2"
    if taco_crops_dir.exists():
        for cat_dir in taco_crops_dir.iterdir():
            if cat_dir.is_dir() and cat_dir.name in CATEGORIES:
                for f in cat_dir.glob("*.jpg"):
                    sub = f.stem.split("_")[1] if len(f.stem.split("_")) > 1 else "item"
                    candidates[cat_dir.name]["taco"].append({
                        "path": f, "subclass": sub
                    })
                    
    # 4. Voxel51 Food Waste (MIT)
    v51_dir = RAW_DIR / "voxel51_foodwaste"
    if v51_dir.exists():
        for f in v51_dir.glob("*.jpg"):
            candidates["ORGANICO"]["voxel51"].append({
                "path": f, "subclass": "food_waste"
            })
            
    # 5. GIZ E-Waste (CC BY 4.0)
    giz_dir = RAW_DIR / "gizewaste"
    if giz_dir.exists():
        for f in giz_dir.glob("*.jpg"):
            candidates["RAEE"]["gizewaste"].append({
                "path": f, "subclass": "electronics"
            })
            
    # 6. OpenImages v2
    oi_dir = RAW_DIR / "openimages" / "crops_v2"
    if oi_dir.exists():
        for cat_dir in oi_dir.iterdir():
            if cat_dir.is_dir() and cat_dir.name in CATEGORIES:
                for f in cat_dir.glob("*.jpg"):
                    sub = f.stem.split("_")[1] if len(f.stem.split("_")) > 1 else "item"
                    candidates[cat_dir.name]["openimages"].append({
                        "path": f, "subclass": sub
                    })
                    
    # 7. Wikimedia Commons (v2 + bases)
    for wm_root in [RAW_DIR / "wikimedia_v2", RAW_DIR / "wikimedia", RAW_DIR / "wikimedia_expanded"]:
        if wm_root.exists():
            for cat_dir in wm_root.iterdir():
                if cat_dir.is_dir() and cat_dir.name in CATEGORIES:
                    for f in cat_dir.glob("*.jpg"):
                        sub = f.stem.split("_")[1] if len(f.stem.split("_")) > 1 else "item"
                        candidates[cat_dir.name]["wikimedia"].append({
                            "path": f, "subclass": sub
                        })
                        
    # 8. TrashBox (Filtrado estricto)
    tb_dir = RAW_DIR / "trashbox"
    if tb_dir.exists():
        # RAEE
        if (tb_dir / "RAEE").exists():
            for f in (tb_dir / "RAEE").glob("*.jpg"):
                candidates["RAEE"]["trashbox"].append({
                    "path": f, "subclass": "ewaste"
                })
        # RIESGO_BIOLOGICO
        if (tb_dir / "RIESGO_BIOLOGICO").exists():
            for f in (tb_dir / "RIESGO_BIOLOGICO").glob("*.jpg"):
                candidates["RIESGO_BIOLOGICO"]["trashbox"].append({
                    "path": f, "subclass": "medical"
                })
        # PELIGROSO (Máximo medicamentos)
        if (tb_dir / "PELIGROSO").exists():
            med_count = 0
            for f in (tb_dir / "PELIGROSO").glob("*.jpg"):
                name_l = f.name.lower()
                if "medicine" in name_l or "pill" in name_l or "tablet" in name_l:
                    if med_count < 120:
                        candidates["PELIGROSO"]["trashbox"].append({
                            "path": f, "subclass": "medicine"
                        })
                        med_count += 1
                else:
                    candidates["PELIGROSO"]["trashbox"].append({
                        "path": f, "subclass": "hazard"
                    })

    # 9. Unsplash / Pexels
    for ps_root in [RAW_DIR / "pexels", RAW_DIR / "unsplash"]:
        if ps_root.exists():
            for cat_dir in ps_root.iterdir():
                if cat_dir.is_dir() and cat_dir.name in CATEGORIES:
                    for f in cat_dir.glob("*.jpg"):
                        sub = f.stem.split("_")[1] if len(f.stem.split("_")) > 1 else "item"
                        candidates[cat_dir.name]["unsplash"].append({
                            "path": f, "subclass": sub
                        })
                    
    return candidates

def assemble_balanced_dataset():
    print("🚀 ENSAMBLANDO DATASET V2 CON REGLAS ESTRICTAS...")
    
    # Limpiar dataset previo
    for cat in CATEGORIES:
        d = TARGET_DATASET / cat
        d.mkdir(parents=True, exist_ok=True)
        for f in d.glob("*.*"):
            f.unlink()
            
    test_hashes = []
    if PRUEBA_DIR.exists():
        for f in PRUEBA_DIR.rglob("*.*"):
            if f.suffix.lower() in ('.jpg', '.jpeg', '.png', '.webp'):
                try:
                    with Image.open(f) as im:
                        test_hashes.append(imagehash.phash(im))
                except Exception:
                    pass
                    
    candidates = collect_candidates()
    
    global_hashes = list(test_hashes)
    random.seed(42)
    
    final_stats = {}
    
    for cat in CATEGORIES:
        cat_sources = candidates[cat]
        target_dir = TARGET_DATASET / cat
        
        print(f"\n📂 Procesando categoría: {cat}")
        for sname, flist in cat_sources.items():
            print(f"   Fuente '{sname}': {len(flist)} candidatos")
            
        accepted_files = []
        source_counts = Counter()
        
        # Mezclar candidatos por fuente
        for sname in cat_sources:
            random.shuffle(cat_sources[sname])
            
        # Determinar límite total razonable para la categoría
        # Si hay pocas fuentes, limitamos para respetar la regla del 60%
        # Para RCD o RIESGO_BIOLOGICO, si una fuente tiene pocas fotos, calculamos el máximo balanceado
        total_available = sum(len(flist) for flist in cat_sources.values())
        
        # Intercalar fuentes equitativamente en rondas
        round_idx = 0
        still_adding = True
        
        while still_adding:
            added_in_round = 0
            for sname, items in cat_sources.items():
                if round_idx < len(items):
                    item = items[round_idx]
                    
                    # Verificar si agregar de esta fuente violaría el 60%
                    curr_total = len(accepted_files)
                    if curr_total >= 10:
                        if (source_counts[sname] + 1) / float(curr_total + 1) > MAX_FUENTE_UNICA:
                            continue
                            
                    res, reason = check_image_quality(item["path"], allow_catalog=False)
                    if res is None:
                        continue
                        
                    im_proc, h_obj = res
                    if is_duplicate(h_obj, global_hashes):
                        continue
                        
                    out_idx = len(accepted_files)
                    sub = item["subclass"]
                    out_name = f"{sname}_{sub}_{out_idx:04d}.jpg"
                    out_path = target_dir / out_name
                    
                    im_proc.save(out_path, "JPEG", quality=JPEG_QUALITY)
                    global_hashes.append(h_obj)
                    accepted_files.append(out_name)
                    source_counts[sname] += 1
                    added_in_round += 1
                    
                    if len(accepted_files) >= 650:
                        still_adding = False
                        break
                        
            round_idx += 1
            if added_in_round == 0:
                # Si dimos 15 vueltas sin agregar, paramos
                if round_idx > max(len(items) for items in cat_sources.values()) if cat_sources else 0:
                    break
                    
        final_stats[cat] = {
            "total": len(accepted_files),
            "fuentes": dict(source_counts)
        }
        print(f"  ✅ {cat}: {len(accepted_files)} fotos admitidas -> {dict(source_counts)}")
        
    print("\n" + "=" * 65)
    print("📊 RESUMEN FINAL DATASET V2")
    print("=" * 65)
    for cat, info in final_stats.items():
        print(f"  📁 {cat:18s}: {info['total']:4d} fotos | {info['fuentes']}")
    print("=" * 65)

if __name__ == "__main__":
    assemble_balanced_dataset()
