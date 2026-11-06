"""Evalúa el modelo que usa la app (.tflite) y genera la matriz de confusión.

No reentrena: carga app/assets/models/ecoresiduos_model.tflite y labels.txt
y clasifica una carpeta de fotos con la estructura <CATEGORIA>/*.jpg.

Uso:
    python evaluar_modelo.py                       # dataset_prueba/ (fotos que el modelo no vio)
    python evaluar_modelo.py --carpeta otra/       # cualquier carpeta por categoría
    python evaluar_modelo.py --validacion          # el 20 % de validación de dataset/

--validacion repite la misma división 80/20 de train.py (semilla 42). Solo es
válida si dataset/ tiene exactamente las mismas fotos que cuando se entrenó
el modelo; si se agregaron o quitaron fotos, la división cambia y se cuelan
fotos de entrenamiento, lo que infla los resultados.

Genera en resultados_evaluacion/:
    matriz_confusion.png        para el documento (300 dpi, cantidades y % por fila)
    matriz_confusion.csv        la misma matriz en números, para una tabla en Word
    reporte_evaluacion.txt      precisión, exhaustividad (recall) y F1 por categoría
"""

import argparse
import os
import sys
from pathlib import Path

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'

import numpy as np
import tensorflow as tf
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix

SCRIPT_DIR = Path(__file__).resolve().parent
MODELOS = SCRIPT_DIR.parent / 'assets' / 'models'
SALIDA = SCRIPT_DIR / 'resultados_evaluacion'
IMG_SIZE = (224, 224)
SEMILLA = 42

# Nombres como se muestran en la app.
ETIQUETAS = {
    'APROVECHABLE': 'Aprovechable',
    'FONDO': 'Sin residuo',
    'ORDINARIO': 'Ordinario',
    'ORGANICO': 'Orgánico',
    'PELIGROSO': 'Peligroso',
    'RAEE': 'RAEE',
    'RCD': 'RCD',
    'RIESGO_BIOLOGICO': 'Riesgo biológico',
}


def cargar_fotos(carpeta, validacion):
    return tf.keras.utils.image_dataset_from_directory(
        carpeta,
        validation_split=0.2 if validacion else None,
        subset='validation' if validacion else None,
        seed=SEMILLA,
        image_size=IMG_SIZE,
        batch_size=32,
        label_mode='int',
        shuffle=validacion,  # la división de train.py depende de este barajado
    )


def predecir(interprete, imagenes):
    entrada = interprete.get_input_details()[0]
    salida = interprete.get_output_details()[0]
    predichas = []
    for imagen in imagenes:
        interprete.set_tensor(entrada['index'], imagen[np.newaxis].astype(np.float32))
        interprete.invoke()
        predichas.append(int(np.argmax(interprete.get_tensor(salida['index']))))
    return predichas


def dibujar(matriz, nombres, titulo, ruta):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt

    porcentaje = matriz / np.maximum(matriz.sum(axis=1, keepdims=True), 1)
    fig, ax = plt.subplots(figsize=(9, 8))
    imagen = ax.imshow(porcentaje, cmap='Greens', vmin=0, vmax=1)
    barra = fig.colorbar(imagen, ax=ax, fraction=0.046, pad=0.04)
    barra.set_label('Proporción de la categoría real')
    ax.set_xticks(range(len(nombres)), nombres, rotation=45, ha='right')
    ax.set_yticks(range(len(nombres)), nombres)
    ax.set_xlabel('Categoría predicha por el modelo')
    ax.set_ylabel('Categoría real')
    ax.set_title(titulo)
    for i in range(len(nombres)):
        for j in range(len(nombres)):
            color = 'white' if porcentaje[i, j] > 0.5 else 'black'
            ax.text(j, i, f'{matriz[i, j]}\n{porcentaje[i, j]:.0%}', ha='center', va='center', fontsize=8, color=color)
    fig.tight_layout()
    fig.savefig(ruta, dpi=300)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--carpeta', type=Path, help='carpeta con subcarpetas por categoría')
    parser.add_argument('--validacion', action='store_true', help='usar el 20 %% de validación de dataset/')
    args = parser.parse_args()

    carpeta = args.carpeta or (SCRIPT_DIR / ('dataset' if args.validacion else 'dataset_prueba'))
    if not carpeta.exists():
        print(f'No existe {carpeta}. Crea dataset_prueba/<CATEGORIA>/ con fotos o usa --validacion.')
        return

    claves = (MODELOS / 'labels.txt').read_text(encoding='utf-8').split()
    fotos = cargar_fotos(carpeta, args.validacion)
    if fotos.class_names != claves:
        print(f'Las carpetas {fotos.class_names} no coinciden con labels.txt {claves}.')
        return

    interprete = tf.lite.Interpreter(model_path=str(MODELOS / 'ecoresiduos_model.tflite'))
    interprete.allocate_tensors()

    reales, predichas = [], []
    for x, y in fotos:
        reales.extend(y.numpy().tolist())
        predichas.extend(predecir(interprete, x.numpy()))

    nombres = [ETIQUETAS.get(c, c) for c in claves]
    etiquetas = range(len(claves))
    matriz = confusion_matrix(reales, predichas, labels=etiquetas)
    exactitud = accuracy_score(reales, predichas)
    origen = 'validación (20 % de dataset)' if args.validacion else carpeta.name
    reporte = classification_report(
        reales, predichas, labels=etiquetas, target_names=nombres, digits=3, zero_division=0
    )

    SALIDA.mkdir(exist_ok=True)
    texto = f'Modelo: ecoresiduos_model.tflite\nFotos: {origen}, {len(reales)} en total\n'
    texto += f'Exactitud global: {exactitud:.1%}\n\n{reporte}'
    (SALIDA / 'reporte_evaluacion.txt').write_text(texto, encoding='utf-8')

    filas = ['Real \\ Predicha;' + ';'.join(nombres)]
    filas += [f'{n};' + ';'.join(str(v) for v in fila) for n, fila in zip(nombres, matriz)]
    (SALIDA / 'matriz_confusion.csv').write_text('\n'.join(filas) + '\n', encoding='utf-8-sig')

    dibujar(matriz, nombres, f'Matriz de confusión ({len(reales)} fotos, exactitud {exactitud:.1%})',
            SALIDA / 'matriz_confusion.png')

    print(texto)
    print(f'Archivos en {SALIDA}')


if __name__ == '__main__':
    main()
