import os
import sys
import time
import requests
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
    'User-Agent': 'EcoResiduos-OpenSource-Collector/2.0 (academic research; contact: cemor@uninorte.edu.co)'
}

# Consultas específicas y diversificadas para RCD, FONDO y PELIGROSO
CATEGORY_QUERIES = {
    "RCD": [
        "rubble", "demolition rubble", "concrete rubble", "broken bricks",
        "construction waste", "demolition waste", "crushed concrete",
        "brick rubble", "masonry rubble", "mortar rubble",
        "broken roof tiles", "broken ceramic tiles", "demolition debris",
        "construction debris", "asphalt rubble", "drywall waste",
        "excavation rubble", "building demolition concrete"
    ],
    "FONDO": [
        "wooden table", "dining table empty", "kitchen countertop",
        "granite countertop empty", "ceramic tile floor", "tiled floor empty",
        "parquet floor empty", "concrete floor empty", "clean sidewalk pavement",
        "green grass lawn clean", "empty wall white", "brick wall clean background",
        "empty plastic table", "empty waste container bin", "clean desk table"
    ],
    "PELIGROSO": [
        "alkaline battery", "lithium battery", "car battery lead acid",
        "aerosol can", "spray paint can", "solvent can hazard",
        "compact fluorescent bulb", "fluorescent tube lamp", "pesticide bottle"
    ]
}

def search_wikimedia_paginated(query, target_count=50):
    url = "https://commons.wikimedia.org/w/api.php"
    results = []
    seen = set()
    continue_params = {}
    
    while len(results) < target_count:
        params = {
            'action': 'query',
            'generator': 'search',
            'gsrsearch': f"{query} filetype:bitmap",
            'gsrnamespace': '6',
            'gsrlimit': '30',
            'prop': 'imageinfo',
            'iiprop': 'url|size|extmetadata',
            'format': 'json'
        }
        params.update(continue_params)
        
        try:
            r = requests.get(url, params=params, headers=HEADERS, timeout=15)
            if r.status_code != 200:
                break
            data = r.json()
            pages = data.get('query', {}).get('pages', {})
            if not pages:
                break
                
            for pid, pinfo in pages.items():
                imginfos = pinfo.get('imageinfo', [])
                if imginfos:
                    info = imginfos[0]
                    img_url = info.get('url')
                    width = info.get('width', 0)
                    height = info.get('height', 0)
                    license_name = info.get('extmetadata', {}).get('LicenseShortName', {}).get('value', 'CC')
                    if img_url and img_url not in seen and width >= 224 and height >= 224:
                        seen.add(img_url)
                        results.append({
                            'url': img_url,
                            'title': pinfo.get('title', ''),
                            'license': license_name,
                            'width': width,
                            'height': height
                        })
                        if len(results) >= target_count:
                            break
                            
            if 'continue' in data:
                continue_params = data['continue']
            else:
                break
        except Exception as e:
            break
            
        time.sleep(0.3)
        
    return results

def download_and_save(item, output_path):
    try:
        r = requests.get(item['url'], headers=HEADERS, timeout=15)
        if r.status_code != 200:
            return False
            
        im = Image.open(io.BytesIO(r.content)).convert("RGB")
        w, h = im.size
        
        if min(w, h) < 224:
            return False
            
        max_dim = max(w, h)
        if max_dim > 800:
            scale = 800.0 / max_dim
            im = im.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)
            
        im.save(output_path, "JPEG", quality=90)
        return True
    except Exception:
        return False

def collect_category(category, max_images=600):
    target_dir = RAW_BASE / "wikimedia_expanded" / category
    target_dir.mkdir(parents=True, exist_ok=True)
    
    queries = CATEGORY_QUERIES.get(category, [])
    all_items = []
    seen_urls = set()
    
    print(f"\n🔍 Buscando imágenes para [{category}]...")
    for q in queries:
        items = search_wikimedia_paginated(q, target_count=40)
        for it in items:
            if it['url'] not in seen_urls:
                seen_urls.add(it['url'])
                all_items.append(it)
        time.sleep(0.2)
        
    print(f"  Encontradas {len(all_items)} imágenes únicas para {category}")
    
    saved = 0
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {}
        for idx, it in enumerate(all_items):
            out_file = target_dir / f"wiki_{category.lower()}_{idx:04d}.jpg"
            futures[executor.submit(download_and_save, it, out_file)] = out_file
            
        for f in tqdm(as_completed(futures), total=len(futures), desc=f"Descargando {category}"):
            if f.result():
                saved += 1
                if saved >= max_images:
                    break
                    
    print(f"✅ [{category}] Guardadas: {saved} fotos")
    return saved

def main():
    print("🚀 INICIANDO RECOLECCIÓN AMPLIADA DE WIKIMEDIA (RCD, FONDO, PELIGROSO)...")
    summary = {}
    for cat in ["RCD", "FONDO", "PELIGROSO"]:
        cnt = collect_category(cat, max_images=550)
        summary[cat] = cnt
        time.sleep(1)
        
    print("\n📊 Resumen de recolección ampliada:")
    for c, count in summary.items():
        print(f"  {c}: {count} fotos")

if __name__ == "__main__":
    main()
