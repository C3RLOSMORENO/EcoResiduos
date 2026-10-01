import os
import sys
import csv
import io
import requests
from pathlib import Path
from PIL import Image
from tqdm import tqdm

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
RAW_DIR = SCRIPT_DIR / "descargas_crudas" / "openimages"
RAW_DIR.mkdir(parents=True, exist_ok=True)
CROPS_DIR = RAW_DIR / "crops"
CROPS_DIR.mkdir(parents=True, exist_ok=True)

# Mapeo de ClassID en Open Images V7 a nuestra Categoría y Subclase
# Clases útiles:
# Syringe: /m/012ysf -> RIESGO_BIOLOGICO
# Glove: /m/0174n1 -> RIESGO_BIOLOGICO
# Light bulb: /m/0h8l4fh -> PELIGROSO
# Mobile phone: /m/050k8 -> RAEE
# Laptop: /m/01c648 -> RAEE
# Computer keyboard: /m/01m2v -> RAEE
# Computer mouse: /m/020lf -> RAEE
# Television: /m/07c52 -> RAEE
# Camera: /m/0dv5r -> RAEE
# Banana: /m/09qck -> ORGANICO
# Apple: /m/014j1m -> ORGANICO
# Orange: /m/0cyhj_ -> ORGANICO
# Egg: /m/033cnk -> ORGANICO

OI_CLASSES = {
    "/m/012ysf": ("syringe", "RIESGO_BIOLOGICO"),
    "/m/0174n1": ("glove", "RIESGO_BIOLOGICO"),
    "/m/0h8l4fh": ("light_bulb", "PELIGROSO"),
    "/m/050k8": ("mobile_phone", "RAEE"),
    "/m/01c648": ("laptop", "RAEE"),
    "/m/01m2v": ("computer_keyboard", "RAEE"),
    "/m/020lf": ("computer_mouse", "RAEE"),
    "/m/07c52": ("television", "RAEE"),
    "/m/0dv5r": ("camera", "RAEE"),
    "/m/09qck": ("banana", "ORGANICO"),
    "/m/014j1m": ("apple", "ORGANICO"),
    "/m/0cyhj_": ("orange", "ORGANICO"),
    "/m/033cnk": ("egg", "ORGANICO"),
}

MAX_PER_SUBCLASS = 150

def download_openimages_annotations():
    val_bbox_url = "https://storage.googleapis.com/openimages/v5/validation-annotations-bbox.csv"
    val_img_url = "https://storage.googleapis.com/openimages/2018_04/validation/validation-images-with-rotation.csv"
    
    val_bbox_file = RAW_DIR / "validation-annotations-bbox.csv"
    val_img_file = RAW_DIR / "validation-images-with-rotation.csv"
    
    if not val_bbox_file.exists():
        print("Descargando Open Images validation bboxes...")
        r = requests.get(val_bbox_url, timeout=30)
        with open(val_bbox_file, "wb") as f:
            f.write(r.content)
            
    if not val_img_file.exists():
        print("Descargando Open Images validation images info...")
        r = requests.get(val_img_url, timeout=30)
        with open(val_img_file, "wb") as f:
            f.write(r.content)
            
    return val_bbox_file, val_img_file

def main():
    bbox_file, img_file = download_openimages_annotations()
    
    # Leer URLs de imágenes
    print("Leyendo metadatos de imágenes...")
    image_urls = {}
    with open(img_file, "r", encoding="utf-8", errors="ignore") as f:
        reader = csv.DictReader(f)
        for row in reader:
            img_id = row.get("ImageID")
            url = row.get("OriginalURL")
            if img_id and url:
                image_urls[img_id] = url
                
    print(f"Total imágenes en metadata: {len(image_urls)}")
    
    # Filtrar bboxes para nuestras clases
    print("Filtrando bounding boxes de clases de interés...")
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
        print(f"  {subname} ({cat}): {len(bboxes)} anotaciones encontradas")
        
    session = requests.Session()
    session.headers.update({"User-Agent": "Mozilla/5.0"})
    
    saved_counts = {}
    
    for label, bboxes in target_bboxes.items():
        subname, cat = OI_CLASSES[label]
        target_dir = CROPS_DIR / cat
        target_dir.mkdir(parents=True, exist_ok=True)
        
        count = 0
        pbar = tqdm(bboxes, desc=f"Procesando OI -> {cat}/{subname}")
        for row in pbar:
            if count >= MAX_PER_SUBCLASS:
                break
                
            img_id = row["ImageID"]
            url = image_urls.get(img_id)
            if not url:
                continue
                
            try:
                # Open Images bbox: XMin, XMax, YMin, YMax en coordenadas normalizadas [0, 1]
                xmin = float(row["XMin"])
                xmax = float(row["XMax"])
                ymin = float(row["YMin"])
                ymax = float(row["YMax"])
                
                bw_norm = xmax - xmin
                bh_norm = ymax - ymin
                
                # Descartar si el objeto es microscópico en la imagen (< 5% del área)
                if (bw_norm * bh_norm) < 0.02:
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
                
                # Margen del 15%
                mx = int(bw * 0.15)
                my = int(bh * 0.15)
                
                crop_x1 = max(0, bx1 - mx)
                crop_y1 = max(0, by1 - my)
                crop_x2 = min(w, bx2 + mx)
                crop_y2 = min(h, by2 + my)
                
                crop_w = crop_x2 - crop_x1
                crop_h = crop_y2 - crop_y1
                
                # Regla: Lado corto de 224 px o más
                if min(crop_w, crop_h) < 180:
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
                
    print("\nResumen Open Images procesado:")
    for cat, total in saved_counts.items():
        print(f"  {cat}: {total} fotos")

if __name__ == "__main__":
    main()
