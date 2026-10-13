"""Recorta de Open Images los objetos de las clases de OI_CLASSES.

Usa las anotaciones que descargó procesar_openimages.py y guarda los recortes
en descargas_crudas/openimages/crops_v2/.

    python procesar_openimages_v2.py
"""

import os
import sys
import csv
import io
import requests
from pathlib import Path
from PIL import Image
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
RAW_DIR = SCRIPT_DIR / "descargas_crudas" / "openimages"
RAW_DIR.mkdir(parents=True, exist_ok=True)
CROPS_DIR = RAW_DIR / "crops_v2"
CROPS_DIR.mkdir(parents=True, exist_ok=True)

OI_CLASSES = {
    # RAEE
    "/m/050k8": ("mobile_phone", "RAEE"),
    "/m/01c648": ("laptop", "RAEE"),
    "/m/01m2v": ("keyboard", "RAEE"),
    "/m/020lf": ("mouse", "RAEE"),
    "/m/07c52": ("television", "RAEE"),
    "/m/0qjjc": ("remote_control", "RAEE"),
    "/m/01b7fy": ("headphones", "RAEE"),
    "/m/0bh9flk": ("tablet", "RAEE"),
    "/m/0h8lkj8": ("corded_phone", "RAEE"),
    "/m/0dv5r": ("camera", "RAEE"),
    
    # ORGANICO
    "/m/014j1m": ("apple", "ORGANICO"),
    "/m/09qck": ("banana", "ORGANICO"),
    "/m/0cyhj_": ("orange", "ORGANICO"),
    "/m/033cnk": ("egg", "ORGANICO"),
    "/m/09728": ("bread", "ORGANICO"),
    "/m/0fp6w": ("pineapple", "ORGANICO"),
    "/m/0f4s2w": ("vegetable", "ORGANICO"),
    
    # APROVECHABLE
    "/m/04dr76w": ("bottle", "APROVECHABLE"),
    "/m/02jnhm": ("tin_can", "APROVECHABLE"),
    
    # PELIGROSO
    "/m/0h8l4fh": ("light_bulb", "PELIGROSO"),
    
    # RIESGO_BIOLOGICO
    "/m/012ysf": ("syringe", "RIESGO_BIOLOGICO"),
    "/m/0174n1": ("glove", "RIESGO_BIOLOGICO"),
    
    # RCD
    "/m/0199g": ("brick", "RCD"),
}

MAX_PER_SUBCLASS = 120

def main():
    """Recorta los objetos de las clases de interés de Open Images en descargas_crudas/openimages/crops_v2/."""
    bbox_file = RAW_DIR / "validation-annotations-bbox.csv"
    img_file = RAW_DIR / "validation-images-with-rotation.csv"
    
    if not bbox_file.exists() or not img_file.exists():
        print("Faltan archivos de metadatos de OpenImages en descargas_crudas/openimages")
        return
        
    print("Leyendo metadatos de imágenes de OpenImages...")
    image_urls = {}
    with open(img_file, "r", encoding="utf-8", errors="ignore") as f:
        reader = csv.DictReader(f)
        for row in reader:
            img_id = row.get("ImageID")
            url = row.get("OriginalURL")
            if img_id and url:
                image_urls[img_id] = url
                
    print(f"Total imágenes en catálogo: {len(image_urls)}")
    
    # Agrupar bboxes de interés
    target_bboxes = {}
    with open(bbox_file, "r", encoding="utf-8", errors="ignore") as f:
        reader = csv.DictReader(f)
        for row in reader:
            label = row.get("LabelName")
            if label in OI_CLASSES:
                img_id = row.get("ImageID")
                if img_id in image_urls:
                    if label not in target_bboxes:
                        target_bboxes[label] = []
                    target_bboxes[label].append(row)
                    
    for label, bboxes in target_bboxes.items():
        subname, cat = OI_CLASSES[label]
        print(f"  {subname} ({cat}): {len(bboxes)} detecciones")
        
    session = requests.Session()
    session.headers.update({"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
    
    saved_counts = {}
    
    for label, bboxes in target_bboxes.items():
        subname, cat = OI_CLASSES[label]
        target_dir = CROPS_DIR / cat
        target_dir.mkdir(parents=True, exist_ok=True)
        
        count = 0
        pbar = tqdm(bboxes, desc=f"Descargando OI -> {cat}/{subname}")
        for row in pbar:
            if count >= MAX_PER_SUBCLASS:
                break
                
            img_id = row["ImageID"]
            url = image_urls.get(img_id)
            if not url:
                continue
                
            try:
                xmin = float(row["XMin"])
                xmax = float(row["XMax"])
                ymin = float(row["YMin"])
                ymax = float(row["YMax"])
                
                bw_norm = xmax - xmin
                bh_norm = ymax - ymin
                
                # Descartar si el objeto es microscópico
                if (bw_norm * bh_norm) < 0.03:
                    continue
                    
                resp = session.get(url, timeout=10)
                if resp.status_code != 200:
                    continue
                    
                im = Image.open(io.BytesIO(resp.content)).convert("RGB")
                w, h = im.size
                
                bx1 = int(xmin * w)
                bx2 = int(xmax * w)
                by1 = int(ymin * h)
                by2 = int(ymax * h)
                
                bw = bx2 - bx1
                bh = by2 - by1
                
                # Margen del 20%
                mx = int(bw * 0.20)
                my = int(bh * 0.20)
                
                crop_x1 = max(0, bx1 - mx)
                crop_y1 = max(0, by1 - my)
                crop_x2 = min(w, bx2 + mx)
                crop_y2 = min(h, by2 + my)
                
                crop_w = crop_x2 - crop_x1
                crop_h = crop_y2 - crop_y1
                
                # Regla de calidad: Lado corto >= 224 px
                if min(crop_w, crop_h) < 224:
                    continue
                    
                # Regla de calidad: Proporción máxima <= 2.5:1
                if (max(crop_w, crop_h) / float(min(crop_w, crop_h))) > 2.5:
                    continue
                    
                crop_im = im.crop((crop_x1, crop_y1, crop_x2, crop_y2))
                
                # Redimensionar a max 800 px si es mayor
                max_dim = max(crop_w, crop_h)
                if max_dim > 800:
                    scale = 800.0 / max_dim
                    new_w = int(crop_w * scale)
                    new_h = int(crop_h * scale)
                    crop_im = crop_im.resize((new_w, new_h), Image.Resampling.LANCZOS)
                    
                out_name = f"openimages_{subname}_{count:04d}.jpg"
                crop_im.save(target_dir / out_name, "JPEG", quality=90)
                count += 1
                saved_counts[cat] = saved_counts.get(cat, 0) + 1
            except Exception:
                continue
                
    print("\n✅ Resumen Open Images v2 procesado:")
    for cat, total in saved_counts.items():
        print(f"  {cat}: {total} fotos")

if __name__ == "__main__":
    main()
