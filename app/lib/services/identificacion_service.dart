import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
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

/// Se lanza cuando no hay conexión disponible para completar el análisis
/// (WF-14).
class SinConexionException implements Exception {}

/// Punto único donde se resuelve "¿qué residuo es este?".
class IdentificacionService {
  Future<WasteItem> identificar({required String imagePath}) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw ErrorProcesamientoException();
      }

      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      final prompt = '''
      Eres un experto ambiental colombiano. Analiza la imagen y determina qué residuo es.
      Clasifícalo ESTRICTAMENTE en una de estas categorías colombianas: PELIGROSO, INDUSTRIAL, RAEE, BIOSANITARIO, RECICLABLE, ORGANICO o ORDINARIO.
      Devuelve la respuesta en formato JSON puro (sin bloques de código markdown) con esta estructura exacta:
      {
        "nombre_comun": "Nombre común del objeto (ej. Botella de vidrio)",
        "categoria": "La categoría que le asignaste",
        "descripcion": "Breve impacto ambiental y por qué se clasifica así",
        "codigo": "N/A",
        "guia_manejo": [
          "Paso corto 1 para desecharlo o limpiarlo",
          "Paso corto 2",
          "Paso corto 3"
        ]
      }
      ''';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final modelosParaIntentar = [
        'gemini-3.5-flash',
        'gemini-2.5-flash',
        'gemini-2.5-pro',
        'gemini-flash-latest'
      ];

      GenerateContentResponse? response;
      String? ultimoError;

      for (String nombreModelo in modelosParaIntentar) {
        try {
          final model = GenerativeModel(
            model: nombreModelo,
            apiKey: apiKey,
          );
          response = await model.generateContent(content);
          break; // Si funcionó, salimos del bucle con el response
        } catch (e) {
          ultimoError = e.toString();
          // Solo continuamos si es un 503 (alta demanda), 404 (no encontrado) o no soportado
          if (ultimoError.contains('503') ||
              ultimoError.contains('high demand') ||
              ultimoError.contains('not found') ||
              ultimoError.contains('not supported') ||
              ultimoError.contains('429')) {
            continue;
          }
          // Si es otro tipo de error (red caída, json malformado), tiramos la excepción normal
          rethrow;
        }
      }

      if (response == null) {
        throw ErrorProcesamientoException(ultimoError ?? 'Los servidores de Google están demasiado saturados en este momento.');
      }

      final responseText = response.text;
      
      if (responseText == null || responseText.isEmpty) {
        throw ResiduoNoIdentificadoException('La respuesta de Gemini está vacía');
      }

      // Por si Gemini incluye bloques de código markdown a pesar de la instrucción
      var cleanJson = responseText.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
        if (cleanJson.endsWith('```')) {
          cleanJson = cleanJson.substring(0, cleanJson.length - 3);
        }
      } else if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
        if (cleanJson.endsWith('```')) {
          cleanJson = cleanJson.substring(0, cleanJson.length - 3);
        }
      }

      final jsonMap = jsonDecode(cleanJson.trim());
      
      return WasteItem.fromJson(jsonMap, imagePath: imagePath);

    } catch (e) {
      if (e is ResiduoNoIdentificadoException || e is ErrorProcesamientoException) {
        rethrow;
      }
      // Cualquier otro error de red, parsing o modelo lo tomamos como procesamiento fallido
      throw ErrorProcesamientoException(e.toString());
    }
  }
}
