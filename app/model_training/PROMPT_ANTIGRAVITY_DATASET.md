# Tarea: armar el dataset de imágenes del clasificador de residuos de EcoResiduos

## Contexto
EcoResiduos es una app colombiana que clasifica residuos con un modelo MobileNetV3 (TFLite) a partir de una foto tomada con el celular. El modelo actual falla mucho porque se entrenó con fotos de estudio y con categorías mal asignadas. Tu trabajo es **conseguir, filtrar, organizar y verificar imágenes reales**. No entrenas el modelo.

Trabaja solo dentro de `app/model_training/`. Lee primero `organizar_dataset.py`, `train.py` y `auditar_dataset_con_gemini.py` para entender la estructura.

## Categorías (Resolución 2184 de 2019 y normas asociadas)
Usa EXACTAMENTE estos nombres de carpeta. Ningún otro nombre es válido.

| Carpeta | Qué SÍ va | Qué NO va |
|---|---|---|
| `APROVECHABLE` | Botellas plásticas PET/PEAD, envases plásticos rígidos, tetra pak, cajas y láminas de cartón, papel de archivo, periódico, revistas, frascos y botellas de vidrio, latas de aluminio y acero, chatarra metálica pequeña | Papel sucio o engrasado, servilletas usadas, envases con comida adentro |
| `ORGANICO` | Cáscaras de fruta, restos de verduras y hortalizas, borra de café, bolsitas de té, cáscaras de huevo, restos de comida cruda, hojas secas, pasto, podas | Comida dentro de empaques o recipientes |
| `ORDINARIO` | Papel higiénico usado, servilletas y toallas de papel sucias, pañales, toallas sanitarias, empaques metalizados de paquetes/snacks, icopor sucio, colillas, barrido | Cualquier cosa limpia y reciclable |
| `PELIGROSO` | Pilas (AA, AAA, botón), baterías de carro y de plomo-ácido, aerosoles, envases de pintura, solventes y aceite de motor, plaguicidas, bombillos ahorradores y tubos fluorescentes, medicamentos vencidos | Celulares, cargadores o aparatos completos (van en RAEE) |
| `RAEE` | Celulares, cargadores, cables, computadores, portátiles, teclados, mouse, tarjetas de circuito, tabletas, televisores y pantallas, electrodomésticos pequeños, herramientas eléctricas, juguetes electrónicos | Pilas o baterías sueltas (van en PELIGROSO) |
| `RCD` | Escombros de construcción y demolición: concreto y mortero partido, ladrillo roto, tejas, baldosa y cerámica rota, arena con cemento, grava, drywall, asfalto, madera de formaleta | Botellas, latas, cartón o envases (aunque estén en una obra), llantas |
| `RIESGO_BIOLOGICO` | Jeringas, agujas, lancetas, bisturís, guardianes, gasas y algodones con sangre, apósitos usados, guantes de látex/nitrilo usados, tapabocas usados, material de laboratorio contaminado | Medicamentos (van en PELIGROSO), guantes nuevos en su caja |
| `FONDO` | Fotos SIN residuo: mesas, pisos, mesones de cocina, manos vacías, paredes, andenes, pasto sin basura, canecas vacías | Cualquier foto donde se vea un residuo |

**Casos ambiguos: EXCLÚYELOS.** No los metas en ninguna carpeta: ropa, zapatos, cubiertos plásticos, vasos de papel, icopor limpio, llantas, colchones, muebles, montones mezclados de basura sin un objeto dominante.

## Fuentes permitidas (solo con licencia que permita uso académico)
En este orden de prioridad:
1. **Open Images V7** vía FiftyOne (`fiftyone.zoo.load_zoo_dataset("open-images-v7", classes=[...], label_types=["detections"])`). Recorta las detecciones con margen del 15 % cuando el objeto ocupe menos del 30 % de la imagen. Clases útiles: Bottle, Tin can, Beer, Mobile phone, Laptop, Computer keyboard, Computer mouse, Syringe, Glove, Brick, Banana, Apple, Orange, Egg, Envelope, Box, Light bulb, Television.
2. **TACO** (tacodataset.org, CC BY 4.0): basura real en calles y parques. Recorta cada anotación y mapéala con la tabla de arriba.
3. **RealWaste** (UCI Machine Learning Repository, CC BY 4.0).
4. **Roboflow Universe** y **Kaggle**: solo datasets con licencia explícita (CC BY, CC0, MIT, Apache). Busca: construction debris / rubble / demolition waste, medical waste / syringe, e-waste, battery, fruit peel / food waste.
5. **Pexels y Unsplash** (su licencia lo permite), solo para `FONDO` y para completar `RCD` si faltan fotos.

**PROHIBIDO:** raspar Google Imágenes, Bing, Pinterest, bancos de imágenes con marca de agua o cualquier sitio sin licencia clara.

