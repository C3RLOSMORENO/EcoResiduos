"""Descarga fotos de Wikimedia Commons con licencia abierta y registra su atribución.

Quedan en descargas_crudas/wikimedia_v2/ y cada una se anota con su autor y
licencia en fuentes_individuales.csv.

    python descargar_wikimedia_v2.py
"""

import os
import sys
import csv
import json
import time
import requests
import hashlib
from pathlib import Path
from PIL import Image
import io
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
RAW_BASE = SCRIPT_DIR / "descargas_crudas"
RAW_BASE.mkdir(parents=True, exist_ok=True)
WIKIMEDIA_DIR = RAW_BASE / "wikimedia_v2"
WIKIMEDIA_DIR.mkdir(parents=True, exist_ok=True)
CSV_FILE = SCRIPT_DIR / "fuentes_individuales.csv"

HEADERS = {
    'User-Agent': 'EcoResiduos-Dataset-Builder/2.0 (academic research; contact: cemor@uninorte.edu.co)'
}

WIKIMEDIA_QUERIES = {
    "RCD": [
        "concrete rubble demolition",
        "broken bricks rubble debris",
        "demolition rubble construction",
        "crushed concrete construction waste",
        "broken roof tiles debris",
        "broken ceramic tiles rubble",
        "drywall demolition waste",
        "asphalt rubble road demolition",
        "mortar rubble construction site",
        "building rubble debris",
        "masonry rubble demolition",
        "stone rubble pile construction",
        "brick rubble pile"
    ],
    "FONDO": [
        "empty wooden table surface",
        "empty kitchen countertop granite",
        "empty kitchen countertop marble",
        "empty tiled floor ceramic clean",
        "empty concrete sidewalk clean",
        "empty clean grass lawn no trash",
        "empty white textured wall",
        "empty plastic table surface indoor",
        "empty clean trash can bin empty",
        "empty open human hand palm",
        "clean wooden floor parquet",
        "clean asphalt pavement texture"
    ],
    "PELIGROSO": [
        "discharged dry batteries pile",
        "alkaline batteries discarded",
        "lithium battery hazardous waste",
        "car battery lead acid discarded",
        "aerosol spray cans waste",
        "paint cans solvent hazard waste",
        "compact fluorescent light bulb waste",
        "fluorescent tube hazardous waste",
        "pesticide container hazardous waste",
        "motor oil container discarded"
    ],
    "RIESGO_BIOLOGICO": [
        "medical waste syringe discarded",
        "used syringe needle disposal",
        "used medical gloves waste discarded",
        "blood soaked gauze medical waste",
        "sharps container medical waste biohazard",
        "used surgical mask waste",
        "biomedical waste hospital disposal yellow bag",
        "medical waste disposal red bag biohazard"
    ],
    "RAEE": [
        "electronic waste pcb circuit board",
        "discarded broken mobile phone e-waste",
        "old broken laptop e-waste",
        "discarded computer keyboard mouse",
        "broken computer monitor tv screen e-waste",
        "tangled charger cables e-waste",
        "small domestic appliance e-waste",
        "electric power tool discarded e-waste",
        "computer motherboard scrap e-waste",
        "broken blender kettle e-waste"
    ]
}

def search_wikimedia(query, limit=50):
    """Resultados de Wikimedia Commons con URL, autor y licencia; [] si la API no responde."""
    url = "https://commons.wikimedia.org/w/api.php"
    params = {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': f"{query} filetype:bitmap",
        'gsrnamespace': '6',
        'gsrlimit': str(limit),
        'prop': 'imageinfo',
        'iiprop': 'url|size|extmetadata',
        'format': 'json'
    }
    try:
        r = requests.get(url, params=params, headers=HEADERS, timeout=15)
        if r.status_code == 200:
            data = r.json()
            pages = data.get('query', {}).get('pages', {})
            results = []
            for pid, pinfo in pages.items():
                imginfos = pinfo.get('imageinfo', [])
                if imginfos:
                    info = imginfos[0]
                    img_url = info.get('url')
                    width = info.get('width', 0)
                    height = info.get('height', 0)
                    title = pinfo.get('title', '')
                    ext = info.get('extmetadata', {})
                    license_name = ext.get('LicenseShortName', {}).get('value', 'CC BY / Public Domain')
                    author = ext.get('Artist', {}).get('value', 'Wikimedia Commons Contributor')
                    # Strip html from author
                    import re
                    author = re.sub(r'<[^>]+>', '', author).strip()
                    if not author:
                        author = "Wikimedia Contributor"
                        
                    if img_url and width >= 224 and height >= 224:
                        results.append({
                            'url': img_url,
                            'title': title,
                            'author': author,
                            'license': license_name,
                            'width': width,
                            'height': height
                        })
            return results
    except Exception as e:
        pass
    return []

