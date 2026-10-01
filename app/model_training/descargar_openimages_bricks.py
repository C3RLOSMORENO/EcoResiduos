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
CROPS_DIR = RAW_DIR / "crops_v2" / "RCD"
CROPS_DIR.mkdir(parents=True, exist_ok=True)

def es_catalogo(imagen):
    import numpy as np
    gris = np.asarray(imagen.convert('L').resize((96, 96)))
    borde = np.concatenate([gris[:6].ravel(), gris[-6:].ravel(), gris[:, :6].ravel(), gris[:, -6:].ravel()])
    return (borde > 235).mean() > 0.85

def main():
    bbox_file = RAW_DIR / "validation-annotations-bbox.csv"
    img_file = RAW_DIR / "validation-images-with-rotation.csv"
    
    image_urls = {}
    with open(img_file, "r", encoding="utf-8", errors="ignore") as f:
        reader = csv.DictReader(f)
        for row in reader:
            img_id = row.get("ImageID")
            url = row.get("OriginalURL")
            if img_id and url:
                image_urls[img_id] = url
                
    target_bboxes = []
    with open(bbox_file, "r", encoding="utf-8", errors="ignore") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row.get("LabelName") == "/m/0199g":
                img_id = row.get("ImageID")
                if img_id in image_urls:
                    target_bboxes.append(row)
                    
    print(f"Total Bricks a procesar: {len(target_bboxes)}")
    session = requests.Session()
    session.headers.update({"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
    
    saved = 0
    for row in tqdm(target_bboxes, desc="Descargando Bricks"):
        if saved >= 80:
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
            
            if min(crop_w, crop_h) < 224:
                continue
            if (max(crop_w, crop_h) / float(min(crop_w, crop_h))) > 2.5:
                continue
                
            crop_im = im.crop((crop_x1, crop_y1, crop_x2, crop_y2))
            if es_catalogo(crop_im):
                continue
                
            max_dim = max(crop_w, crop_h)
            if max_dim > 800:
                scale = 800.0 / max_dim
                new_w = int(crop_w * scale)
                new_h = int(crop_h * scale)
                crop_im = crop_im.resize((new_w, new_h), Image.Resampling.LANCZOS)
                
            out_name = f"openimages_brick_{saved:04d}.jpg"
            crop_im.save(CROPS_DIR / out_name, "JPEG", quality=90)
            saved += 1
        except Exception:
            continue
            
    print(f"✅ Descargados {saved} recortes válidos de Brick en {CROPS_DIR}")

if __name__ == "__main__":
    main()
