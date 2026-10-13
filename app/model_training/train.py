"""Entrena el clasificador de residuos y lo exporta a TensorFlow Lite.

Estructura esperada:
    dataset/<CATEGORIA>/*.jpg          fotos de entrenamiento (80 %) y validación (20 %)
    dataset_prueba/<CATEGORIA>/*.jpg   opcional: fotos reales de celular que el modelo
                                       nunca ve al entrenar; es la métrica que importa

Genera ecoresiduos_model.tflite y labels.txt, más matriz_confusion.png y
reporte_entrenamiento.txt para revisar qué categorías se confunden. El modelo
incluye su propia capa de reescalado: la app le pasa los píxeles en [0, 255].
"""

import os
import sys
from pathlib import Path

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'

import numpy as np
import tensorflow as tf
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.utils.class_weight import compute_class_weight

SCRIPT_DIR = Path(__file__).resolve().parent
DATASET_DIR = SCRIPT_DIR / 'dataset'
PRUEBA_DIR = SCRIPT_DIR / 'dataset_prueba'
OUTPUT_MODEL = SCRIPT_DIR / 'ecoresiduos_model.tflite'
OUTPUT_LABELS = SCRIPT_DIR / 'labels.txt'
OUTPUT_MATRIZ = SCRIPT_DIR / 'matriz_confusion.png'
OUTPUT_REPORTE = SCRIPT_DIR / 'reporte_entrenamiento.txt'

IMG_SIZE = (224, 224)
BATCH_SIZE = 32
SEMILLA = 42
EPOCAS_CABEZA = 12
EPOCAS_AJUSTE = 15
CAPAS_A_AJUSTAR = 60

# Categorías de la app según la Resolución 2184 de 2019, más FONDO para fotos sin residuo.
CATEGORIAS = {'APROVECHABLE', 'FONDO', 'ORDINARIO', 'ORGANICO', 'PELIGROSO', 'RAEE', 'RCD', 'RIESGO_BIOLOGICO'}

AUMENTO = tf.keras.Sequential([
    tf.keras.layers.RandomFlip('horizontal'),
    tf.keras.layers.RandomRotation(0.08),
    tf.keras.layers.RandomZoom((-0.25, 0.1)),
    tf.keras.layers.RandomTranslation(0.1, 0.1),
    tf.keras.layers.RandomBrightness(0.25, value_range=(0, 255)),
    tf.keras.layers.RandomContrast(0.25),
])


def cargar(directorio, subconjunto=None, mezclar=True):
    """Lee las fotos de una carpeta por categoría como lotes con etiqueta one-hot.

    Con subconjunto ('training' o 'validation') toma su parte de la división
    80/20; sin él, la carpeta completa.
    """
    return tf.keras.utils.image_dataset_from_directory(
        directorio,
        validation_split=0.2 if subconjunto else None,
        subset=subconjunto,
        seed=SEMILLA,
        image_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        label_mode='categorical',
        shuffle=mezclar,
    )


