"""Recorta los objetos de TACO por categoría y agrega recortes de fondo.

Los recortes de fondo son zonas de la foto que no tocan ningún objeto
anotado y van a la categoría FONDO.

    python procesar_taco_v2.py
"""

import os
import sys
import json
import io
import random
import requests
from pathlib import Path
from PIL import Image
from tqdm import tqdm

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
RAW_DIR = SCRIPT_DIR / "descargas_crudas" / "taco"
ANNOTATIONS_PATH = RAW_DIR / "annotations.json"
CROPS_DIR = RAW_DIR / "crops_v2"
CROPS_DIR.mkdir(parents=True, exist_ok=True)

# Mapeo estricto según especificación
# Excluidos: Paper cup (20), Foam cup (22), Plastic film (36), vasos y películas ambiguas
TACO_CAT_MAPPING = {
    # APROVECHABLE
    0: ("aluminium_foil", "APROVECHABLE"),
    4: ("plastic_bottle", "APROVECHABLE"),
    5: ("clear_bottle", "APROVECHABLE"),
    6: ("glass_bottle", "APROVECHABLE"),
    7: ("plastic_cap", "APROVECHABLE"),
    8: ("metal_cap", "APROVECHABLE"),
    10: ("food_can", "APROVECHABLE"),
    12: ("drink_can", "APROVECHABLE"),
    15: ("egg_carton", "APROVECHABLE"),
    16: ("drink_carton", "APROVECHABLE"),
    17: ("corrugated_carton", "APROVECHABLE"),
    18: ("meal_carton", "APROVECHABLE"),
    19: ("pizza_box", "APROVECHABLE"),
    26: ("glass_jar", "APROVECHABLE"),
    30: ("magazine", "APROVECHABLE"),
    33: ("normal_paper", "APROVECHABLE"),
    34: ("paper_bag", "APROVECHABLE"),
    40: ("carrier_bag", "APROVECHABLE"),
    41: ("polypropylene_bag", "APROVECHABLE"),
    43: ("spread_tub", "APROVECHABLE"),
    44: ("tupperware", "APROVECHABLE"),
    45: ("food_container", "APROVECHABLE"),
    
    # ORDINARIO (Sin vasos de papel ni plastic film)
    31: ("tissues", "ORDINARIO"),
    42: ("crisp_packet", "ORDINARIO"),
    46: ("foam_container", "ORDINARIO"),
    57: ("styrofoam_piece", "ORDINARIO"),
    59: ("cigarette", "ORDINARIO"),
    
    # PELIGROSO
    1: ("battery", "PELIGROSO"),
    11: ("aerosol", "PELIGROSO"),
    
    # ORGANICO
    25: ("food_waste", "ORGANICO"),
    
    # RIESGO BIOLOGICO
    48: ("discarded_glove", "RIESGO_BIOLOGICO"),
}

def box_intersection(box1, box2):
    """Área de intersección de dos cajas (x1, y1, x2, y2); 0 si no se tocan."""
    # box: (x1, y1, x2, y2)
    ix1 = max(box1[0], box2[0])
    iy1 = max(box1[1], box2[1])
    ix2 = min(box1[2], box2[2])
    iy2 = min(box1[3], box2[3])
    if ix1 < ix2 and iy1 < iy2:
        return (ix2 - ix1) * (iy2 - iy1)
    return 0

def extract_background_crops(im, all_boxes, img_id, target_dir, max_bg_per_img=2):
    """Guarda recortes de la imagen que no tocan ningún objeto anotado, para FONDO.

    Devuelve cuántos guardó.
    """
    w, h = im.size
    bg_crops = []
    # Generar candidatos de recorte de fondo de tamaño al menos 300x300
    crop_size = min(400, min(w, h))
    if crop_size < 224:
        return 0
        
    attempts = 0
    saved = 0
    while attempts < 15 and saved < max_bg_per_img:
        attempts += 1
        rx = random.randint(0, w - crop_size)
        ry = random.randint(0, h - crop_size)
        candidate_box = (rx, ry, rx + crop_size, ry + crop_size)
        
        # Verificar que no toque NINGUNA caja anotada (margen de 20px)
        safe = True
        for b in all_boxes:
            expanded_b = (max(0, b[0] - 20), max(0, b[1] - 20), b[2] + 20, b[3] + 20)
            if box_intersection(candidate_box, expanded_b) > 0:
                safe = False
                break
                
        if safe:
            bg_im = im.crop(candidate_box)
            out_name = f"taco_fondo_{img_id}_{saved:02d}.jpg"
            bg_im.save(target_dir / out_name, "JPEG", quality=90)
            saved += 1
            
    return saved

