import os
import sys
import shutil
import zipfile
from pathlib import Path

# Configurar salida UTF-8 para evitar errores con caracteres en la consola de Windows
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

# Rutas principales
DOWNLOADS_DATASET_DIR = Path(r"C:\Users\janerbustillo\Downloads\U_2026B\Proyecto\datasets")
TARGET_DATASET_DIR = Path(__file__).parent / "dataset"

# Mapeo de subcarpetas del dataset 'organic/images/images' (Garbage 30 classes)
ORGANIC_DATASET_MAPPING = {
    # ORGANICO
    "coffee_grounds": "ORGANICO",
    "eggshells": "ORGANICO",
    "food_waste": "ORGANICO",
    "tea_bags": "ORGANICO",

    # RECICLABLE
    "aluminum_food_cans": "RECICLABLE",
    "aluminum_soda_cans": "RECICLABLE",
    "steel_food_cans": "RECICLABLE",
    "glass_beverage_bottles": "RECICLABLE",
    "glass_cosmetic_containers": "RECICLABLE",
    "glass_food_jars": "RECICLABLE",
    "cardboard_boxes": "RECICLABLE",
    "cardboard_packaging": "RECICLABLE",
    "newspaper": "RECICLABLE",
    "magazines": "RECICLABLE",
    "office_paper": "RECICLABLE",
    "plastic_water_bottles": "RECICLABLE",
    "plastic_soda_bottles": "RECICLABLE",
    "plastic_detergent_bottles": "RECICLABLE",
    "plastic_food_containers": "RECICLABLE",
    "plastic_cup_lids": "RECICLABLE",
    "plastic_shopping_bags": "RECICLABLE",

    # ORDINARIO
    "styrofoam_food_containers": "ORDINARIO",
    "styrofoam_cups": "ORDINARIO",
    "paper_cups": "ORDINARIO",
    "plastic_straws": "ORDINARIO",
    "disposable_plastic_cutlery": "ORDINARIO",
    "plastic_trash_bags": "ORDINARIO",
    "clothing": "ORDINARIO",
    "shoes": "ORDINARIO",

    # PELIGROSO
    "aerosol_cans": "PELIGROSO",
}

def ensure_target_dirs():
    categories = ["ORGANICO", "RECICLABLE", "ORDINARIO", "PELIGROSO", "BIOSANITARIO", "RAEE", "INDUSTRIAL"]
    for cat in categories:
        (TARGET_DATASET_DIR / cat).mkdir(parents=True, exist_ok=True)

def copy_organic_images():
    print("\n📦 1. Procesando dataset 'organic' (Garbage Classification)...")
    source_dir = DOWNLOADS_DATASET_DIR / "organic" / "images" / "images"
    if not source_dir.exists():
        print(f"⚠️ No se encontró: {source_dir}")
        return

    count_per_cat = {}
    for folder_name, target_cat in ORGANIC_DATASET_MAPPING.items():
        folder_path = source_dir / folder_name
        if not folder_path.exists():
            continue

        target_dir = TARGET_DATASET_DIR / target_cat
        count = 0
        for root, _, files in os.walk(folder_path):
            for file in files:
                if file.lower().endswith(('.jpg', '.jpeg', '.png')):
                    src_file = Path(root) / file
                    dst_file = target_dir / f"{folder_name}_{count}_{file}"
                    if not dst_file.exists():
                        shutil.copy2(src_file, dst_file)
                        count += 1
        count_per_cat[target_cat] = count_per_cat.get(target_cat, 0) + count
        print(f"  -> {folder_name} ({count} fotos) ==> {target_cat}")

    for cat, total in count_per_cat.items():
        print(f"  ✅ Total agregado a {cat}: {total} fotos")

def copy_electronica_images():
    print("\n📦 2. Procesando dataset 'electronica' (RAEE y Baterías)...")
    source_dir = DOWNLOADS_DATASET_DIR / "electronica" / "modified-dataset"
    if not source_dir.exists():
        print(f"⚠️ No se encontró: {source_dir}")
        return

    raee_dir = TARGET_DATASET_DIR / "RAEE"
    peligroso_dir = TARGET_DATASET_DIR / "PELIGROSO"
    
    raee_count = 0
    peligroso_count = 0

    for root, _, files in os.walk(source_dir):
        parent_name = Path(root).name
        for file in files:
            if file.lower().endswith(('.jpg', '.jpeg', '.png')):
                src_file = Path(root) / file
                if parent_name.lower() == "battery":
                    dst_file = peligroso_dir / f"battery_{peligroso_count}_{file}"
                    if not dst_file.exists():
                        shutil.copy2(src_file, dst_file)
                        peligroso_count += 1
                else:
                    dst_file = raee_dir / f"raee_{raee_count}_{file}"
                    if not dst_file.exists():
                        shutil.copy2(src_file, dst_file)
                        raee_count += 1

    print(f"  ✅ Agregado a RAEE: {raee_count} fotos")
    print(f"  ✅ Agregado a PELIGROSO (Baterías): {peligroso_count} fotos")

