import os
import sys
import requests
import zipfile
import tarfile
from pathlib import Path
from tqdm import tqdm

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
RAW_DIR = SCRIPT_DIR / "descargas_crudas"
RAW_DIR.mkdir(parents=True, exist_ok=True)

HEADERS = {'User-Agent': 'Mozilla/5.0'}

def extract_zip_safely(zip_path, target_folder):
    target_folder.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, 'r') as z:
        for idx, item in enumerate(z.infolist()):
            if item.is_dir() or not item.filename.lower().endswith(('.jpg', '.jpeg', '.png')):
                continue
            # Obtener nombre de la categoría del subdirectorio
            parts = item.filename.replace('\\', '/').split('/')
            category_name = parts[-2] if len(parts) >= 2 else "item"
            out_name = f"{category_name}_{idx:04d}.jpg"
            out_file = target_folder / out_name
            
            with z.open(item) as src, open(out_file, 'wb') as dst:
                dst.write(src.read())
    print(f"✅ Extracción segura completada en {target_folder}")

def download_file(url, target_path):
    print(f"Descargando {url} -> {target_path}...")
    r = requests.get(url, stream=True, headers=HEADERS, timeout=30)
    r.raise_for_status()
    total = int(r.headers.get('content-length', 0))
    with open(target_path, 'wb') as f, tqdm(
        desc=target_path.name,
        total=total,
        unit='iB',
        unit_scale=True
    ) as bar:
        for chunk in r.iter_content(chunk_size=1024*1024):
            if chunk:
                f.write(chunk)
                bar.update(len(chunk))
    print(f"✅ Descarga completada: {target_path.name}")

def extract_dtd_safely(tar_path, target_folder):
    target_folder.mkdir(parents=True, exist_ok=True)
    with tarfile.open(tar_path, 'r:gz') as t:
        for member in t.getmembers():
            if not member.isfile() or not member.name.lower().endswith(('.jpg', '.jpeg', '.png')):
                continue
            parts = member.name.replace('\\', '/').split('/')
            # Formato típico: dtd/images/category_name/category_name_xxxx.jpg
            if len(parts) >= 3:
                cat_name = parts[-2]
                out_dir = target_folder / cat_name
                out_dir.mkdir(parents=True, exist_ok=True)
                out_file = out_dir / Path(parts[-1]).name
                
                f = t.extractfile(member)
                if f:
                    with open(out_file, 'wb') as dst:
                        dst.write(f.read())
    print(f"✅ Extracción DTD completada en {target_folder}")

def main():
    # 1. Demolition & Building Materials (RCD)
    rcd_zip = RAW_DIR / "demolition_scrap.zip"
    rcd_extract = RAW_DIR / "rcd_hf"
    
    if rcd_zip.exists() and rcd_zip.stat().st_size > 1000:
        print(f"Extrayendo de forma segura {rcd_zip}...")
        extract_zip_safely(rcd_zip, rcd_extract)
        
    # 2. Describable Textures Dataset (DTD) para FONDO y RCD
    dtd_tar = RAW_DIR / "dtd.tar.gz"
    dtd_extract = RAW_DIR / "dtd_extracted"
    dtd_url = "https://thor.robots.ox.ac.uk/dtd/dtd-r1.0.1.tar.gz"
    
    if not dtd_tar.exists() or dtd_tar.stat().st_size < 1000:
        download_file(dtd_url, dtd_tar)
        
    print(f"Extrayendo DTD en {dtd_extract}...")
    extract_dtd_safely(dtd_tar, dtd_extract)

if __name__ == "__main__":
    main()
