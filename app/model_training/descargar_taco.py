"""Descarga TACO (Trash Annotations in Context) y recorta sus objetos por categoría.

    python descargar_taco.py
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
IMAGES_DIR = RAW_DIR / "images"
IMAGES_DIR.mkdir(parents=True, exist_ok=True)

ANNOTATIONS_URL = "https://raw.githubusercontent.com/pedropro/TACO/master/data/annotations.json"

# Mapeo oficial de supercategorías y categorías TACO a nuestras clases:
# APROVECHABLE, ORGANICO, ORDINARIO, PELIGROSO, RAEE, RCD, RIESGO_BIOLOGICO
TACO_CAT_MAPPING = {
    # Plastico / Latas / Botellas / Vidrio / Carton / Papel -> APROVECHABLE
    "Aluminium foil": "APROVECHABLE",
    "Clear plastic bottle": "APROVECHABLE",
    "Other plastic bottle": "APROVECHABLE",
    "Plastic bottle cap": "APROVECHABLE",
    "Metal bottle cap": "APROVECHABLE",
    "Drink can": "APROVECHABLE",
    "Food can": "APROVECHABLE",
    "Drink carton": "APROVECHABLE", # Tetra pak
    "Glass bottle": "APROVECHABLE",
    "Glass cup": "APROVECHABLE",
    "Glass jar": "APROVECHABLE",
    "Other glass": "APROVECHABLE",
    "Plastic lid": "APROVECHABLE",
    "Corrugated carton": "APROVECHABLE",
    "Egg carton": "APROVECHABLE",
    "Magazine paper": "APROVECHABLE",
    "Normal paper": "APROVECHABLE",
    "Paper bag": "APROVECHABLE",
    "Plastified paper bag": "APROVECHABLE",
    "Spread tub": "APROVECHABLE",
    "Tupperware": "APROVECHABLE",
    "Disposable food container": "APROVECHABLE",
    "Plastic glooves": "RIESGO_BIOLOGICO", # Guantes desechados en calle -> RIESGO_BIOLOGICO
    "Single-use carrier bag": "APROVECHABLE",
    "Polypropylene bag": "APROVECHABLE",
    
    # Ordinario: Colillas, empaques metalizados de snacks, servilletas/toallas sucias, icopor sucio
    "Cigarette": "ORDINARIO",
    "Crisp packet": "ORDINARIO", # empaques metalizados de papas/snacks
    "Paper cup": "ORDINARIO", # vasos de cafe de un solo uso / encerados
    "Styrofoam piece": "ORDINARIO",
    "Foam cup": "ORDINARIO",
    "Foam food container": "ORDINARIO",
    "Plastic film": "ORDINARIO", # si esta sucio/arrugado o envoltorio de snack
    
    # Peligroso
    "Battery": "PELIGROSO",
    "Aerosol": "PELIGROSO",
    
    # Organico
    "Food waste": "ORGANICO",
    
    # Casos a ignorar explicitamente: Broken glass pequeño ambiguo, Unlabeled litter, Rope & strings, Shoe (excluir ropa/zapatos)
}

def download_annotations():
    """Descarga las anotaciones de TACO si aún no están."""
    if not ANNOTATIONS_PATH.exists():
        print("Descargando annotations.json de TACO...")
        r = requests.get(ANNOTATIONS_URL, timeout=30)
        r.raise_for_status()
        with open(ANNOTATIONS_PATH, "wb") as f:
            f.write(r.content)
        print("annotations.json descargado.")

def download_and_crop_taco(max_per_category=200):
    """Recorta cada objeto anotado de TACO y lo guarda en la categoría de TACO_CAT_MAPPING."""
    download_annotations()
    with open(ANNOTATIONS_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
        
    categories = {c["id"]: c["name"] for c in data["categories"]}
    images = {img["id"]: img for img in data["images"]}
    
    # Agrupar anotaciones por categoría mapeada
    cat_annotations = {}
    for ann in data["annotations"]:
        cat_name = categories.get(ann["category_id"])
        target_cat = TACO_CAT_MAPPING.get(cat_name)
        if not target_cat:
            continue
        if target_cat not in cat_annotations:
            cat_annotations[target_cat] = []
        cat_annotations[target_cat].append(ann)
        
    print(f"Anotaciones TACO encontradas por categoría:")
    for c, anns in cat_annotations.items():
        print(f"  {c}: {len(anns)} anotaciones")
        
    # Descargar imágenes y recortar anotaciones
    base_url = "https://raw.githubusercontent.com/pedropro/TACO/master/data/"
    
    # Cache de imágenes descargadas en memoria o disco
    downloaded_images = {}
    
    saved_count = {c: 0 for c in cat_annotations}
    
    for target_cat, anns in cat_annotations.items():
        target_dir = RAW_DIR / "crops" / target_cat
        target_dir.mkdir(parents=True, exist_ok=True)
        
        for ann in tqdm(anns, desc=f"Procesando TACO -> {target_cat}"):
            if saved_count[target_cat] >= max_per_category:
                break
                
            img_info = images.get(ann["image_id"])
            if not img_info:
                continue
                
            file_path = img_info["file_name"]
            img_local_path = IMAGES_DIR / Path(file_path).name
            
            # Descargar imagen completa si no existe
            if not img_local_path.exists():
                img_url = base_url + file_path
                try:
                    r = requests.get(img_url, timeout=15)
                    if r.status_code == 200:
                        with open(img_local_path, "wb") as f:
                            f.write(r.content)
                    else:
                        continue
                except Exception:
                    continue
                    
            # Cargar imagen y recortar bbox con margen 15%
            try:
                with Image.open(img_local_path) as im:
                    im = im.convert("RGB")
                    w, h = im.size
                    bbox = ann["bbox"] # [x, y, width, height]
                    bx, by, bw, bh = bbox
                    
                    # Si el bbox es extremadamente pequeño (< 100 px), saltar
                    if bw < 40 or bh < 40:
                        continue
                        
                    # Margen del 15%
                    margin_x = bw * 0.15
                    margin_y = bh * 0.15
                    
                    x1 = max(0, int(bx - margin_x))
                    y1 = max(0, int(by - margin_y))
                    x2 = min(w, int(bx + bw + margin_x))
                    y2 = min(h, int(by + bh + margin_y))
                    
                    crop_w = x2 - x1
                    crop_h = y2 - y1
                    
                    # Lado corto debe ser al menos 150px para el recorte antes del resize
                    if crop_w < 100 or crop_h < 100:
                        continue
                        
                    cropped = im.crop((x1, y1, x2, y2))
                    
                    # Guardar recorte
                    cat_orig_name = categories.get(ann["category_id"], "waste").replace(" ", "_").lower()
                    out_filename = f"taco_{cat_orig_name}_{saved_count[target_cat]:04d}.jpg"
                    cropped.save(target_dir / out_filename, "JPEG", quality=90)
                    saved_count[target_cat] += 1
            except Exception as e:
                pass
                
    print("\nResumen TACO extraído:")
    for c, cnt in saved_count.items():
        print(f"  {c}: {cnt} fotos")

if __name__ == "__main__":
    download_and_crop_taco()
