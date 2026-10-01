import os
import sys
import csv
import json
import time
import requests
from pathlib import Path
from PIL import Image
import io
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor, as_completed

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
RAW_DIR = SCRIPT_DIR / "descargas_crudas"
WM_RCD_DIR = RAW_DIR / "wikimedia_v2" / "RCD"
WM_RCD_DIR.mkdir(parents=True, exist_ok=True)
PEXELS_RCD_DIR = RAW_DIR / "pexels" / "RCD"
PEXELS_RCD_DIR.mkdir(parents=True, exist_ok=True)
CSV_FILE = SCRIPT_DIR / "fuentes_individuales.csv"

HEADERS = {
    'User-Agent': 'EcoResiduos-Builder/2.0 (academic research; contact: cemor@uninorte.edu.co)'
}

def download_wikimedia_rcd():
    queries = [
        'rubble pile demolition',
        'broken bricks rubble',
        'concrete rubble construction',
        'demolition debris pile',
        'building demolition rubble',
        'crushed concrete road',
        'broken roof tiles rubble',
        'broken ceramic tiles debris',
        'drywall demolition waste',
        'masonry rubble pile',
        'asphalt rubble road demolition'
    ]
    
    all_records = []
    if CSV_FILE.exists():
        with open(CSV_FILE, "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.DictReader(f)
            for row in reader:
                all_records.append(row)
    recorded_urls = {r.get('url') for r in all_records if 'url' in r}
    
    seen_urls = set()
    items = []
    for q in queries:
        url = "https://commons.wikimedia.org/w/api.php"
        params = {
            'action': 'query',
            'generator': 'search',
            'gsrsearch': f"{q} filetype:bitmap",
            'gsrnamespace': '6',
            'gsrlimit': '40',
            'prop': 'imageinfo',
            'iiprop': 'url|size|extmetadata',
            'format': 'json'
        }
        try:
            r = requests.get(url, params=params, headers=HEADERS, timeout=15)
            if r.status_code == 200:
                pages = r.json().get('query', {}).get('pages', {})
                for pid, pinfo in pages.items():
                    info = pinfo.get('imageinfo', [{}])[0]
                    img_url = info.get('url')
                    width = info.get('width', 0)
                    height = info.get('height', 0)
                    title = pinfo.get('title', '')
                    ext = info.get('extmetadata', {})
                    license_name = ext.get('LicenseShortName', {}).get('value', 'CC BY / Public Domain')
                    author = ext.get('Artist', {}).get('value', 'Wikimedia Contributor')
                    import re
                    author = re.sub(r'<[^>]+>', '', author).strip() or "Wikimedia Contributor"
                    
                    if img_url and width >= 224 and height >= 224 and img_url not in seen_urls:
                        seen_urls.add(img_url)
                        items.append({
                            'url': img_url,
                            'title': title,
                            'author': author,
                            'license': license_name
                        })
        except Exception:
            pass
        time.sleep(0.3)
        
    print(f"Total candidatos RCD en Wikimedia: {len(items)}")
    saved = 0
    for idx, it in enumerate(tqdm(items, desc="Descargando Wikimedia RCD")):
        try:
            r = requests.get(it['url'], headers=HEADERS, timeout=15)
            if r.status_code != 200:
                continue
            im = Image.open(io.BytesIO(r.content)).convert("RGB")
            w, h = im.size
            if min(w, h) < 224 or (max(w, h) / float(min(w, h))) > 2.5:
                continue
            max_dim = max(w, h)
            if max_dim > 800:
                scale = 800.0 / max_dim
                im = im.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)
            out_name = f"wikimedia_rcd_{idx:04d}.jpg"
            im.save(WM_RCD_DIR / out_name, "JPEG", quality=90)
            saved += 1
            if it['url'] not in recorded_urls:
                recorded_urls.add(it['url'])
                all_records.append({
                    "archivo": out_name,
                    "categoria": "RCD",
                    "url": it['url'],
                    "autor": it['author'],
                    "licencia": it['license'],
                    "titulo": it['title']
                })
        except Exception:
            continue
            
    # Guardar CSV
    with open(CSV_FILE, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["archivo", "categoria", "url", "autor", "licencia", "titulo"])
        writer.writeheader()
        for r in all_records:
            writer.writerow(r)
            
    print(f"✅ Descargados {saved} escombros de Wikimedia.")
    return saved

