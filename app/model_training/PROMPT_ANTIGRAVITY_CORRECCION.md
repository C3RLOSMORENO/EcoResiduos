# Corrección del dataset de EcoResiduos: la entrega anterior NO cumple

Revisé tu entrega abriendo las hojas de contacto y midiendo el dataset con `app/model_training/verificar_dataset.py`. Salieron **21 errores**. El dataset no sirve para entrenar como está. Sigue aplicando las reglas de `PROMPT_ANTIGRAVITY_DATASET.md`; este documento las complementa y, si algo choca, manda este.

## Lo que encontré (verificado)

### Categorías con contenido equivocado
1. **FONDO son texturas, no fondos.** 386 de 400 son del dataset DTD: rayas de tela, telarañas y fibras. La app necesita mesas, pisos, mesones de cocina, andenes y manos vacías, que es lo que aparece detrás de un residuo cuando alguien toma la foto.
2. **RCD no tiene escombros reales.**
   - 317 imágenes son texturas DTD («grooved», «cracked», «potholed», «stratified»): tablas de madera, tapetes de caucho, un cojín, papas fritas, una flor, huecos en la calle.
   - Las 319 de «demolition_scrap» son texturas planas (fondos lisos amarillos o rosados, pisos de madera, muros de ladrillo) y objetos renderizados sobre blanco (clavos, alambre de cobre). No son fotos reales de escombros.
3. **APROVECHABLE tiene residuos peligrosos.** Hay aerosoles en RealWaste «metal» (ej. `realwaste_*` de las hojas APROVECHABLE_02: .041, .045, .053, .137, .154) y blísteres de medicamentos (.029, .151).
4. **RIESGO_BIOLOGICO es casi todo catálogo.** Son guantes nuevos sobre fondo blanco, manos posando con guantes, collages de varias fotos y fotos con marca de agua (shutterstock, CanStockPhoto). Casi no hay residuos usados o descartados.
5. **RAEE tiene infografías y texto.** Por ejemplo «ELECTRONIC COMPONENTS EXPLAINED», banners publicitarios, marcas de agua y fotos de personas reparando placas. Además es casi todo placas y cables: faltan celulares, cargadores, teclados, mouse, electrodomésticos y televisores.
6. **PELIGROSO es casi todo pastillas de stock.** 316 son fotos publicitarias de medicamentos, incluida una portada de guía con texto, y las baterías de «hf» son de catálogo. En total el 42 % es foto de catálogo con fondo blanco. Faltan pinturas, aceite de motor, bombillos o tubos fluorescentes y pilas usadas.
7. **ORDINARIO tiene recortes inútiles de TACO.** Hay tiras finísimas y recortes donde solo se ve pasto o piso. También incluye vasos de papel y «plastic film», que te pedí excluir por ambiguos.

### Sesgo por fuente (grave)
Cada categoría viene casi entera de una sola fuente con un estilo propio:
- ORGANICO, APROVECHABLE y ORDINARIO: RealWaste, con el mismo piso gris de concreto.
- RAEE y RIESGO_BIOLOGICO: TrashBox, con fotos web y de stock.

El modelo aprendería a reconocer **el fondo y el estilo de la fuente**, no el residuo. Por eso ahora ninguna fuente puede aportar más del 60 % de una categoría.

### Afirmaciones que no son ciertas en tu informe
- «0 duplicados con `dataset_prueba/`»: esa carpeta no existe.
- «Revisión visual»: generaste las hojas, pero no eliminaste ninguna imagen. Las imágenes de arriba lo demuestran.
- La auditoría con Gemini no se ejecutó.
- `FUENTES.md` cita «Battery Hazard Dataset» y «Demolition & Construction Scrap» con un enlace genérico a `huggingface.co/datasets`, sin identificador. No se pueden verificar. Tampoco está confirmada la licencia de TrashBox («MIT / CC BY-NC 4.0» no es una licencia concreta).
- En `auditar_dataset_con_gemini.py` reemplazaste los modelos por versiones antiguas (`gemini-1.5-flash`, `gemini-2.0-flash`) que pueden estar retiradas.

## Qué debes hacer

### Paso 1: Borrar lo que no sirve
- Elimina **todas** las imágenes `dtd_*` y `demolition_*` de todas las categorías. No se reutilizan.
- Elimina de todas las categorías: infografías, imágenes con texto encima, marcas de agua, collages, fotos de gente reparando o posando, y renders o texturas planas.
- Mueve los aerosoles de RealWaste de APROVECHABLE a PELIGROSO. Elimina los blísteres de medicamentos.
- En ORDINARIO elimina vasos de papel, «plastic film» y todo recorte donde el residuo no ocupe al menos el 30 %.

### Paso 2: Rehacer los recortes de TACO
Recorta con un margen del 30 % alrededor de la anotación y descarta todo recorte con lado corto menor de 224 px o proporción mayor de 2,5:1. Nada de tiras.

### Paso 3: Completar cada categoría con otras fuentes
Mínimo 2 fuentes por categoría; ninguna por encima del 60 %.

