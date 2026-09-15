# 📑 Reporte de Auditoría de Dataset con IA Maestra (Gemini)

**Fecha:** 2026-09-14 22:31:32  
**Metodología:** Teacher-Student Knowledge Distillation / Dataset Auditing  
**Modelo Maestro:** Google Gemini 3.6 Flash  
**Dataset Auditado:** `model_training/dataset/`  

---

## 📈 Métricas Globales
- **Total imágenes auditadas:** 12
- **Coincidencias (Aprobadas por Maestro):** 9
- **Discordancias detectadas:** 3
- **Tasa de Calidad / Concordancia:** **75.0%**

---

## ⚠️ Detalle de Discordancias e Imágenes Ruidosas
Las siguientes imágenes fueron marcadas por el modelo maestro como potencialmente mal etiquetadas o ambiguas:

| Archivo | Cat. en Dataset | Cat. Sugerida (Gemini) | Objeto Detectado | Justificación |
| :--- | :--- | :--- | :--- | :--- |
| `tires2_664_00064.jpg` | **INDUSTRIAL** | **RECICLABLE** | Superficie de vidrio o metal | La imagen muestra una superficie lisa y reflectante, característica de materiales como vidrio o metal, los cuales son susceptibles de aprovechamiento y reciclaje bajo la normativa colombiana. |
| `disposable_plastic_cutlery_174_Image_30.png` | **ORDINARIO** | **RECICLABLE** | Cuchara de plástico desechable | Es un objeto elaborado de material plástico rígido que, al estar limpio y seco, clasifica como residuo aprovechable para su posterior reciclaje (caneca blanca). |
| `battery_169_battery_253.jpg` | **PELIGROSO** | **RAEE** | Batería de teléfono celular | Las baterías de teléfonos móviles son componentes de residuos de aparatos eléctricos y electrónicos (RAEE) que contienen elementos químicos peligrosos y deben entregarse en puntos de recolección posconsumo específicos. |

---
> 💡 **Nota Metodológica para Tesis:**  
> La utilización de un modelo fundacional de gran escala (Gemini Vision) como supervisor externo permite filtrar inconsistencias humanas en el dataset perimetral, aumentando la robustez y generalización del modelo ligero (MobileNetV2).
