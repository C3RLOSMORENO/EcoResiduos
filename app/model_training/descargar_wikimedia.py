"""Descarga fotos de Wikimedia Commons con licencia abierta para varias categorías.

Quedan en descargas_crudas/wikimedia/<CATEGORIA>/. descargar_wikimedia_v2.py
hace lo mismo y además registra el autor y la licencia de cada foto.

    python descargar_wikimedia.py
"""

import os
import sys
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

HEADERS = {
    'User-Agent': 'EcoResiduos-Academic-Dataset-Builder/1.0 (academic research; contact: cemor@uninorte.edu.co)'
}

# Términos de búsqueda con licencias abiertas para Wikimedia Commons (CC BY / CC0 / Public Domain)
WIKIMEDIA_QUERIES = {
    "RCD": [
        "concrete rubble demolition",
        "broken bricks pile debris",
        "demolition rubble construction",
        "crushed concrete construction waste",
        "broken roof tiles debris",
        "broken ceramic tiles rubble",
        "drywall demolition waste",
        "asphalt rubble road demolition",
        "mortar rubble construction site",
        "building rubble debris",
        "construction waste pile rubble"
    ],
    "RIESGO_BIOLOGICO": [
        "medical waste syringe",
        "used syringe needle disposal",
        "used medical gloves waste",
        "blood soaked gauze medical waste",
        "sharps container medical waste",
        "used surgical mask waste",
        "biomedical waste hospital disposal",
        "medical waste disposal bag biohazard",
        "contaminated syringe needle biohazard"
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
        "expired medicine blisters hazard",
        "pesticide container hazardous waste"
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
        "computer motherboard scrap e-waste"
    ],
    "ORDINARIO": [
        "cigarette butts littered ground",
        "empty chips snack foil wrapper",
        "dirty paper napkin trash",
        "used sanitary napkin diaper trash",
        "greasy dirty styrofoam container",
        "metallized snack wrapper trash",
        "dirty food wrapper trash bag",
        "sweepings dustpan floor trash"
    ],
    "FONDO": [
        "empty wooden table surface",
        "empty kitchen countertop granite marble",
        "empty tiled floor ceramic clean",
        "empty concrete sidewalk clean",
        "empty clean grass lawn no trash",
        "empty white textured wall",
        "empty plastic table surface indoor",
        "empty clean trash can bin empty",
        "empty open human hand palm"
    ]
}

def search_wikimedia(query, limit=50):
    """Resultados de Wikimedia Commons con su URL y licencia; [] si la API no responde."""
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
                    license_name = info.get('extmetadata', {}).get('LicenseShortName', {}).get('value', 'CC')
                    if img_url and width >= 224 and height >= 224:
                        results.append({
                            'url': img_url,
                            'title': title,
                            'license': license_name,
                            'width': width,
                            'height': height
                        })
            return results
    except Exception as e:
        print(f"Error buscando Wikimedia '{query}': {e}")
    return []

def download_and_process_image(item, output_path):
    """Descarga la imagen, la reduce y la guarda si mide al menos 224 px. True si quedó guardada."""
    try:
        r = requests.get(item['url'], headers=HEADERS, timeout=15)
        if r.status_code != 200:
            return False
            
        im = Image.open(io.BytesIO(r.content)).convert("RGB")
        w, h = im.size
        
        # Validar tamaño mínimo de 224px en lado corto
        if min(w, h) < 224:
            return False
            
        # Redimensionar a máximo 800px en lado mayor
        max_dim = max(w, h)
        if max_dim > 800:
            scale = 800.0 / max_dim
            new_w = int(w * scale)
            new_h = int(h * scale)
            im = im.resize((new_w, new_h), Image.Resampling.LANCZOS)
            
        im.save(output_path, "JPEG", quality=90)
        return True
    except Exception:
        return False

def collect_wikimedia_for_category(category, max_images=400):
    """Descarga las imágenes de las consultas de la categoría y devuelve cuántas guardó."""
    target_dir = RAW_BASE / "wikimedia" / category
    target_dir.mkdir(parents=True, exist_ok=True)
    
    queries = WIKIMEDIA_QUERIES.get(category, [])
    seen_urls = set()
    all_items = []
    
    for q in queries:
        items = search_wikimedia(q, limit=40)
        for it in items:
            if it['url'] not in seen_urls:
                seen_urls.add(it['url'])
                all_items.append(it)
        time.sleep(0.5)
        
    print(f"📂 [{category}] {len(all_items)} imágenes encontradas en Wikimedia Commons.")
    
    saved = 0
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = {}
        for idx, it in enumerate(all_items):
            out_file = target_dir / f"wikimedia_{category.lower()}_{idx:04d}.jpg"
            futures[executor.submit(download_and_process_image, it, out_file)] = out_file
            
        for f in tqdm(as_completed(futures), total=len(futures), desc=f"Descargando {category}"):
            if f.result():
                saved += 1
                if saved >= max_images:
                    break
                    
    print(f"✅ [{category}] Descargadas exitosamente: {saved} fotos")
    return saved

def main():
    """Descarga de Wikimedia Commons hasta 350 imágenes de RCD, RIESGO_BIOLOGICO, PELIGROSO, RAEE, ORDINARIO y FONDO."""
    print("🚀 INICIANDO RECOLECCIÓN DE IMÁGENES LIBRES (WIKIMEDIA COMMONS CC BY/CC0)...")
    summary = {}
    categories = ["RCD", "RIESGO_BIOLOGICO", "PELIGROSO", "RAEE", "ORDINARIO", "FONDO"]
    for cat in categories:
        cnt = collect_wikimedia_for_category(cat, max_images=350)
        summary[cat] = cnt
        time.sleep(1)
        
    print("\n📊 Resumen de recolección Wikimedia:")
    for c, count in summary.items():
        print(f"  {c}: {count} fotos")

if __name__ == "__main__":
    main()
