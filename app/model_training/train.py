import os
import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D, Dropout
from tensorflow.keras.models import Model
import matplotlib.pyplot as plt

# 1. Configuración de parámetros
DATASET_DIR = 'dataset' # Aquí deben ir las carpetas con las fotos
BATCH_SIZE = 32
IMG_SIZE = (224, 224) # Tamaño ideal para MobileNetV2
EPOCHS = 10 # Para empezar, luego puedes subir a 20 o 30

def check_dataset():
    if not os.path.exists(DATASET_DIR):
        print(f"❌ Error: No se encontró la carpeta '{DATASET_DIR}'.")
        print("Debes crearla y colocar dentro subcarpetas por cada categoría.")
        return False
    
    categories = [d for d in os.listdir(DATASET_DIR) if os.path.isdir(os.path.join(DATASET_DIR, d))]
    if len(categories) == 0:
        print(f"❌ Error: La carpeta '{DATASET_DIR}' está vacía.")
        return False
        
    print(f"✅ Categorías encontradas: {categories}")
    return True

def main():
    if not check_dataset():
        return

    print("🚀 Iniciando preparación de datos...")
    
    # 2. Aumento de Datos (Data Augmentation)
    # Esto rota, hace zoom y voltea las imágenes para que el modelo aprenda mejor
    # con menos fotos.
    datagen = ImageDataGenerator(
        rescale=1./255,
        rotation_range=20,
        width_shift_range=0.2,
        height_shift_range=0.2,
        shear_range=0.2,
        zoom_range=0.2,
        horizontal_flip=True,
        validation_split=0.2 # 80% para entrenar, 20% para validar
    )

    train_generator = datagen.flow_from_directory(
        DATASET_DIR,
        target_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        class_mode='categorical',
        subset='training'
    )

    val_generator = datagen.flow_from_directory(
        DATASET_DIR,
        target_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        class_mode='categorical',
        subset='validation'
    )

    # Guardar las etiquetas (categorías) para usarlas en Flutter
    labels = (train_generator.class_indices)
    labels = dict((v,k) for k,v in labels.items())
    with open('labels.txt', 'w') as f:
        for i in range(len(labels)):
            f.write(f"{labels[i]}\n")
    print("✅ Archivo labels.txt generado.")

    # 3. Construir el Modelo (Transfer Learning con MobileNetV2)
    print("🧠 Descargando arquitectura MobileNetV2...")
    base_model = MobileNetV2(
        weights='imagenet', # Usa conocimientos previos de millones de imágenes
        include_top=False, 
        input_shape=IMG_SIZE + (3,)
    )

    # Congelamos las capas base para no dañar lo que ya sabe
    base_model.trainable = False

    # Añadimos nuestras propias capas al final para las categorías de residuos
    x = base_model.output
    x = GlobalAveragePooling2D()(x)
    x = Dropout(0.2)(x) # Evita el sobreentrenamiento (overfitting)
    predictions = Dense(train_generator.num_classes, activation='softmax')(x)

    model = Model(inputs=base_model.input, outputs=predictions)

    # 4. Compilar el modelo
    model.compile(optimizer='adam', 
                  loss='categorical_crossentropy', 
                  metrics=['accuracy'])

    print(f"🔥 Iniciando entrenamiento por {EPOCHS} épocas...")
    history = model.fit(
        train_generator,
        epochs=EPOCHS,
        validation_data=val_generator
    )

    # 5. Guardar y exportar a TensorFlow Lite
    print("💾 Convirtiendo modelo a TensorFlow Lite (.tflite)...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    # Optimizaciones para móvil (reduce el peso del modelo)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    with open('ecoresiduos_model.tflite', 'wb') as f:
        f.write(tflite_model)
    
    print("🎉 ¡Entrenamiento finalizado exitosamente!")
    print("Archivos generados para Flutter:")
    print(" 1. ecoresiduos_model.tflite")
    print(" 2. labels.txt")

if __name__ == '__main__':
    main()