## Reglas de calidad (cada imagen debe cumplirlas TODAS)
- Foto real. Nada de dibujos, íconos, renders 3D, capturas de pantalla, infografías ni fotos de producto sobre fondo blanco perfecto de catálogo (se permiten hasta un 10 % por carpeta).
- Lado corto de 224 px o más. Nada borroso, sobreexpuesto ni casi negro.
- Un residuo principal que ocupe al menos el 30 % de la imagen.
- Sin marcas de agua, sin texto encima, sin personas identificables como sujeto principal.
- Sin duplicados: calcula el hash perceptual (`imagehash.phash`) de todo el dataset, incluidas las fotos que ya existen, y elimina las que queden a distancia de Hamming de 6 o menos. Si existe `dataset_prueba/`, ninguna imagen puede repetirse allí.
- Guarda todo en JPG con calidad 90, redimensionado a un lado mayor de máximo 800 px.
- Nombre del archivo: `<fuente>_<clase-original>_<n>.jpg` (ej. `openimages_syringe_0042.jpg`) para que se pueda rastrear.

## Cantidades objetivo
- Entre 500 y 800 imágenes por categoría. **Ninguna por encima de 800.** Si sobran, quédate con las más variadas: distintos fondos, luces y ángulos.
- `FONDO`: entre 300 y 500.
- Prioridad: `RCD` y `RIESGO_BIOLOGICO` son las más escasas, así que empieza por ellas.

## Pasos (haz uno a la vez y no pases al siguiente sin terminar el anterior)

### Paso 0: Revisar lo que ya existe
Si `dataset/` tiene carpetas con nombres viejos, **no las borres sin revisarlas**:
- `BIOSANITARIO` → renómbrala a `RIESGO_BIOLOGICO`.
- `RECICLABLE` → mueve su contenido a `APROVECHABLE`.
- `INDUSTRIAL` → NO la renombres a RCD. Casi todo son botellas y cartón de una planta de reciclaje (WaRP-C). Mueve máximo 600 de esas a `APROVECHABLE`, borra lo demás (llantas, cosas que no son escombros) y elimina la carpeta.
Luego aplica las reglas de calidad y de categorías de arriba también a las imágenes que ya existían: saca de `ORDINARIO` la ropa, los zapatos y los cubiertos, y saca de `RAEE` las pilas sueltas.

### Paso 1: Descargar a una zona temporal
Descarga todo en `app/model_training/descargas_crudas/<fuente>/`, nunca directo en `dataset/`.

### Paso 2: Filtrar y copiar
Aplica las reglas de calidad y copia a `dataset/<CATEGORIA>/` solo lo que pase.

### Paso 3: Revisar visualmente (obligatorio)
Para cada categoría genera hojas de contacto de 10×10 miniaturas con el nombre de archivo debajo en `app/model_training/revision/<CATEGORIA>_<n>.jpg`. **Ábrelas y míralas todas tú mismo.** Elimina toda imagen que no cumpla la tabla de categorías o las reglas de calidad. Anota cuántas eliminaste y por qué.

### Paso 4: Auditoría con Gemini
Ejecuta `python auditar_dataset_con_gemini.py` (la clave ya está configurada; nunca la imprimas ni la copies a ningún archivo). Toma al menos 20 muestras por categoría. En cada discordancia, mira la imagen y decide: si Gemini tiene razón, muévela o elimínala; si no, déjala. **Meta: menos de 5 % de discordancias en cada categoría.** Si alguna la supera, vuelve al paso 3 con esa categoría.

### Paso 5: Informe
Crea `app/model_training/FUENTES.md` con:
- Una tabla por fuente con URL, licencia, cita requerida e imágenes aportadas a cada categoría.
- El total final por categoría.
- Las imágenes eliminadas en la revisión visual y en la auditoría, con sus motivos.
- Las categorías que quedaron por debajo de 500 y cuántas fotos faltan (esas las completaré con fotos propias).

## Límites estrictos
- No modifiques nada fuera de `app/model_training/`. No toques `app/assets/models/`, `app/lib/`, `.env`, claves ni credenciales.
- No borres ni modifiques `dataset_prueba/` ni `videos/`.
- No entrenes el modelo, no reemplaces el `.tflite` y no hagas commits.
- Agrega `descargas_crudas/` y `revision/` al `.gitignore` de `app/model_training/`.
- Si una fuente exige registro, pago o aceptar términos que yo tenga que firmar, sáltala y anótalo en el informe.
- Si dudas en qué categoría va una imagen, exclúyela. Es mejor tener menos imágenes que imágenes mal etiquetadas.

## Al terminar, respóndeme con
1. El total por categoría (antes y después).
2. La tasa de discordancia de la auditoría por categoría.
3. Las categorías que me toca completar con fotos propias y cuántas faltan.
