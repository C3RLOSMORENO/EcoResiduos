import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/waste_item.dart';

/// Se lanza cuando el modelo no alcanza el umbral de confianza.
class ResiduoNoIdentificadoException implements Exception {
  ResiduoNoIdentificadoException(this.confianza);

  /// Confianza obtenida, en %.
  final int confianza;

  @override
  String toString() => 'Confianza insuficiente ($confianza %)';
}

/// Se lanza cuando ocurre un fallo al procesar la imagen.
class ErrorProcesamientoException implements Exception {
  final String? message;
  ErrorProcesamientoException([this.message]);

  @override
  String toString() => message ?? 'Error de procesamiento';
}

/// Servicio de Inteligencia Artificial que ejecuta inferencia LOCAL en el dispositivo
/// utilizando el modelo MobileNetV2 entrenado (ecoresiduos_model.tflite).
class IdentificacionService {
  /// Confianza mínima (en %) para aceptar la categoría que detecta el modelo.
  static const umbralConfianza = 30;

  /// Desde esta confianza (en %) el resultado se muestra como «Muy probable».
  static const confianzaAlta = 85;

  // El modelo se carga una sola vez y se comparte entre análisis.
  static Interpreter? _interpreter;
  static List<String>? _labels;

  Future<void> _inicializar() async {
    if (_interpreter != null && _labels != null) return;

    try {
      _interpreter = await Interpreter.fromAsset('assets/models/ecoresiduos_model.tflite');

      final labelsRaw = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelsRaw.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    } catch (e) {
      throw ErrorProcesamientoException('Error al cargar el modelo de IA local: $e');
    }
  }

  /// Identifica el residuo en la imagen de forma 100% offline
  Future<WasteItem> identificar({required String imagePath}) async {
    try {
      await _inicializar();

      final file = File(imagePath);
      if (!await file.exists()) {
        throw ErrorProcesamientoException('El archivo de imagen no existe.');
      }

      final imageBytes = await file.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        throw ErrorProcesamientoException('No se pudo decodificar la imagen.');
      }

      // 1. Corregir orientación EXIF (crítico para fotos tomadas con el celular)
      final orientedImage = img.bakeOrientation(decodedImage);

      // 2. Recortar al centro para hacer la imagen cuadrada antes de redimensionar.
      // Esto evita que las fotos 16:9 se aplasten/deformen al forzarlas a 224x224.
      final size = orientedImage.width < orientedImage.height ? orientedImage.width : orientedImage.height;
      final x = (orientedImage.width - size) ~/ 2;
      final y = (orientedImage.height - size) ~/ 2;
      final croppedImage = img.copyCrop(orientedImage, x: x, y: y, width: size, height: size);

      // 3. Preprocesamiento: redimensionar a 224x224 (tamaño de entrada de MobileNetV2)
      final resizedImage = img.copyResize(croppedImage, width: 224, height: 224);

      // Convertir imagen a tensor [1, 224, 224, 3] en rango [0, 255] (Requerido por MobileNetV3)
      final input = List.generate(
        1,
        (_) => List.generate(
          224,
          (y) => List.generate(224, (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          }),
        ),
      );

      final numClasses = _labels!.length;
      // Salida: [1, numClasses] con las probabilidades softmax
      final output = List.filled(1 * numClasses, 0.0).reshape([1, numClasses]);

      _interpreter!.run(input, output);

      final probabilities = (output[0] as List).map((e) => (e as num).toDouble()).toList();

      int maxIndex = 0;
      double maxProb = probabilities[0];
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      final confidencePercent = (maxProb * 100).clamp(0, 100).round();

      if (confidencePercent < umbralConfianza) {
        throw ResiduoNoIdentificadoException(confidencePercent);
      }

      final categoria = _labels![maxIndex].toUpperCase();
      return WasteItem(
        nombre: _nombres[categoria] ?? 'Residuo identificado',
        categoria: categoria,
        confianza: confidencePercent,
        imagenPath: imagePath,
      );
    } catch (e) {
      if (e is ResiduoNoIdentificadoException || e is ErrorProcesamientoException) {
        rethrow;
      }
      throw ErrorProcesamientoException('Fallo al analizar el residuo: $e');
    }
  }

  static const _nombres = {
    'APROVECHABLE': 'Residuo aprovechable',
    'ORGANICO': 'Residuo orgánico',
    'ORDINARIO': 'Residuo ordinario',
    'RAEE': 'Residuo electrónico (RAEE)',
    'PELIGROSO': 'Residuo peligroso',
    'RIESGO_BIOLOGICO': 'Residuo de riesgo biológico',
    'RCD': 'Residuo de construcción (RCD)',
  };
}
