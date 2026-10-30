"""Recorta los objetos de TACO según TACO_CAT_MAPPING.

Usa las anotaciones de descargas_crudas/taco/ y guarda los recortes en crops/.

    python procesar_taco.py
"""

import os
import sys
import json
import requests
from pathlib import Path
from PIL import Image
import io
from tqdm import tqdm

SCRIPT_DIR = Path(__file__).resolve().parent
RAW_DIR = SCRIPT_DIR / "descargas_crudas" / "taco"
RAW_DIR.mkdir(parents=True, exist_ok=True)
ANNOTATIONS_PATH = RAW_DIR / "annotations.json"
CROPS_DIR = RAW_DIR / "crops"

TACO_CAT_MAPPING = {
    # Plastico / Latas / Botellas / Vidrio / Carton / Papel -> APROVECHABLE
    0: ("Aluminium foil", "APROVECHABLE"),
    4: ("Other plastic bottle", "APROVECHABLE"),
    5: ("Clear plastic bottle", "APROVECHABLE"),
    6: ("Glass bottle", "APROVECHABLE"),
    7: ("Plastic bottle cap", "APROVECHABLE"),
    8: ("Metal bottle cap", "APROVECHABLE"),
    10: ("Food Can", "APROVECHABLE"),
    12: ("Drink can", "APROVECHABLE"),
    15: ("Egg carton", "APROVECHABLE"),
    16: ("Drink carton", "APROVECHABLE"),
    17: ("Corrugated carton", "APROVECHABLE"),
    18: ("Meal carton", "APROVECHABLE"),
    19: ("Pizza box", "APROVECHABLE"),
    26: ("Glass jar", "APROVECHABLE"),
    30: ("Magazine paper", "APROVECHABLE"),
    33: ("Normal paper", "APROVECHABLE"),
    34: ("Paper bag", "APROVECHABLE"),
    40: ("Single-use carrier bag", "APROVECHABLE"),
    41: ("Polypropylene bag", "APROVECHABLE"),
    43: ("Spread tub", "APROVECHABLE"),
    44: ("Tupperware", "APROVECHABLE"),
    45: ("Disposable food container", "APROVECHABLE"),
    
    # Ordinario: Colillas, empaques metalizados de snacks, servilletas/toallas sucias, icopor sucio
    20: ("Paper cup", "ORDINARIO"),
    22: ("Foam cup", "ORDINARIO"),
    31: ("Tissues", "ORDINARIO"),
    36: ("Plastic film", "ORDINARIO"),
    42: ("Crisp packet", "ORDINARIO"),
    46: ("Foam food container", "ORDINARIO"),
    57: ("Styrofoam piece", "ORDINARIO"),
    59: ("Cigarette", "ORDINARIO"),
    
    # Peligroso
    1: ("Battery", "PELIGROSO"),
    11: ("Aerosol", "PELIGROSO"),
    
    # Organico
    25: ("Food waste", "ORGANICO"),
    
    # Riesgo Biologico
    48: ("Plastic glooves", "RIESGO_BIOLOGICO"),
}

def main():
    """Recorta los objetos de TACO según TACO_CAT_MAPPING en descargas_crudas/taco/crops/."""
    if not ANNOTATIONS_PATH.exists():
        print(f"No existe {ANNOTATIONS_PATH}")
        return
        
    with open(ANNOTATIONS_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
        
    images_dict = {img["id"]: img for img in data["images"]}
    
    # Mapear anotaciones por imagen
    img_to_anns = {}
    for ann in data["annotations"]:
        cat_id = ann["category_id"]
        if cat_id in TACO_CAT_MAPPING:
            img_id = ann["image_id"]
            if img_id not in img_to_anns:
                img_to_anns[img_id] = []
            img_to_anns[img_id].append(ann)
            
    print(f"Total de imágenes TACO con residuos mapeados: {len(img_to_anns)}")
    
    saved_counts = {}
    session = requests.Session()
    
    for img_id, anns in tqdm(img_to_anns.items(), desc="Descargando y recortando TACO"):
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
            
            # Anotaciones escaladas si la imagen descargada no coincide con width/height de metadatos
            meta_w = img_info.get("width", orig_w)
            meta_h = img_info.get("height", orig_h)
            scale_x = orig_w / meta_w
            scale_y = orig_h / meta_h
            
            for ann in anns:
                cat_id = ann["category_id"]
                orig_label, target_cat = TACO_CAT_MAPPING[cat_id]
                
                bx, by, bw, bh = ann["bbox"]
                bx *= scale_x
                by *= scale_y
                bw *= scale_x
                bh *= scale_y
                
                # Filtrar si el objeto es microscópico
                if bw < 50 or bh < 50:
                    continue
                    
                # Margen del 15%
                mx = bw * 0.15
                my = bh * 0.15
                x1 = max(0, int(bx - mx))
                y1 = max(0, int(by - my))
                x2 = min(orig_w, int(bx + bw + mx))
                y2 = min(orig_h, int(by + bh + my))
                
                crop_w = x2 - x1
                crop_h = y2 - y1
                
                if crop_w < 120 or crop_h < 120:
                    continue
                    
                crop_im = im.crop((x1, y1, x2, y2))
                
                # Redimensionar si es mayor a 800px
                max_dim = max(crop_w, crop_h)
                if max_dim > 800:
                    scale = 800.0 / max_dim
                    new_w = int(crop_w * scale)
                    new_h = int(crop_h * scale)
                    crop_im = crop_im.resize((new_w, new_h), Image.Resampling.LANCZOS)
                    
                # Guardar
                target_dir = CROPS_DIR / target_cat
                target_dir.mkdir(parents=True, exist_ok=True)
                
                cnt = saved_counts.get(target_cat, 0)
                safe_label = orig_label.replace(" ", "_").lower()
                out_path = target_dir / f"taco_{safe_label}_{cnt:04d}.jpg"
                
                crop_im.save(out_path, "JPEG", quality=90)
                saved_counts[target_cat] = cnt + 1
                
        except Exception as e:
            continue
            
    print("\nExtracción de TACO finalizada:")
    for cat, count in saved_counts.items():
        print(f"  {cat}: {count} fotos")

if __name__ == "__main__":
    main()
