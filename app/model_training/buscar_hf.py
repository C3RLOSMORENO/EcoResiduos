"""Busca en Hugging Face datasets de residuos y muestra los más descargados.

Script exploratorio: no descarga nada.

    python buscar_hf.py
"""

import requests

queries = ['construction waste', 'demolition', 'medical waste', 'battery waste', 'e-waste', 'garbage classification']
for q in queries:
    url = f"https://huggingface.co/api/datasets?search={requests.utils.quote(q)}"
    r = requests.get(url, timeout=10)
    if r.status_code == 200:
        data = r.json()
        print(f"HuggingFace search '{q}': {len(data)} datasets found")
        for it in data[:4]:
            print(f"  - {it.get('id')} | downloads: {it.get('downloads')}")