def copy_industry_images():
    print("\n📦 3. Procesando dataset 'industry' (INDUSTRIAL)...")
    source_dir = DOWNLOADS_DATASET_DIR / "industry" / "Warp-C" / "train_crops"
    if not source_dir.exists():
        print(f"⚠️ No se encontró: {source_dir}")
        return

    industrial_dir = TARGET_DATASET_DIR / "INDUSTRIAL"
    count = 0
    for root, _, files in os.walk(source_dir):
        category_name = Path(root).name
        for file in files:
            if file.lower().endswith(('.jpg', '.jpeg', '.png')):
                src_file = Path(root) / file
                dst_file = industrial_dir / f"ind_{category_name}_{count}_{file}"
                if not dst_file.exists():
                    shutil.copy2(src_file, dst_file)
                    count += 1
                if count >= 2000:
                    break
        if count >= 2000:
            break

    print(f"  ✅ Agregado a INDUSTRIAL: {count} fotos")

def extract_medico_images():
    print("\n📦 4. Extrayendo dataset 'medico.zip' (BIOSANITARIO y PELIGROSO)...")
    zip_path = DOWNLOADS_DATASET_DIR / "medico.zip"
    if not zip_path.exists():
        print(f"⚠️ No se encontró: {zip_path}")
        return

    biosanitario_dir = TARGET_DATASET_DIR / "BIOSANITARIO"
    peligroso_dir = TARGET_DATASET_DIR / "PELIGROSO"

    bio_classes = ["used_masks", "used_medical_gloves", "used_syringes", "blood_soaked_bandages", "human_organs"]
    peligro_classes = ["expired_tablets", "ampoules_full", "ampuoles_broken", "vaccine_or_medicine_vials"]

    bio_count = 0
    peligro_count = 0

    with zipfile.ZipFile(zip_path, 'r') as z:
        for filename in z.namelist():
            if not filename.lower().endswith(('.jpg', '.jpeg', '.png')):
                continue
            
            if "raw" in filename.lower():
                parts = filename.split('/')
                subfolder = parts[-2] if len(parts) >= 2 else ""

                if subfolder in bio_classes:
                    dst_file = biosanitario_dir / f"med_{subfolder}_{bio_count}.jpg"
                    if not dst_file.exists():
                        with z.open(filename) as src, open(dst_file, 'wb') as dst:
                            dst.write(src.read())
                        bio_count += 1
                elif subfolder in peligro_classes:
                    dst_file = peligroso_dir / f"med_{subfolder}_{peligro_count}.jpg"
                    if not dst_file.exists():
                        with z.open(filename) as src, open(dst_file, 'wb') as dst:
                            dst.write(src.read())
                        peligro_count += 1

    print(f"  ✅ Agregado a BIOSANITARIO: {bio_count} fotos")
    print(f"  ✅ Agregado a PELIGROSO (Medicamentos/Ampollas): {peligro_count} fotos")

def print_final_summary():
    print("\n📊 === RESUMEN FINAL DEL DATASET LISTO PARA ENTRENAR ===")
    total_imgs = 0
    for cat_dir in sorted(TARGET_DATASET_DIR.iterdir()):
        if cat_dir.is_dir():
            count = len([f for f in cat_dir.glob("*") if f.is_file()])
            total_imgs += count
            print(f"  📁 {cat_dir.name}: {count} imágenes")
    print(f"\n🎉 Total general de imágenes: {total_imgs}")

def main():
    print("🚀 INICIANDO ORGANIZACIÓN AUTOMÁTICA DE DATASETS...")
    ensure_target_dirs()
    copy_organic_images()
    copy_electronica_images()
    copy_industry_images()
    extract_medico_images()
    print_final_summary()

if __name__ == "__main__":
    main()
