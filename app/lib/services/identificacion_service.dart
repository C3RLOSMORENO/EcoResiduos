import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/waste_item.dart';

/// Se lanza cuando el modelo no alcanza el umbral de confianza o cuando
/// reconoce que la foto no muestra un residuo.
class ResiduoNoIdentificadoException implements Exception {
  ResiduoNoIdentificadoException(this.confianza, {this.sinResiduo = false, this.alternativas = const []});

  /// Confianza obtenida, en %.
  final int confianza;

  /// El modelo eligió la clase FONDO: la foto no muestra un residuo.
  final bool sinResiduo;

  /// Categorías más probables, para que la persona elija la correcta.
  final List<Alternativa> alternativas;

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
/// utilizando el modelo MobileNetV3 entrenado (ecoresiduos_model.tflite).
class IdentificacionService {
  /// Confianza mínima (en %) para aceptar la categoría que detecta el modelo.
  static const umbralConfianza = 40;

  /// Desde esta confianza (en %) el resultado se muestra como «Muy probable».
  static const confianzaAlta = 85;

  /// Clase del modelo para fotos sin residuo.
  static const _claseFondo = 'FONDO';

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

  /// Identifica el residuo en la imagen de forma 100% offline.
  ///
  /// Promedia la predicción de varias vistas de la misma foto (recorte central,
  /// espejo, foto completa y acercamiento): un encuadre o una luz desfavorable
  /// en una sola vista ya no cambia el resultado.
  Future<WasteItem> identificar({required String imagePath}) async {
    try {
      await _inicializar();

      final file = File(imagePath);
      if (!await file.exists()) {
        throw ErrorProcesamientoException('El archivo de imagen no existe.');
      }

      final decodedImage = img.decodeImage(await file.readAsBytes());
      if (decodedImage == null) {
        throw ErrorProcesamientoException('No se pudo decodificar la imagen.');
      }

      // La orientación EXIF se corrige antes de recortar: las fotos del celular
      // llegan giradas.
      final probabilidades = _promedio([
        for (final vista in _vistas(img.bakeOrientation(decodedImage))) _inferir(vista),
      ]);

      final ranking = List.generate(probabilidades.length, (i) => i)
        ..sort((a, b) => probabilidades[b].compareTo(probabilidades[a]));
      final categoria = _labels![ranking.first].toUpperCase();
      final confianza = _porcentaje(probabilidades[ranking.first]);
      final alternativas = [
        for (final i in ranking.skip(1))
          if (_labels![i].toUpperCase() != _claseFondo && _porcentaje(probabilidades[i]) >= _minimoAlternativa)
            Alternativa(categoria: _labels![i].toUpperCase(), confianza: _porcentaje(probabilidades[i])),
      ].take(_maxAlternativas).toList();

      if (categoria == _claseFondo) {
        throw ResiduoNoIdentificadoException(confianza, sinResiduo: true);
      }
      if (confianza < umbralConfianza) {
        throw ResiduoNoIdentificadoException(
          confianza,
          alternativas: [
            Alternativa(categoria: categoria, confianza: confianza),
            ...alternativas,
          ],
        );
      }

      return WasteItem(
        nombre: nombreDe(categoria),
        categoria: categoria,
        confianza: confianza,
        imagenPath: imagePath,
        alternativas: alternativas,
      );
    } catch (e) {
      if (e is ResiduoNoIdentificadoException || e is ErrorProcesamientoException) {
        rethrow;
      }
      throw ErrorProcesamientoException('Fallo al analizar el residuo: $e');
    }
  }

  /// Nombre descriptivo de un código de categoría del modelo.
  static String nombreDe(String categoria) => _nombres[categoria.toUpperCase()] ?? 'Residuo identificado';

  /// Probabilidad mínima (en %) para ofrecer una categoría como alternativa.
  static const _minimoAlternativa = 10;
  static const _maxAlternativas = 2;

  static int _porcentaje(double p) => (p * 100).clamp(0, 100).round();

  /// Vistas de 224×224 de la misma foto.
  static List<img.Image> _vistas(img.Image foto) {
    const lado = 224;
    final corto = foto.width < foto.height ? foto.width : foto.height;

    img.Image recorte(double fraccion) {
      final tam = (corto * fraccion).round();
      final recortada = img.copyCrop(
        foto,
        x: (foto.width - tam) ~/ 2,
        y: (foto.height - tam) ~/ 2,
        width: tam,
        height: tam,
      );
      return img.copyResize(recortada, width: lado, height: lado, interpolation: img.Interpolation.average);
    }

    final central = recorte(1);
    return [
      central,
      img.flipHorizontal(img.Image.from(central)),
      // La foto completa, como en el entrenamiento, por si el recorte deja
      // fuera parte del residuo.
      img.copyResize(foto, width: lado, height: lado, interpolation: img.Interpolation.average),
      recorte(0.75),
    ];
  }

  /// Probabilidades softmax de una vista. El modelo trae su propia capa de
  /// reescalado, así que recibe los píxeles en [0, 255].
  List<double> _inferir(img.Image vista) {
    final input = [
      List.generate(
        vista.height,
        (y) => List.generate(vista.width, (x) {
          final pixel = vista.getPixel(x, y);
          return [pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble()];
        }),
      ),
    ];
    final output = [List.filled(_labels!.length, 0.0)];
    _interpreter!.run(input, output);
    return [for (final p in output[0]) (p as num).toDouble()];
  }

  static List<double> _promedio(List<List<double>> predicciones) => [
    for (var i = 0; i < predicciones.first.length; i++)
      predicciones.map((p) => p[i]).reduce((a, b) => a + b) / predicciones.length,
  ];

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
