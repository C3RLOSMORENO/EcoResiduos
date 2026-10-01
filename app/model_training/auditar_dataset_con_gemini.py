import os
import sys
import base64
import json
import random
import time
import requests
from pathlib import Path

# Salida UTF-8 para consola de Windows
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SCRIPT_DIR = Path(__file__).resolve().parent
DATASET_DIR = SCRIPT_DIR / "dataset"
DISCARDED_DIR = SCRIPT_DIR / "dataset_descartados_gemini"
REPORT_FILE = SCRIPT_DIR / "reporte_auditoria_gemini.md"

# Cargar API KEY desde .env
def get_api_key():
    env_paths = [
        SCRIPT_DIR.parent / ".env",
        SCRIPT_DIR.parent.parent / "app" / ".env",
        SCRIPT_DIR.parent.parent / ".env",
        SCRIPT_DIR / ".env"
    ]
    for p in env_paths:
        if p.exists():
            for line in p.read_text(encoding="utf-8", errors="ignore").splitlines():
                line = line.strip()
                if line.startswith("GEMINI_API_KEY="):
                    key = line.split("=", 1)[1].strip().strip('"').strip("'")
                    if key:
                        return key
    return os.environ.get("GEMINI_API_KEY")

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

CANDIDATE_MODELS = [
    "gemini-2.5-flash",
    "gemini-2.0-flash",
    "gemini-1.5-flash"
]

def audit_image_with_gemini(api_key, img_path, max_retries=3):
    # Redimensionar en memoria a máx 512x512 para que la subida sea instantánea y no cause timeouts
    try:
        from PIL import Image
        import io
        with Image.open(img_path) as im:
            im = im.convert("RGB")
            im.thumbnail((512, 512))
            buf = io.BytesIO()
            im.save(buf, format="JPEG", quality=85)
            b64_data = base64.b64encode(buf.getvalue()).decode("utf-8")
    except Exception:
        with open(img_path, "rb") as f:
            b64_data = base64.b64encode(f.read()).decode("utf-8")

    prompt = f"""
Eres un auditor ambiental experto bajo la normativa colombiana de gestion de residuos (Resolucion 2184 de 2019).
Analiza esta imagen y clasificala ESTRICTAMENTE en una de estas 8 categorias:
- APROVECHABLE: Plastico limpio, vidrio, metal/latas, carton, papel limpio.
- ORGANICO: Restos de comida cruda, cascaras de frutas/huevos, borra de cafe, hojas/pasto.
- ORDINARIO: Servilletas sucias, papel higienico, paquetes metalizados de snacks, colillas, icopor sucio.
- PELIGROSO: Pilas, baterias, aerosoles, envases de quimicos/solventes/pinturas, bombillos ahorradores, medicamentos.
- RAEE: Celulares, computadores, cables, cargadores, perifericos, electrodomesticos, placas electronicas.
- RCD: Escombros de construccion, ladrillo roto, concreto, tejas, ceramica/baldosa rota, arena, drywall.
- RIESGO_BIOLOGICO: Jeringas, agujas, guantes usados, gasas/algodones contaminados, tapabocas, material hospitalario.
- FONDO: Imagenes SIN ningun residuo (pisos limpios, paredes, mesas vacias, textura de andenes/superficies sin basura).

Responde UNICAMENTE con un objeto JSON valido en este formato exacto:
{{
  "categoria_sugerida": "UNA DE LAS 8 CATEGORIAS",
  "objeto_detectado": "Nombre comun del objeto principal o superficie",
  "confianza": 90,
  "justificacion": "Explicacion breve de por que pertenece a esta categoria"
}}
"""
    payload = {
        "contents": [{
            "parts": [
                {"text": prompt},
                {
                    "inline_data": {
                        "mime_type": "image/jpeg",
                        "data": b64_data
                    }
                }
            ]
        }],
        "generationConfig": {
            "response_mime_type": "application/json",
            "temperature": 0.2
        }
    }

    # Probar con modelos candidatos en caso de agotamiento temporal de cuota
    for model_name in CANDIDATE_MODELS:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}"
        for attempt in range(1, max_retries + 1):
            try:
                resp = requests.post(url, json=payload, timeout=25)
                if resp.status_code == 200:
                    res_json = resp.json()
                    raw_text = res_json["candidates"][0]["content"]["parts"][0]["text"]
                    parsed = json.loads(raw_text)
                    parsed["_model_used"] = model_name
                    return parsed
                elif resp.status_code in (503, 429):
                    # Intentar obtener tiempo sugerido de espera
                    wait_time = 4 * attempt
                    try:
                        err_data = resp.json()
                        for detail in err_data.get("error", {}).get("details", []):
                            if detail.get("@type", "").endswith("RetryInfo"):
                                delay_str = detail.get("retryDelay", "4s").rstrip("s")
                                wait_time = max(float(delay_str), 3.0)
                    except Exception:
                        pass
                    time.sleep(wait_time)
                    continue
                else:
                    break  # Probar con siguiente modelo si este da error no recuperable
            except (requests.exceptions.Timeout, requests.exceptions.ConnectionError):
                if attempt < max_retries:
                    time.sleep(3 * attempt)
                    continue
                break
            except Exception as e:
                return {"error": str(e)}

    return {"error": "Cuota o límite de peticiones temporalmente alcanzado en todos los modelos disponibles"}