def construir_modelo(num_clases):
    """MobileNetV3Large preentrenada en ImageNet con una cabeza nueva.

    Devuelve el modelo y la base, congelada, para descongelarla en el ajuste fino.
    """
    base = tf.keras.applications.MobileNetV3Large(
        input_shape=IMG_SIZE + (3,),
        include_top=False,
        weights='imagenet',
        include_preprocessing=True,
    )
    base.trainable = False

    entradas = tf.keras.Input(shape=IMG_SIZE + (3,))
    x = base(entradas, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    salidas = tf.keras.layers.Dense(num_clases, activation='softmax')(x)
    return tf.keras.Model(entradas, salidas), base


def pesos_por_clase(dataset, num_clases):
    """Peso de cada categoría para que las que tienen menos fotos cuenten igual."""
    etiquetas = np.concatenate([np.argmax(y, axis=1) for _, y in dataset])
    pesos = compute_class_weight('balanced', classes=np.arange(num_clases), y=etiquetas)
    return dict(enumerate(pesos))


def evaluar(modelo, dataset, nombres, titulo):
    """Devuelve el reporte de precisión por categoría y la matriz de confusión."""
    reales, predichas = [], []
    for x, y in dataset:
        reales.extend(np.argmax(y, axis=1))
        predichas.extend(np.argmax(modelo.predict(x, verbose=0), axis=1))

    reporte = classification_report(reales, predichas, labels=range(len(nombres)), target_names=nombres, digits=3, zero_division=0)
    matriz = confusion_matrix(reales, predichas, labels=range(len(nombres)))
    return f'=== {titulo} ===\n{reporte}\n', matriz


def guardar_matriz(matriz, nombres, titulo):
    """Dibuja la matriz de confusión normalizada por fila en matriz_confusion.png."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt

    normalizada = matriz / np.maximum(matriz.sum(axis=1, keepdims=True), 1)
    fig, ax = plt.subplots(figsize=(9, 8))
    ax.imshow(normalizada, cmap='Greens', vmin=0, vmax=1)
    ax.set_xticks(range(len(nombres)), nombres, rotation=45, ha='right')
    ax.set_yticks(range(len(nombres)), nombres)
    ax.set_xlabel('Predicha')
    ax.set_ylabel('Real')
    ax.set_title(titulo)
    for i in range(len(nombres)):
        for j in range(len(nombres)):
            ax.text(j, i, matriz[i, j], ha='center', va='center', color='white' if normalizada[i, j] > 0.5 else 'black')
    fig.tight_layout()
    fig.savefig(OUTPUT_MATRIZ, dpi=150)


def exportar_tflite(modelo):
    """Convierte el modelo a TensorFlow Lite con la optimización por defecto.

    Si la conversión directa falla, lo exporta antes como SavedModel.
    """
    try:
        convertidor = tf.lite.TFLiteConverter.from_keras_model(modelo)
        convertidor.optimizations = [tf.lite.Optimize.DEFAULT]
        return convertidor.convert()
    except Exception as e:
        print(f'  from_keras_model falló ({e}); exporto vía SavedModel')
        carpeta = SCRIPT_DIR / 'modelo_guardado'
        modelo.export(str(carpeta))
        convertidor = tf.lite.TFLiteConverter.from_saved_model(str(carpeta))
        convertidor.optimizations = [tf.lite.Optimize.DEFAULT]
        return convertidor.convert()


def comprobar_tflite(modelo, dataset):
    """El .tflite debe recibir [1, 224, 224, 3] en [0, 255] y coincidir con el modelo de Keras."""
    interprete = tf.lite.Interpreter(model_path=str(OUTPUT_MODEL))
    interprete.allocate_tensors()
    entrada = interprete.get_input_details()[0]
    salida = interprete.get_output_details()[0]
    assert list(entrada['shape']) == [1, *IMG_SIZE, 3], f"Entrada inesperada: {entrada['shape']}"
    assert entrada['dtype'] == np.float32, f"Tipo de entrada inesperado: {entrada['dtype']}"

    x, _ = next(iter(dataset))
    coincidencias = 0
    total = min(16, x.shape[0])
    for i in range(total):
        imagen = x[i:i + 1].numpy().astype(np.float32)
        interprete.set_tensor(entrada['index'], imagen)
        interprete.invoke()
        coincidencias += int(np.argmax(interprete.get_tensor(salida['index'])) == np.argmax(modelo.predict(imagen, verbose=0)))
    print(f'✅ TFLite: entrada {list(entrada["shape"])} float32, coincide con Keras en {coincidencias}/{total} imágenes')
    if coincidencias < total * 0.9:
        print('⚠️  El .tflite no coincide con el modelo de Keras: NO lo copies a la app.')


def main():
    """Entrena en dos fases, evalúa, exporta el .tflite y comprueba que coincida con Keras."""
    if not DATASET_DIR.exists():
        print(f"❌ No se encontró la carpeta '{DATASET_DIR}'.")
        return
    desconocidas = sorted(d.name for d in DATASET_DIR.iterdir() if d.is_dir() and d.name not in CATEGORIAS)
    if desconocidas:
        print(f"❌ Carpetas que no son categorías de la norma: {desconocidas}. Usa: {sorted(CATEGORIAS)}")
        return

    entrenamiento = cargar(DATASET_DIR, 'training')
    validacion = cargar(DATASET_DIR, 'validation')
    nombres = entrenamiento.class_names
    print(f'✅ Categorías ({len(nombres)}): {nombres}')

    pesos = pesos_por_clase(entrenamiento, len(nombres))
    print(f'⚖️  Pesos por clase: { {nombres[i]: round(p, 2) for i, p in pesos.items()} }')
    tabla_pesos = tf.constant([pesos[i] for i in range(len(nombres))], dtype=tf.float32)
    autotune = tf.data.AUTOTUNE
    entrenamiento_aumentado = entrenamiento.map(
        lambda x, y: (AUMENTO(x, training=True), y, tf.gather(tabla_pesos, tf.argmax(y, axis=1))),
        num_parallel_calls=autotune,
    ).prefetch(autotune)
    validacion = validacion.cache().prefetch(autotune)

    modelo, base = construir_modelo(len(nombres))
    parada = tf.keras.callbacks.EarlyStopping(monitor='val_accuracy', patience=4, restore_best_weights=True)

    print('🧠 Fase 1: entrenando la cabeza con la base congelada...')
    modelo.compile(optimizer=tf.keras.optimizers.Adam(1e-3), loss='categorical_crossentropy', metrics=['accuracy'])
    modelo.fit(entrenamiento_aumentado, validation_data=validacion, epochs=EPOCAS_CABEZA, callbacks=[parada])

    print(f'🔧 Fase 2: ajuste fino de las últimas {CAPAS_A_AJUSTAR} capas...')
    base.trainable = True
    for capa in base.layers[:-CAPAS_A_AJUSTAR]:
        capa.trainable = False
    for capa in base.layers:
        if isinstance(capa, tf.keras.layers.BatchNormalization):
            capa.trainable = False
    modelo.compile(
        optimizer=tf.keras.optimizers.Adam(1e-5),
        loss=tf.keras.losses.CategoricalCrossentropy(label_smoothing=0.1),
        metrics=['accuracy'],
    )
    modelo.fit(entrenamiento_aumentado, validation_data=validacion, epochs=EPOCAS_AJUSTE, callbacks=[parada])

    texto, matriz = evaluar(modelo, validacion, nombres, 'Validación (20 % del dataset)')
    titulo_matriz = 'Validación'
    if PRUEBA_DIR.exists():
        texto_prueba, matriz = evaluar(modelo, cargar(PRUEBA_DIR, mezclar=False), nombres, 'Prueba con fotos reales')
        texto += texto_prueba
        titulo_matriz = 'Fotos reales de prueba'
    print(texto)
    OUTPUT_REPORTE.write_text(texto, encoding='utf-8')
    guardar_matriz(matriz, nombres, titulo_matriz)

    print('💾 Exportando a TensorFlow Lite...')
    OUTPUT_MODEL.write_bytes(exportar_tflite(modelo))
    comprobar_tflite(modelo, validacion)
    OUTPUT_LABELS.write_text(''.join(f'{n}\n' for n in nombres), encoding='utf-8')

    print('🎉 Listo. Copia estos dos archivos a app/assets/models/:')
    print(f'  1. {OUTPUT_MODEL}')
    print(f'  2. {OUTPUT_LABELS}')
    print(f'Revisa {OUTPUT_MATRIZ.name} para ver qué categorías se confunden.')


if __name__ == '__main__':
    main()