def download_and_process_image(item, output_path):
    """Descarga la imagen, la reduce y la guarda si mide al menos 224 px. True si quedó guardada."""
    try:
        r = requests.get(item['url'], headers=HEADERS, timeout=15)
        if r.status_code != 200:
            return None
            
        im = Image.open(io.BytesIO(r.content)).convert("RGB")
        w, h = im.size
        
        # Validar tamaño mínimo y aspecto
        if min(w, h) < 224:
            return None
        if (max(w, h) / float(min(w, h))) > 2.5:
            return None
            
        # Redimensionar a máximo 800px
        max_dim = max(w, h)
        if max_dim > 800:
            scale = 800.0 / max_dim
            new_w = int(w * scale)
            new_h = int(h * scale)
            im = im.resize((new_w, new_h), Image.Resampling.LANCZOS)
            
        im.save(output_path, "JPEG", quality=90)
        return item
    except Exception:
        return None

def collect_wikimedia(max_per_category=350):
    """Descarga de Wikimedia Commons hasta max_per_category imágenes por categoría."""
    all_records = []
    
    # Si ya existe CSV, leerlo para mantener registros
    if CSV_FILE.exists():
        with open(CSV_FILE, "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.DictReader(f)
            for row in reader:
                all_records.append(row)
                
    recorded_urls = {r.get('url') for r in all_records if 'url' in r}
    
    for cat, queries in WIKIMEDIA_QUERIES.items():
        cat_dir = WIKIMEDIA_DIR / cat
        cat_dir.mkdir(parents=True, exist_ok=True)
        
        seen_urls = set()
        items = []
        for q in queries:
            res = search_wikimedia(q, limit=40)
            for it in res:
                if it['url'] not in seen_urls:
                    seen_urls.add(it['url'])
                    items.append(it)
            time.sleep(0.4)
            
        print(f"\n[{cat}] {len(items)} imágenes candidatas en Wikimedia.")
        
        saved = 0
        with ThreadPoolExecutor(max_workers=8) as executor:
            futures = {}
            for idx, it in enumerate(items):
                out_name = f"wikimedia_{cat.lower()}_{idx:04d}.jpg"
                out_path = cat_dir / out_name
                futures[executor.submit(download_and_process_image, it, out_path)] = (it, out_name)
                
            for f in tqdm(as_completed(futures), total=len(futures), desc=f"Descargando {cat}"):
                res = f.result()
                if res:
                    it, out_name = futures[f]
                    saved += 1
                    if it['url'] not in recorded_urls:
                        recorded_urls.add(it['url'])
                        all_records.append({
                            "archivo": out_name,
                            "categoria": cat,
                            "url": it['url'],
                            "autor": it['author'],
                            "licencia": it['license'],
                            "titulo": it['title']
                        })
                    if saved >= max_per_category:
                        break
                        
        print(f"✅ [{cat}] {saved} fotos válidas descargadas.")
        
    # Guardar CSV actualizado
    with open(CSV_FILE, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["archivo", "categoria", "url", "autor", "licencia", "titulo"])
        writer.writeheader()
        for r in all_records:
            writer.writerow(r)
            
    print(f"\n📄 CSV de fuentes individuales guardado en {CSV_FILE} ({len(all_records)} registros)")

if __name__ == "__main__":
    collect_wikimedia()