def main(samples_per_cat=5, auto_clean=False, target_category=None):
    api_key = get_api_key()
    if not api_key:
        print("❌ Error: No se encontró la GEMINI_API_KEY en los archivos .env.")
        return

    print("=" * 65)
    print("🔬 AUDITORÍA DE DATASET CON IA MAESTRA (Teacher-Student Pipeline)")
    print(f"   Modelos Auditores: {', '.join(CANDIDATE_MODELS)}")
    print(f"   Muestras por categoría: {samples_per_cat}")
    print(f"   Limpieza automática (auto-clean): {'ACTIVADA' if auto_clean else 'DESACTIVADA (Solo reporte)'}")
    print("=" * 65)

    categories_to_audit = [target_category] if target_category else CATEGORIES
    
    total_audited = 0
    total_matches = 0
    discordances = []

    for cat in categories_to_audit:
        cat_dir = DATASET_DIR / cat
        if not cat_dir.exists():
            continue

        images = [f for f in cat_dir.iterdir() if f.suffix.lower() in ('.jpg', '.jpeg', '.png')]
        if not images:
            continue

        sample_size = min(samples_per_cat, len(images))
        sampled_images = random.sample(images, sample_size)

        print(f"\n📂 Evaluando categoría: {cat} ({sample_size} imágenes tomadas de {len(images)})...")

        for idx, img in enumerate(sampled_images, 1):
            result = audit_image_with_gemini(api_key, img)
            
            if "error" in result:
                print(f"  [{idx}/{sample_size}] ⚠️ {img.name} -> Error de API: {result['error']}")
                time.sleep(2)
                continue

            total_audited += 1

            gemini_cat = result.get("categoria_sugerida", "").upper().strip()
            objeto = result.get("objeto_detectado", "Desconocido")
            confianza = result.get("confianza", 0)
            justificacion = result.get("justificacion", "")

            is_match = (gemini_cat == cat)
            if is_match:
                total_matches += 1
                print(f"  [{idx}/{sample_size}] ✅ {img.name} -> Coincide: {gemini_cat} ({objeto}) [{confianza}%]")
            else:
                print(f"  [{idx}/{sample_size}] ⚠️ DISCORDANCIA: {img.name}")
                print(f"       Etiqueta Humana: {cat}")
                print(f"       Gemini Sugiere:  {gemini_cat} ({objeto})")
                print(f"       Motivo:          {justificacion}")

                discordances.append({
                    "archivo": img.name,
                    "ruta": str(img),
                    "categoria_dataset": cat,
                    "categoria_gemini": gemini_cat,
                    "objeto": objeto,
                    "justificacion": justificacion,
                    "confianza": confianza
                })

                if auto_clean:
                    target_move_dir = DISCARDED_DIR / cat
                    target_move_dir.mkdir(parents=True, exist_ok=True)
                    img.rename(target_move_dir / img.name)
                    print(f"       -> Movida a {target_move_dir}")

            # Respetar rate limits de la API
            time.sleep(3.0)

    accuracy_dataset = (total_matches / total_audited * 100) if total_audited > 0 else 0

    print("\n" + "=" * 65)
    print("📊 RESUMEN FINAL DE LA AUDITORÍA CON GEMINI")
    print(f"  Imágenes auditadas : {total_audited}")
    print(f"  Coincidencias (✅) : {total_matches}")
    print(f"  Discordancias (⚠️) : {len(discordances)}")
    print(f"  Tasa de Concordancia: {accuracy_dataset:.1f}%")
    print("=" * 65)

    # Generar Reporte en Markdown
    report_content = f"""# 📑 Reporte de Auditoría de Dataset con IA Maestra (Gemini)

**Fecha:** {time.strftime('%Y-%m-%d %H:%M:%S')}  
**Metodología:** Teacher-Student Knowledge Distillation / Dataset Auditing  
**Modelo Maestro:** Google Gemini 3.6 Flash  
**Dataset Auditado:** `model_training/dataset/`  

---

## 📈 Métricas Globales
- **Total imágenes auditadas:** {total_audited}
- **Coincidencias (Aprobadas por Maestro):** {total_matches}
- **Discordancias detectadas:** {len(discordances)}
- **Tasa de Calidad / Concordancia:** **{accuracy_dataset:.1f}%**

---

## ⚠️ Detalle de Discordancias e Imágenes Ruidosas
Las siguientes imágenes fueron marcadas por el modelo maestro como potencialmente mal etiquetadas o ambiguas:

| Archivo | Cat. en Dataset | Cat. Sugerida (Gemini) | Objeto Detectado | Justificación |
| :--- | :--- | :--- | :--- | :--- |
"""
    for d in discordances:
        report_content += f"| `{d['archivo']}` | **{d['categoria_dataset']}** | **{d['categoria_gemini']}** | {d['objeto']} | {d['justificacion']} |\n"

    report_content += """
---
> 💡 **Nota Metodológica para Tesis:**  
> La utilización de un modelo fundacional de gran escala (Gemini Vision) como supervisor externo permite filtrar inconsistencias humanas en el dataset perimetral, aumentando la robustez y generalización del modelo ligero (MobileNetV2).
"""

    with open(REPORT_FILE, "w", encoding="utf-8") as f:
        f.write(report_content)

    print(f"\n📄 Reporte generado exitosamente en:\n   {REPORT_FILE}")

if __name__ == "__main__":
    # 20 muestras por categoría según los requisitos del protocolo de auditoría
    main(samples_per_cat=20, auto_clean=False)