| Categoría | Qué agregar | Dónde buscar |
|---|---|---|
| FONDO (300–500) | Mesas de madera y de plástico, mesones de cocina, baldosas, pisos de concreto, andenes, pasto sin basura, palma de la mano vacía, fondo de caneca vacía | Zonas SIN anotaciones de las fotos de TACO (recorta regiones que no toquen ninguna caja); hasta 100 recortes de RealWaste sin objeto (así el modelo aprende que el piso gris solo no es residuo); Pexels/Unsplash vía API guardando la URL y el autor de cada foto |
| RCD (500–800) | Ladrillo roto, trozos de concreto y mortero, baldosa y teja rota, montones de escombro en obra o en la calle, drywall roto | Dataset **CODD** (construction and demolition waste, Zenodo); datasets de Roboflow Universe de «construction waste» o «demolition waste» con licencia explícita; Wikimedia Commons, categorías «Rubble» y «Construction and demolition waste», guardando la licencia de cada imagen |
| RIESGO_BIOLOGICO | Jeringas, guantes y tapabocas **usados o tirados**, bolsas rojas, guardianes, gasas con sangre | Open Images (Syringe; Glove solo si está en basura o desechado), datasets de «medical waste» en Roboflow o Kaggle con licencia |
| RAEE | Celulares, cargadores, teclados, mouse, portátiles, televisores, controles, audífonos, electrodomésticos pequeños, todos dañados o viejos si es posible | Open Images (Mobile phone, Laptop, Computer keyboard, Computer mouse, Television, Remote control, Headphones), datasets de «e-waste» con licencia |
| PELIGROSO | Pilas usadas sueltas, baterías de carro, tarros de pintura, envases de aceite de motor, aerosoles, bombillos ahorradores y tubos fluorescentes. **Máximo 150 de medicamentos** | Aerosoles de RealWaste, TACO (aerosol, battery) con recortes nuevos, datasets de «battery waste» y «hazardous waste» con licencia |
| ORGANICO | Cáscaras, restos de comida en platos, en canecas y en la tierra; borra de café | Datasets de «food waste» y «fruit peel» con licencia (Roboflow/Kaggle), TACO (food waste) |
| APROVECHABLE / ORDINARIO | Los mismos objetos en otros fondos: mesa, cocina, calle, mano | TACO con recortes nuevos, Open Images (Bottle, Tin can) |

**Si una categoría no llega al mínimo con imágenes que cumplan, NO la rellenes con cualquier cosa.** Déjala corta y reporta cuántas faltan: yo la completo con fotos propias. Prefiero 350 imágenes correctas a 650 con basura.

### Paso 4: Nombres de archivo
El prefijo hasta el primer `_` identifica el **dataset concreto**: `realwaste_`, `taco_`, `trashbox_`, `openimages_`, `codd_`, `roboflowcdw_`, `wikimedia_`, `pexels_`. Nada de prefijos genéricos como `hf_`. Cada prefijo debe aparecer en `FUENTES.md` con su URL exacta.

### Paso 5: Verificación automática (obligatoria)
Ejecuta:
```
python verificar_dataset.py
```
Tiene que terminar con «✅ El dataset cumple los requisitos verificables». Si falla, corrige y vuelve a ejecutar.

**Prohibido** modificar `verificar_dataset.py`, sus umbrales o su lista de fuentes prohibidas, y prohibido renombrar archivos para esquivar la regla del 60 %. Si crees que un umbral está mal, dímelo en el informe, pero no lo cambies.

### Paso 6: Revisión visual real
Regenera las hojas de contacto con el dataset ya corregido. Míralas todas y crea `revision/REVISION.md` con una línea por hoja: nombre de la hoja, archivos eliminados y motivo. Si en una hoja no eliminaste nada, escribe «revisada, sin cambios». Después de eliminar, vuelve a ejecutar el paso 5.

### Paso 7: Auditoría con Gemini (ejecutada de verdad)
- Consulta los modelos disponibles con la API (`GET https://generativelanguage.googleapis.com/v1beta/models`) y usa el modelo «flash» más reciente que aparezca. No lo escribas de memoria.
- Ejecuta `auditar_dataset_con_gemini.py` con 20 muestras por categoría. La meta es menos de 5 % de discordancias por categoría.
- Si no encuentras `GEMINI_API_KEY`, **detente y avísame**. No la busques en otros archivos, no la pidas en el chat, no la imprimas y no marques la auditoría como hecha.

### Paso 8: Corregir `FUENTES.md`
Una fila por dataset con:
- URL exacta (el enlace directo al dataset, no a la página principal).
- Licencia verificada en la página del dataset, citada textualmente.
- Cita bibliográfica real e imágenes aportadas a cada categoría.

Si no pudiste verificar una licencia, **elimina esas imágenes** y anótalo. Para Pexels, Unsplash y Wikimedia, agrega un CSV (`fuentes_individuales.csv`) con archivo, URL, autor y licencia de cada imagen.

## Límites (los mismos de antes)
- Solo trabajas dentro de `app/model_training/`. No toques `app/lib/`, `app/assets/`, `.env`, claves ni credenciales. No entrenes, no reemplaces el `.tflite` y no hagas commits.
- No borres `descargas_crudas/`: puede hacer falta volver a procesar.

## Tu respuesta final debe incluir
1. La salida completa de `python verificar_dataset.py` (la tabla y la línea final).
2. El total por categoría y por fuente.
3. El porcentaje de discordancia de Gemini por categoría y el nombre del modelo usado.
4. Las categorías que quedaron por debajo del mínimo y cuántas faltan.
5. Cualquier requisito que no pudiste cumplir, dicho explícitamente. No lo escondas.
