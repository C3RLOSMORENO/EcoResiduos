import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/waste_item.dart';

/// Se lanza cuando el análisis no logra reconocer el residuo con
/// suficiente confianza (WF-12).
class ResiduoNoIdentificadoException implements Exception {
  final String? message;
  ResiduoNoIdentificadoException([this.message]);
}

/// Se lanza cuando ocurre un fallo al procesar la imagen (WF-13).
class ErrorProcesamientoException implements Exception {
  final String? message;
  ErrorProcesamientoException([this.message]);
}

/// Se lanza cuando no hay conexión disponible para completar el análisis (WF-14).
class SinConexionException implements Exception {}

/// Servicio de Inteligencia Artificial que ejecuta inferencia LOCAL en el dispositivo
/// utilizando el modelo MobileNetV2 entrenado (ecoresiduos_model.tflite).
class IdentificacionService {
  Interpreter? _interpreter;
  List<String>? _labels;

  /// Carga el intérprete y las etiquetas en memoria (singleton / lazy load)
  Future<void> _inicializar() async {
    if (_interpreter != null && _labels != null) return;

    try {
      _interpreter = await Interpreter.fromAsset('assets/models/ecoresiduos_model.tflite');
      
      final labelsRaw = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelsRaw
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
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

      // Preprocesamiento: redimensionar a 224x224 (tamaño de entrada de MobileNetV2)
      final resizedImage = img.copyResize(decodedImage, width: 224, height: 224);

      // Convertir imagen a tensor [1, 224, 224, 3] normalizado a [0, 1]
      final input = List.generate(
        1,
        (_) => List.generate(
          224,
          (y) => List.generate(
            224,
            (x) {
              final pixel = resizedImage.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      final numClasses = _labels!.length;
      // Salida: [1, numClasses] con las probabilidades softmax
      final output = List.filled(1 * numClasses, 0.0).reshape([1, numClasses]);

      // Ejecutar inferencia en milisegundos
      _interpreter!.run(input, output);

      final probabilities = (output[0] as List).map((e) => (e as num).toDouble()).toList();

      // Encontrar la clase con mayor probabilidad
      int maxIndex = 0;
      double maxProb = probabilities[0];
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      final confidencePercent = (maxProb * 100).clamp(0, 100).round();

      // Si la confianza es menor al 30%, se considera residuo no identificado (WF-12)
      if (confidencePercent < 30) {
        throw ResiduoNoIdentificadoException('Confianza insuficiente ($confidencePercent%)');
      }

      final detectedCategory = _labels![maxIndex];
      final meta = _obtenerMetadataCategoria(detectedCategory);

      return WasteItem(
        nombre: meta['nombre']!,
        categoria: detectedCategory,
        etiquetaCategoria: detectedCategory,
        confianza: confidencePercent,
        descripcion: meta['descripcion']!,
        caracteristicas: meta['caracteristicas']!,
        pasosManejo: meta['pasosManejo'] as List<String>,
        imagenPath: imagePath,
      );

    } catch (e) {
      if (e is ResiduoNoIdentificadoException || e is ErrorProcesamientoException) {
        rethrow;
      }
      throw ErrorProcesamientoException('Fallo al analizar el residuo: $e');
    }
  }

  /// Información ambiental y guía de manejo según la normativa colombiana (Resolución 2184)
  Map<String, dynamic> _obtenerMetadataCategoria(String categoria) {
    switch (categoria.toUpperCase()) {
      case 'RECICLABLE':
        return {
          'nombre': 'Residuo Aprovechable (Reciclable)',
          'descripcion': 'Materiales limpios y secos que pueden transformarse en nueva materia prima (plásticos, metales, vidrio, papel y cartón).',
          'caracteristicas': 'Disposición: Bolsa o Caneca BLANCA',
          'pasosManejo': [
            'Limpia y enjuaga los envases para retirar restos de líquidos o alimentos.',
            'Seca completamente y aplasta botellas o cajas para reducir su volumen.',
            'Deposita en la bolsa BLANCA y entrégalo a los recicladores de oficio.',
          ],
        };

      case 'ORGANICO':
        return {
          'nombre': 'Residuo Orgánico Aprovechable',
          'descripcion': 'Restos biológicos de origen vegetal o animal ideales para procesos de compostaje y producción de abono natural.',
          'caracteristicas': 'Disposición: Bolsa o Caneca VERDE',
          'pasosManejo': [
            'Separa restos de comida, frutas, verduras, cáscaras de huevo o cuncho de café.',
            'Evita mezclar con plásticos, servilletas o empaques no biodegradables.',
            'Deposita en la bolsa VERDE o utilízalo directamente en composteras.',
          ],
        };

      case 'ORDINARIO':
        return {
          'nombre': 'Residuo No Aprovechable (Ordinario)',
          'descripcion': 'Desechos que no pueden recuperarse debido a suciedad o composiciones complejas (icopor, servilletas usadas, vasos encerados).',
          'caracteristicas': 'Disposición: Bolsa o Caneca NEGRA',
          'pasosManejo': [
            'Verifica que no contenga materiales que puedan ser aprovechados.',
            'Empaca en bolsa NEGRA herméticamente cerrada.',
            'Entrega al camión recolector del servicio de aseo convencional.',
          ],
        };

      case 'RAEE':
        return {
          'nombre': 'Residuo Electrónico (RAEE)',
          'descripcion': 'Aparatos eléctricos y electrónicos en desuso que contienen circuitos y metales pesados con alto potencial contaminante.',
          'caracteristicas': 'Disposición: Puntos Posconsumo / Gestor RAEE',
          'pasosManejo': [
            'No intentes desarmar ni romper circuitos, tarjetas o pantallas.',
            'Llévalo a un punto posconsumo autorizado (Red Verde en centros comerciales).',
            'Entrega a empresas gestoras certificadas en reciclaje de electrónicos.',
          ],
        };

      case 'PELIGROSO':
        return {
          'nombre': 'Residuo Peligroso / Posconsumo',
          'descripcion': 'Elementos corrosivos, inflamables, tóxicos o reactivos como pilas, aerosoles presurizados y medicamentos vencidos.',
          'caracteristicas': 'Disposición: Caneca ROJA o Punto Posconsumo',
          'pasosManejo': [
            'Conserva los residuos en su empaque original para evitar fugas o reacciones.',
            'No los mezcles con la basura ordinaria ni los tires al alcantarillado.',
            'Deposítalos en contenedores posconsumo especializados (Pilas con el Ambiente, Punto Azul).',
          ],
        };

      case 'BIOSANITARIO':
        return {
          'nombre': 'Residuo Biosanitario (Riesgo Biológico)',
          'descripcion': 'Materiales con posible presencia de patógenos infecciosos como tapabocas, jeringas, apósitos, gasas o guantes quirúrgicos.',
          'caracteristicas': 'Disposición: Bolsa ROJA (Símbolo Biológico)',
          'pasosManejo': [
            'Coloca inmediatamente en bolsa ROJA gruesa debidamente rotulada.',
            'Si contiene agujas u objetos cortopunzantes, deposítalos en recipientes rígidos (guardianes).',
            'Entrega a empresas de recolección especializada para incineración controlada.',
          ],
        };

      case 'INDUSTRIAL':
        return {
          'nombre': 'Residuo Industrial / Construcción (RCD)',
          'descripcion': 'Materiales derivados de obras, demoliciones o procesos industriales (escombros, concreto, ladrillos, llantas y bidones químicos).',
          'caracteristicas': 'Disposición: Escombrera / Gestor Industrial',
          'pasosManejo': [
            'Acopia los escombros o residuos en un sitio seco y delimitado.',
            'No los abandones en espacio público, humedales ni canales de agua.',
            'Contrata un servicio de volqueta autorizado hacia una escombrera o gestor RCD certificado.',
          ],
        };

      default:
        return {
          'nombre': 'Residuo Identificado',
          'descripcion': 'Residuo clasificado mediante inteligencia artificial.',
          'caracteristicas': 'Revisar normativa local',
          'pasosManejo': [
            'Clasifica el residuo de acuerdo a las recomendaciones locales.',
            'Consulta el punto de recolección más cercano en la app.',
          ],
        };
    }
  }

  /// Libera recursos del modelo si es necesario
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
