"""Empaqueta train.py y el dataset en ecoresiduos_colab.zip para entrenar en Colab.

    python empaquetar_para_colab.py
"""

import sys
import zipfile
from pathlib import Path

from verificar_dataset import EXTENSIONES

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
SALIDA = SCRIPT_DIR / 'ecoresiduos_colab.zip'


def main():
    """Escribe el .zip con train.py, dataset/ y dataset_prueba/."""
    total = 0
    with zipfile.ZipFile(SALIDA, 'w', zipfile.ZIP_STORED) as z:
        z.write(SCRIPT_DIR / 'train.py', 'train.py')
        for carpeta in ('dataset', 'dataset_prueba'):
            raiz = SCRIPT_DIR / carpeta
            if not raiz.exists():
                continue
            for f in sorted(raiz.rglob('*')):
                if f.suffix.lower() in EXTENSIONES:
                    z.write(f, f.relative_to(SCRIPT_DIR).as_posix())
                    total += 1
    print(f'✅ {SALIDA.name}: {total} imágenes, {SALIDA.stat().st_size / 1e6:.0f} MB')
    print('Súbelo en la primera celda de entrenar_en_colab.ipynb')


if __name__ == '__main__':
    main()
