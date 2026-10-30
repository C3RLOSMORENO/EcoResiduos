// Validación de teléfonos y NIT. Mismas reglas que el panel
// (admin-panel/src/utils/validacion.js): si cambias una, cambia la otra.

/// Los 6 municipios del proyecto están en Santander: un fijo antiguo de 7
/// dígitos se completa con su indicativo.
const indicativoSantander = '607';

/// Pesos del dígito de verificación del NIT (algoritmo módulo 11 de la DIAN),
/// aplicados de derecha a izquierda.
const _pesosNit = [3, 7, 13, 17, 19, 23, 29, 37, 41, 43, 47, 53, 59, 67, 71];

const mensajeTelefono = 'Escribe un celular (300 123 4567), un fijo de 10 dígitos (607 634 5678), '
    'un fijo de 7 dígitos o una línea 01 8000';

final _extension = RegExp(r'^(.*?)(?:\s*(?:ext\.?|extensi[oó]n|x)\s*(\d{1,6}))?$', caseSensitive: false);

/// Teléfono colombiano según el plan de numeración de la CRC: desde 2021 los
/// fijos también tienen 10 dígitos, empezando por 60 y el indicativo.
///
/// Acepta celulares (3XX XXX XXXX), fijos de 10 dígitos (60X XXX XXXX), fijos
/// antiguos de 7 dígitos (se guardan con el indicativo 607 de Santander) y
/// líneas 01 8000 XXX XXX; con +57, espacios, puntos, guiones o paréntesis, y
/// una extensión opcional. Devuelve solo dígitos (más « ext. N»), o null si
/// el número no es válido.
String? normalizarTelefono(String valor) {
  final partes = _extension.firstMatch(valor.trim())!;
  var numero = partes.group(1)!.replaceAll(RegExp(r'[\s().-]'), '');
  final extension = partes.group(2);

  if (numero.startsWith('+57')) {
    numero = numero.substring(3);
  } else if (RegExp(r'^57\d{10}$').hasMatch(numero)) {
    numero = numero.substring(2);
  }
  if (RegExp(r'^\d{7}$').hasMatch(numero)) numero = '$indicativoSantander$numero';

  final valido = RegExp(r'^3\d{9}$').hasMatch(numero) ||
      RegExp(r'^60\d{8}$').hasMatch(numero) ||
      RegExp(r'^018000\d{6}$').hasMatch(numero);
  if (!valido) return null;
  return extension == null ? numero : '$numero ext. $extension';
}

/// Mensaje de error del teléfono para el formulario, o null si es válido.
String? validarTelefono(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return 'Escribe el teléfono';
  return normalizarTelefono(texto) == null ? mensajeTelefono : null;
}

/// Dígito de verificación de un NIT (sin el dígito) según la DIAN.
int digitoVerificacion(String base) {
  var suma = 0;
  final digitos = base.split('').reversed.toList();
  for (var i = 0; i < digitos.length; i++) {
    suma += int.parse(digitos[i]) * _pesosNit[i];
  }
  final resto = suma % 11;
  return resto > 1 ? 11 - resto : resto;
}

/// Mensaje de error del NIT, o null si es válido: 8 a 15 dígitos y, si trae
/// dígito de verificación después del guion, que coincida.
String? validarNit(String? valor) {
  final partes = (valor ?? '').replaceAll(RegExp(r'[\s.]'), '').split('-');
  final base = partes.first;
  if (!RegExp(r'^\d{8,15}$').hasMatch(base)) return 'El NIT debe tener entre 8 y 15 dígitos';
  if (partes.length > 1 && partes[1].isNotEmpty) {
    final dv = int.tryParse(partes[1]);
    if (partes[1].length != 1 || dv != digitoVerificacion(base)) {
      return 'El dígito de verificación no corresponde a este NIT. Revísalo en el RUT o escríbelo sin él';
    }
  }
  return null;
}
