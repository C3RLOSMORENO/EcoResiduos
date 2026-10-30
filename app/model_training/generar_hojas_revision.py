"""Genera hojas de contacto de 10 x 10 miniaturas por categoría para revisar dataset/ a ojo.

Las hojas quedan en revision/, con el nombre de cada archivo bajo su miniatura.

    python generar_hojas_revision.py
"""

import os
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
DATASET_DIR = SCRIPT_DIR / "dataset"
REVISION_DIR = SCRIPT_DIR / "revision"

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

GRID_COLS = 10
GRID_ROWS = 10
BATCH_SIZE = GRID_COLS * GRID_ROWS  # 100 images per sheet

THUMB_W = 120
THUMB_H = 120
LABEL_H = 22
CELL_W = THUMB_W + 8
CELL_H = THUMB_H + LABEL_H + 8
MARGIN = 16

def create_contact_sheet(category, batch_idx, image_files):
    """Arma una hoja de 10 x 10 miniaturas con el nombre de cada archivo y la guarda en revision/."""
    num_imgs = len(image_files)
    sheet_w = MARGIN * 2 + GRID_COLS * CELL_W
    sheet_h = MARGIN * 2 + GRID_ROWS * CELL_H + 40  # Header area
    
    sheet = Image.new("RGB", (sheet_w, sheet_h), color=(30, 30, 30))
    draw = ImageDraw.Draw(sheet)
    
    # Try to get a standard font or default font
    try:
        font = ImageFont.load_default()
    except Exception:
        font = None
        
    title = f"REVISIÓN VISUAL: {category} (Hoja {batch_idx + 1} - {num_imgs} imágenes)"
    draw.text((MARGIN, 12), title, fill=(255, 255, 255), font=font)
    
    for i, img_path in enumerate(image_files):
        row = i // GRID_COLS
        col = i % GRID_COLS
        
        x = MARGIN + col * CELL_W + 4
        y = MARGIN + 40 + row * CELL_H + 4
        
        try:
            with Image.open(img_path) as im:
                im = im.convert("RGB")
                im.thumbnail((THUMB_W, THUMB_H))
                
                # Center thumbnail in slot
                im_w, im_h = im.size
                offset_x = x + (THUMB_W - im_w) // 2
                offset_y = y + (THUMB_H - im_h) // 2
                sheet.paste(im, (offset_x, offset_y))
                
            # Truncate filename if long
            name = img_path.name
            if len(name) > 16:
                short_name = name[:7] + ".." + name[-7:]
            else:
                short_name = name
                
            text_y = y + THUMB_H + 2
            draw.text((x, text_y), short_name, fill=(200, 200, 200), font=font)
        except Exception as e:
            draw.rectangle([x, y, x + THUMB_W, y + THUMB_H], fill=(80, 20, 20))
            draw.text((x + 2, y + 2), "ERROR", fill=(255, 100, 100), font=font)
            
    out_path = REVISION_DIR / f"{category}_{batch_idx + 1:02d}.jpg"
    sheet.save(out_path, "JPEG", quality=88)
    return out_path

def main():
    """Genera las hojas de todas las categorías de dataset/."""
    REVISION_DIR.mkdir(parents=True, exist_ok=True)
    print("Generando hojas de contacto 10x10 para revisión visual...")
    
    total_sheets = 0
    for cat in CATEGORIES:
        cat_dir = DATASET_DIR / cat
        if not cat_dir.exists():
            print(f" Carpeta {cat} no existe.")
            continue
            
        img_files = sorted(list(cat_dir.glob("*.jpg")) + list(cat_dir.glob("*.png")))
        total_imgs = len(img_files)
        
        if total_imgs == 0:
            print(f" {cat}: 0 imágenes.")
            continue
            
        # Divide in batches of 100
        batches = [img_files[i:i + BATCH_SIZE] for i in range(0, total_imgs, BATCH_SIZE)]
        for b_idx, batch in enumerate(batches):
            out_file = create_contact_sheet(cat, b_idx, batch)
            total_sheets += 1
            
        print(f"  {cat:18s}: {len(batches)} hoja(s) creada(s) para {total_imgs} fotos")
        
    print(f"\nTotal de hojas de contacto generadas: {total_sheets} en {REVISION_DIR}")

if __name__ == "__main__":
    main()
