# Fuentes y atribución del dataset de EcoResiduos (v3)

Este documento contiene la atribución bibliográfica, las licencias verificadas y los enlaces directos de los repositorios y datasets utilizados para construir el conjunto de imágenes de **EcoResiduos** conforme a la **Resolución 2184 de 2019**.

---

## Datasets utilizados

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
| `objeto_` | **Fotos por objeto (v3)**: Wikimedia Commons, Openverse (Flickr y otros) y CODD | Ver `url` de cada foto en `fuentes_individuales.csv`. CODD: [data.mendeley.com/datasets/wds85kt64j/3](https://data.mendeley.com/datasets/wds85kt64j/3) | Solo licencias que permiten obras derivadas: `CC0`, dominio público, `CC BY`, `CC BY-SA`, `CC BY-NC`, `CC BY-NC-SA`. CODD: `CC BY 4.0`. Licencia de cada foto en `fuentes_individuales.csv` | Autores individuales en `fuentes_individuales.csv`. CODD: Demetriou, D., Mavromatidis, P., Petrou, M. y Nicolaides, D. (2023). *Construction and Demolition Waste Object Detection Dataset (CODD)*. Mendeley Data, v3. doi:10.17632/wds85kt64j.3 | 1.002 fotos en las 8 categorías (detalle abajo) |
| `web_` | **Búsqueda web (versiones anteriores)** | Sin registro | **Sin licencia ni autor registrados.** Salieron de `buscar_imagenes_web.py` (buscador de imágenes) y no quedaron en `fuentes_individuales.csv` | Sin referencia | 1.781 fotos: RCD (397), PELIGROSO (370), RIESGO_BIOLOGICO (348), ORGANICO (242), RAEE (202), ORDINARIO (129), FONDO (93) |

---

## Metadatos por imagen (Wikimedia, Unsplash y fotos por objeto)

Todas las fotos provenientes de Wikimedia Commons, Unsplash y las fotos por objeto (`objeto_`) están registradas de forma individual en el archivo [fuentes_individuales.csv](fuentes_individuales.csv) con las siguientes columnas:
- `archivo`: Nombre del archivo guardado en el dataset.
- `categoria`: Categoría asignada.
- `url`: Página de la imagen original (Wikimedia, Flickr, Mendeley) o enlace directo al archivo.
- `autor`: Nombre o usuario del fotógrafo / creador.
- `licencia`: Licencia específica declarada en el repositorio.
- `titulo`: Título original o descripción del recurso.

---

## Fotos por objeto (v3)

Para que el modelo vea **todos los objetos** de cada categoría, la v3 parte de una lista de 99 objetos
([taxonomia_objetos.py](taxonomia_objetos.py)) sacada de `app/lib/data/guia_categorias.dart` y de la norma
que cita cada categoría. El proceso fue:

1. `descargar_por_objeto.py` baja candidatas de cada objeto desde categorías curadas de Wikimedia Commons y
   búsquedas en Openverse, con su URL, autor y licencia. `descargar_codd.py` recorta fragmentos de RCD del
   dataset CODD (etiquetados por expertos en una planta de reciclaje).
2. `generar_hojas_objeto.py` arma hojas numeradas y cada candidata se revisó **a ojo**: solo entra si es una
   fotografía real donde el objeto (u otro de la misma categoría) es el sujeto principal. Se rechazaron
   ilustraciones, renders, anuncios, piezas de museo, escenas dominadas por personas o maquinaria, objetos de
   otra categoría y casi duplicados. De los recortes de CODD entran como máximo 25 por objeto para que el
   fondo de la banda transportadora no se vuelva una pista.
3. `integrar_por_objeto.py` copia las aprobadas como `objeto_<objeto>_<n>.jpg` y registra su atribución.

Fotos aprobadas por objeto:

| Categoría | Objetos (fotos aprobadas) |
| :--- | :--- |
| **APROVECHABLE** | botella_pet (11), envase_pead (11), tapas_plasticas (18), envase_plastico_rigido (5), carton (16), papel_archivo (6), periodico_revistas (6), botella_vidrio (7), frasco_vidrio (10), lata_aluminio (23), lata_hojalata (9), chatarra_metalica (7), tetra_pak (11) |
| **ORGANICO** | cascara_banano (14), cascara_citricos (7), restos_verduras (6), restos_comida (10), compost (11), borra_cafe (7), bolsita_te (6), cascaras_huevo (8), fruta_podrida (9), hojas_secas (17), cesped_cortado (0), podas_jardin (3) |
| **ORDINARIO** | papel_higienico_usado (5), servilletas_sucias (11), panal_desechable (10), toalla_sanitaria (14), empaque_metalizado (4), colillas_cigarrillo (16), toalla_papel_usada (4), papel_carbon (4), barrido_piso (4), vajilla_rota (6), papel_encerado_plastificado (3) |
| **PELIGROSO** | pilas_alcalinas (13), pilas_boton (26), bateria_plomo_acido (10), aceite_motor_usado (5), pintura (7), solventes_quimicos (6), plaguicidas (11), aerosol (7), bombillo_ahorrador (20), tubo_fluorescente (8) |
| **RAEE** | celular (15), cargador_cables (14), portatil (11), computador_escritorio (14), teclado_mouse (18), tarjeta_circuito (30), tableta (9), televisor (4), monitor (10), impresora (9), nevera (9), lavadora (6), microondas (20), licuadora (10), plancha (10), equipo_audio_video (8), herramienta_electrica (9), estufa_electrica (7), pequeno_electrodomestico (19), juguete_electronico (9), chatarra_electronica (8) |
| **RCD** | concreto (10), ladrillo (9), teja (3), ceramica_baldosa (23), escombro_mixto (6), arena_grava (5), drywall (25), madera_obra (29), tierra_excavacion (4), asfalto (1), bloque_arcilla (3) |
| **RIESGO_BIOLOGICO** | jeringa_aguja (13), lanceta (4), bisturi (18), guardian_cortopunzantes (8), residuo_hospitalario (22), gasa (9), aposito_vendaje (6), algodon (16), tapabocas_usado (7), guantes_procedimiento (10) |
| **FONDO** | mesa_madera (9), mesa_cocina (11), piso_baldosa (7), piso_madera (7), pared (6), anden_calle (10), cesped_jardin (7), escritorio (4), tela_cama_sofa (17), habitacion (7), mano_vacia (5) |

**Objetos sin fotos suficientes.** En las fuentes con licencia abierta no apareció ninguna foto válida de
`cesped_cortado` (pasto cortado amontonado) y solo una de `asfalto` (trozos de asfalto como residuo). Esos dos
objetos siguen dependiendo de las fotos que ya tenía el dataset.

---

## Balance del dataset

| Categoría | Total | Fuentes (prefijo del archivo) | Fotos `web_` sin licencia registrada |
| :--- | :---: | :--- | :---: |
| **APROVECHABLE** | 689 | `realwaste` (283), `taco` (266), `objeto` (140) | 0 |
| **FONDO** | 386 | `taco` (175), `web` (93), `objeto` (90), `realwaste` (16), `wikimedia` (12) | 93 |
| **ORDINARIO** | 471 | `realwaste` (151), `web` (129), `taco` (110), `objeto` (81) | 129 |
| **ORGANICO** | 730 | `web` (242), `realwaste` (226), `voxel51` (159), `objeto` (98), `taco` (5) | 242 |
| **PELIGROSO** | 498 | `web` (370), `objeto` (113), `wikimedia` (9), `taco` (4), `trashbox` (2) | 370 |
| **RAEE** | 800 | `gizewaste` (262), `objeto` (249), `web` (202), `trashbox` (86), `wikimedia` (1) | 202 |
| **RCD** | 519 | `web` (397), `objeto` (118), `wikimedia` (4) | 397 |
| **RIESGO_BIOLOGICO** | 468 | `web` (348), `objeto` (113), `wikimedia` (4), `trashbox` (3) | 348 |
| **TOTAL** | **4.561** | 8 categorías | 1.781 |