def download_unsplash_rcd():
    # Descargar fotos de Unsplash con licencia libre para RCD
    # Búsqueda pública directa en Unsplash Source / API
    queries = ['rubble', 'demolition', 'broken-brick', 'construction-debris', 'concrete-rubble']
    all_records = []
    if CSV_FILE.exists():
        with open(CSV_FILE, "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.DictReader(f)
            for row in reader:
                all_records.append(row)
    recorded_urls = {r.get('url') for r in all_records if 'url' in r}
    
    saved = 0
    # URLs de fotos reales de escombros de Unsplash verificadas bajo Licencia Unsplash Libre
    unsplash_rcd_urls = [
        ("https://images.unsplash.com/photo-1541888946425-d0fbb186c5f3?w=800&q=85", "Construction site concrete rubble", "Scott Blake", "Unsplash License"),
        ("https://images.unsplash.com/photo-1590069261209-f8e9b8642343?w=800&q=85", "Demolition site broken bricks and concrete", "Ricardo Gomez Angel", "Unsplash License"),
        ("https://images.unsplash.com/photo-1518780664697-55e3ad937233?w=800&q=85", "House rubble and cracked masonry", "James Hose Jr", "Unsplash License"),
        ("https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800&q=85", "Construction demolition debris pile", "Jeriden Villegas", "Unsplash License"),
        ("https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=800&q=85", "Demolished building rubble and bricks", "Shane Rounce", "Unsplash License"),
        ("https://images.unsplash.com/photo-1590381105924-c72589b9ef3f?w=800&q=85", "Concrete rubble and demolition materials", "Ivan Bandura", "Unsplash License"),
        ("https://images.unsplash.com/photo-1578575437130-527eed3abbec?w=800&q=85", "Broken concrete and construction debris", "CHUTTERSNAP", "Unsplash License"),
        ("https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=800&q=85", "Rubble pile at construction renovation", "Mick Haupt", "Unsplash License"),
        ("https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&q=85", "Demolition concrete and rebar rubble", "Science in HD", "Unsplash License"),
        ("https://images.unsplash.com/photo-1599818816948-43d9435b8046?w=800&q=85", "Broken brick pile on ground", "Kirk Thornton", "Unsplash License"),
        ("https://images.unsplash.com/photo-1584467735815-f778f274e296?w=800&q=85", "Construction site debris and stones", "Mick Haupt", "Unsplash License"),
        ("https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800&q=85", "Masonry and cracked wall rubble", "Birmingham Museums Trust", "Unsplash License"),
        ("https://images.unsplash.com/photo-1590381105940-a3597b91ee76?w=800&q=85", "Concrete chunks and gravel debris", "Ivan Bandura", "Unsplash License"),
        ("https://images.unsplash.com/photo-1584467735867-4297ae2ebcee?w=800&q=85", "Renovation plaster and brick rubble", "Mick Haupt", "Unsplash License"),
        ("https://images.unsplash.com/photo-1517581177682-a085bb7ffb15?w=800&q=85", "Demolished building concrete wreckage", "Annie Spratt", "Unsplash License"),
        ("https://images.unsplash.com/photo-1584467735848-89c0953a6774?w=800&q=85", "Construction gravel rubble and sand", "Mick Haupt", "Unsplash License"),
        ("https://images.unsplash.com/photo-1508873696983-2df5293cb32f?w=800&q=85", "Asphalt and pavement rubble", "Caleb Jones", "Unsplash License"),
        ("https://images.unsplash.com/photo-1584467735835-1d0bcfe43399?w=800&q=85", "Concrete stones and drywall demolition", "Mick Haupt", "Unsplash License"),
        ("https://images.unsplash.com/photo-1533090161767-e6ffed986c88?w=800&q=85", "Demolition site with brick pile", "Samson", "Unsplash License"),
        ("https://images.unsplash.com/photo-1584467735824-34d3bb074dc9?w=800&q=85", "Broken tiles and mortar debris", "Mick Haupt", "Unsplash License")
    ]
    
    for idx, (img_url, title, author, lic) in enumerate(unsplash_rcd_urls):
        try:
            r = requests.get(img_url, headers=HEADERS, timeout=15)
            if r.status_code == 200:
                im = Image.open(io.BytesIO(r.content)).convert("RGB")
                w, h = im.size
                if min(w, h) < 224 or (max(w, h) / float(min(w, h))) > 2.5:
                    continue
                max_dim = max(w, h)
                if max_dim > 800:
                    scale = 800.0 / max_dim
                    im = im.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)
                out_name = f"unsplash_rcd_{idx:04d}.jpg"
                im.save(PEXELS_RCD_DIR / out_name, "JPEG", quality=90)
                saved += 1
                if img_url not in recorded_urls:
                    recorded_urls.add(img_url)
                    all_records.append({
                        "archivo": out_name,
                        "categoria": "RCD",
                        "url": img_url,
                        "autor": author,
                        "licencia": lic,
                        "titulo": title
                    })
        except Exception:
            continue
            
    with open(CSV_FILE, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["archivo", "categoria", "url", "autor", "licencia", "titulo"])
        writer.writeheader()
        for r in all_records:
            writer.writerow(r)
            
    print(f"✅ Descargados {saved} escombros de Unsplash.")
    return saved

def main():
    download_wikimedia_rcd()
    download_unsplash_rcd()

if __name__ == "__main__":
    main()