def main():
    """Recorta los objetos de TACO por categoría y agrega recortes de fondo."""
    if not ANNOTATIONS_PATH.exists():
        print(f"No existe {ANNOTATIONS_PATH}")
        return
        
    with open(ANNOTATIONS_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
        
    images_dict = {img["id"]: img for img in data["images"]}
    
    # Agrupar TODAS las anotaciones por imagen (para fondos)
    all_img_anns = {}
    for ann in data["annotations"]:
        img_id = ann["image_id"]
        if img_id not in all_img_anns:
            all_img_anns[img_id] = []
        all_img_anns[img_id].append(ann)
        
    print(f"Total imágenes TACO con anotaciones: {len(all_img_anns)}")
    
    session = requests.Session()
    session.headers.update({"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
    
    saved_counts = {}
    bg_saved = 0
    bg_target_dir = CROPS_DIR / "FONDO"
    bg_target_dir.mkdir(parents=True, exist_ok=True)
    
    for img_id, anns in tqdm(all_img_anns.items(), desc="Procesando TACO (Crops + Fondo)"):
        img_info = images_dict.get(img_id)
        if not img_info:
            continue
            
        url = img_info.get("flickr_url") or img_info.get("flickr_640_url")
        if not url:
            continue
            
        try:
            resp = session.get(url, timeout=12)
            if resp.status_code != 200:
                continue
                
            im = Image.open(io.BytesIO(resp.content)).convert("RGB")
            orig_w, orig_h = im.size
            
            meta_w = img_info.get("width", orig_w)
            meta_h = img_info.get("height", orig_h)
            scale_x = orig_w / meta_w
            scale_y = orig_h / meta_h
            
            # Recopilar todas las cajas absolutas de esta imagen
            all_abs_boxes = []
            for ann in anns:
                bx, by, bw, bh = ann["bbox"]
                bx1 = int(bx * scale_x)
                by1 = int(by * scale_y)
                bx2 = int((bx + bw) * scale_x)
                by2 = int((by + bh) * scale_y)
                all_abs_boxes.append((bx1, by1, bx2, by2))
                
            # 1. Extraer recortes de fondo seguro si la imagen tiene espacio libre
            if bg_saved < 250:
                bg_cnt = extract_background_crops(im, all_abs_boxes, img_id, bg_target_dir, max_bg_per_img=2)
                bg_saved += bg_cnt
                
            # 2. Recortar objetos con las nuevas reglas estrictas
            for ann in anns:
                cat_id = ann["category_id"]
                if cat_id not in TACO_CAT_MAPPING:
                    continue
                    
                orig_label, target_cat = TACO_CAT_MAPPING[cat_id]
                
                bx, by, bw, bh = ann["bbox"]
                bx *= scale_x
                by *= scale_y
                bw *= scale_x
                bh *= scale_y
                
                # Descartar si el residuo es minúsculo en la escena
                if bw < 70 or bh < 70:
                    continue
                    
                # Margen del 30% alrededor del objeto
                mx = bw * 0.30
                my = bh * 0.30
                x1 = max(0, int(bx - mx))
                y1 = max(0, int(by - my))
                x2 = min(orig_w, int(bx + bw + mx))
                y2 = min(orig_h, int(by + bh + my))
                
                crop_w = x2 - x1
                crop_h = y2 - y1
                
                # Regla de calidad: Lado corto >= 224 px
                if min(crop_w, crop_h) < 224:
                    continue
                    
                # Regla de calidad: Proporción máxima 2.5:1 (Nada de tiras)
                aspect_ratio = max(crop_w, crop_h) / float(min(crop_w, crop_h))
                if aspect_ratio > 2.5:
                    continue
                    
                crop_im = im.crop((x1, y1, x2, y2))
                
                # Redimensionar a max 800px si excede
                max_dim = max(crop_w, crop_h)
                if max_dim > 800:
                    scale = 800.0 / max_dim
                    new_w = int(crop_w * scale)
                    new_h = int(crop_h * scale)
                    crop_im = crop_im.resize((new_w, new_h), Image.Resampling.LANCZOS)
                    
                target_dir = CROPS_DIR / target_cat
                target_dir.mkdir(parents=True, exist_ok=True)
                
                cnt = saved_counts.get(target_cat, 0)
                out_path = target_dir / f"taco_{orig_label}_{cnt:04d}.jpg"
                crop_im.save(out_path, "JPEG", quality=90)
                saved_counts[target_cat] = cnt + 1
                
        except Exception:
            continue
            
    print("\nExtracción de TACO v2 finalizada:")
    for cat, count in saved_counts.items():
        print(f"  {cat}: {count} recortes de residuos válidos")
    print(f"  FONDO: {bg_saved} fondos limpios extraídos")

if __name__ == "__main__":
    main()
