# Fuentes y Atribución del Dataset - EcoResiduos (v2)

Este documento contiene la atribución bibliográfica, las licencias verificadas y los enlaces directos de los repositorios y datasets utilizados para construir el conjunto de imágenes de **EcoResiduos** conforme a la **Resolución 2184 de 2019**.

---

## Tabla de Datasets Utilizados

| Prefijo en Archivo | Nombre del Dataset | URL Directa al Dataset | Licencia Verificada (Cita Textual) | Referencia / Cita Bibliográfica | Categorías e Imágenes Aportadas |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `realwaste_` | **RealWaste** | [archive.ics.uci.edu/dataset/908/realwaste](https://archive.ics.uci.edu/dataset/908/realwaste) | Creative Commons Attribution 4.0 International (`CC BY 4.0`) | *RealWaste: A Dataset for Waste Classification*, UCI Machine Learning Repository, 2023. | APROVECHABLE (329), ORGANICO (226), ORDINARIO (151), FONDO (100) |
| `taco_` | **TACO (Trash Annotations in Context)** | [github.com/pedropro/TACO](https://github.com/pedropro/TACO) | Creative Commons Attribution 4.0 International (`CC BY 4.0`) | Proença, P. F., & Simões, P. (2020). *TACO: Trash Annotations in Context for Litter Detection*. arXiv preprint arXiv:2003.06975. | APROVECHABLE (321), FONDO (176), ORDINARIO (110), ORGANICO (5), PELIGROSO (4) |
| `gizewaste_` | **GIZ E-Waste Database** | [huggingface.co/datasets/GIZ/E-Waste-Database](https://huggingface.co/datasets/GIZ/E-Waste-Database) | Creative Commons Attribution 4.0 International (`CC BY 4.0`) | Deutsche Gesellschaft für Internationale Zusammenarbeit (GIZ) GmbH. *E-Waste Image Database for Circular Economy & Recycling*, 2023. | RAEE (299) |
| `trashbox_` | **TrashBox** | [huggingface.co/datasets/arijitx/trashbox](https://huggingface.co/datasets/arijitx/trashbox) | Creative Commons Attribution-NonCommercial 4.0 International (`CC BY-NC 4.0`) | *TrashBox: An Image Dataset for Waste Detection & Classification*, 2021. | RAEE (346), PELIGROSO (27), RIESGO_BIOLOGICO (17) |
| `voxel51_` | **Voxel51 Food Waste Dataset** | [huggingface.co/datasets/Voxel51/food-waste-dataset](https://huggingface.co/datasets/Voxel51/food-waste-dataset) | MIT License (`MIT`) | Voxel51 Inc. *Food Waste Object Detection and Classification Dataset*, 2023. | ORGANICO (159) |
| `openimages_` | **Open Images Dataset V7** | [storage.googleapis.com/openimages/web/index.html](https://storage.googleapis.com/openimages/web/index.html) | Creative Commons Attribution 2.0 Generic (`CC BY 2.0`) / Creative Commons Attribution 4.0 International (`CC BY 4.0`) | Kuznetsova, A., et al. (2020). *The Open Images Dataset V4*. International Journal of Computer Vision (IJCV). | RAEE (3) |
| `wikimedia_` | **Wikimedia Commons** | [commons.wikimedia.org](https://commons.wikimedia.org) | Creative Commons Attribution-ShareAlike (`CC BY-SA 4.0`, `CC BY 3.0`, `CC0` / Public Domain). Ver detalle en `fuentes_individuales.csv` | Varios autores de Wikimedia Commons. Detalle individual en `app/model_training/fuentes_individuales.csv`. | FONDO (28), PELIGROSO (16), RCD (15), RIESGO_BIOLOGICO (13), RAEE (2) |
| `unsplash_` | **Unsplash** | [unsplash.com](https://unsplash.com) | Unsplash License (Uso comercial y no comercial libre sin permiso explícito requerido). Ver detalle en `fuentes_individuales.csv` | Varios fotógrafos de Unsplash. Detalle individual en `app/model_training/fuentes_individuales.csv`. | RCD (11) |

---

## Metadatos Individuales (Wikimedia y Unsplash)

Todas las fotos provenientes de Wikimedia Commons y Unsplash están registradas de forma individual en el archivo [fuentes_individuales.csv](fuentes_individuales.csv) con las siguientes columnas:
- `archivo`: Nombre del archivo guardado en el dataset.
- `categoria`: Categoría asignada.
- `url`: Enlace directo a la imagen original de alta resolución.
- `autor`: Nombre o usuario del fotógrafo / creador.
- `licencia`: Licencia específica declarada en el repositorio.
- `titulo`: Título original o descripción del recurso.

---

## Balance General del Dataset

| Categoría | Total Imágenes | Fuentes Utilizadas | Porcentaje Fuente Mayor (Máx. 60%) |
| :--- | :---: | :--- | :---: |
| **APROVECHABLE** | 650 | `realwaste` (329), `taco` (321) | 51% |
| **FONDO** | 304 | `taco` (176), `realwaste` (100), `wikimedia` (28) | 58% |
| **ORDINARIO** | 261 | `realwaste` (151), `taco` (110) | 58% |
| **ORGANICO** | 390 | `realwaste` (226), `voxel51` (159), `taco` (5) | 58% |
| **PELIGROSO** | 47 | `trashbox` (27), `wikimedia` (16), `taco` (4) | 57% |
| **RAEE** | 650 | `trashbox` (346), `gizewaste` (299), `openimages` (3), `wikimedia` (2) | 53% |
| **RCD** | 26 | `wikimedia` (15), `unsplash` (11) | 58% |
| **RIESGO_BIOLOGICO** | 30 | `trashbox` (17), `wikimedia` (13) | 57% |
| **TOTAL** | **2.358** | *8 categorías conformadas* | — |
