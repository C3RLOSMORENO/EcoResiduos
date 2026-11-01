import '../theme/eco_colors.dart';

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

const _unidadesCortas = {
  'KG': 'kg',
  'TON': 't',
  'UNIDADES': 'unidades',
  'LITROS': 'L',
  'GALONES': 'galones',
  'CANECAS': 'canecas',
  'M3': 'm³',
};

/// Etiqueta legible de una categoría de la base de datos.
String etiquetaCategoria(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'Sin categoría';
  return catLabel[raw.trim().toUpperCase()] ?? raw;
}

/// Etiqueta legible de un estado de solicitud o postulación.
String etiquetaEstado(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  return estadoLabel[raw.trim().toUpperCase()] ?? raw;
}

/// Unidad de medida en minúscula para acompañar una cifra («120 kg»).
String unidadCorta(String unidad) => _unidadesCortas[unidad.toUpperCase()] ?? unidad.toLowerCase();

/// Cifra sin decimales innecesarios y con coma decimal («12», «2,5»).
String formatoNumero(double valor) {
  if (valor == valor.truncateToDouble()) return valor.toStringAsFixed(0);
  return valor.toStringAsFixed(1).replaceAll('.', ',');
}

/// Cantidad con su propia unidad («120 kg», «3 unidades»).
String formatoCantidad(double cantidad, String unidad) => '${formatoNumero(cantidad)} ${unidadCorta(unidad)}';

/// Entero con punto de miles («1250000» → «1.250.000»).
String separarMiles(int valor) {
  final digitos = valor.abs().toString();
  final miles = StringBuffer(valor < 0 ? '-' : '');
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) miles.write('.');
    miles.write(digitos[i]);
  }
  return miles.toString();
}

/// Pesos colombianos («$ 1.250.000»).
String formatoPesos(int valor) => '\$ ${separarMiles(valor)}';

/// Distancia en kilómetros con un decimal («3,2 km»).
String formatoDistancia(double km) => '${km.toStringAsFixed(1).replaceAll('.', ',')} km';

/// Fecha corta del estilo «12 sep».
String fechaCorta(DateTime fecha) {
  final local = fecha.toLocal();
  return '${local.day} ${_meses[local.month - 1]}';
}

/// Tiempo transcurrido del estilo «hace 2 h» o «ayer».
String tiempoRelativo(DateTime? fecha, {DateTime? ahora}) {
  if (fecha == null) return '';
  final diferencia = (ahora ?? DateTime.now()).difference(fecha.toLocal());
  if (diferencia.inMinutes < 1) return 'ahora';
  if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
  if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
  if (diferencia.inDays == 1) return 'ayer';
  if (diferencia.inDays < 7) return 'hace ${diferencia.inDays} días';
  if (diferencia.inDays < 14) return 'hace 1 semana';
  return fechaCorta(fecha);
}

const _siglas = {
  'S.A.S.', 'S.A.S', 'SAS',
  'S.A.', 'S.A',
  'E.S.P.', 'E.S.P', 'ESP',
  'E.U.', 'E.U', 'LTDA', 'LTDA.', 'C.I.', 'C.I',
  'BIC', 'NIT', 'CDMB', 'AMB', 'CAS',
  'RAEE', 'RCD', 'RESPEL', 'PQRS', 'IPS', 'EPS',
};

const _conectores = {
  'de', 'del', 'la', 'las', 'el', 'los', 'y', 'e', 'o', 'u', 'en', 'a', 'para', 'por', 'con', 'sin',
};

final _tieneLetras = RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]');
final _partesPalabra = RegExp(
  r'^([(\[«"\x27]*?)([^(\[«"\x27\])»",;:!?]+(?:\.[^(\[«"\x27\])»",;:!?]+)*\.?)([\])»",;:!?]*)$',
);

String _capitalizarPalabra(String palabra, {required bool esPrimera}) {
  if (palabra.isEmpty) return palabra;
  final m = _partesPalabra.firstMatch(palabra);
  final prefijo = m != null ? m.group(1)! : '';
  final nucleo = m != null ? m.group(2)! : palabra;
  final sufijo = m != null ? m.group(3)! : '';
  final mayus = nucleo.toUpperCase();
  if (_siglas.contains(mayus)) return '$prefijo$mayus$sufijo';
  final minus = nucleo.toLowerCase();
  if (minus == 'giron') return '${prefijo}Girón$sufijo';
  if (!esPrimera && _conectores.contains(minus)) return '$prefijo$minus$sufijo';
  return '$prefijo${minus[0].toUpperCase()}${minus.substring(1)}$sufijo';
}

/// Cada palabra con mayúscula inicial («FLORIDABLANCA» → «Floridablanca»,
/// «RECICLAJES DEL ORIENTE S.A.S.» → «Reciclajes del Oriente S.A.S.»).
String capitalizar(String texto) {
  if (texto.isEmpty) return texto;
  final palabras = texto.split(' ');
  return [
    for (var i = 0; i < palabras.length; i++) _capitalizarPalabra(palabras[i], esPrimera: i == 0),
  ].join(' ');
}

/// Normaliza nombres propios o razones sociales que vienen completamente en
/// mayúsculas o minúsculas desde la base de datos, respetando los que ya tienen
/// combinación de mayúsculas y minúsculas (como «EcoPilas»).
String formatoNombre(String texto) {
  final limpio = texto.trim();
  if (limpio.isEmpty || !_tieneLetras.hasMatch(limpio)) return limpio;
  if (limpio == limpio.toUpperCase() || limpio == limpio.toLowerCase()) {
    return capitalizar(limpio);
  }
  return limpio;
}

/// Convierte textos escritos completamente en mayúsculas a formato de oración
/// («CAJAS DE CARTÓN EN PORTERÍA» → «Cajas de cartón en portería»), conservando
/// siglas conocidas (RAEE, RESPEL, S.A.S., CDMB…) y dejando intactos los textos
/// que ya usan mayúsculas y minúsculas normalmente.
String formatoOracion(String texto) {
  final limpio = texto.trim();
  if (limpio.isEmpty || !_tieneLetras.hasMatch(limpio)) return limpio;
  if (limpio != limpio.toUpperCase()) return limpio;
  var inicioOracion = true;
  final buffer = StringBuffer();
  for (final match in RegExp(r'\S+|\s+').allMatches(limpio)) {
    final fragmento = match.group(0)!;
    if (fragmento.trim().isEmpty) {
      buffer.write(fragmento);
      continue;
    }
    final m = _partesPalabra.firstMatch(fragmento);
    final prefijo = m != null ? m.group(1)! : '';
    final nucleo = m != null ? m.group(2)! : fragmento;
    final sufijo = m != null ? m.group(3)! : '';
    final mayus = nucleo.toUpperCase();
    final cierraOracion = RegExp(r'[.!?]$').hasMatch(fragmento) && !_siglas.contains(mayus);
    if (_siglas.contains(mayus)) {
      buffer.write('$prefijo$mayus$sufijo');
    } else {
      final minus = nucleo.toLowerCase();
      if (inicioOracion && _tieneLetras.hasMatch(minus)) {
        buffer.write('$prefijo${minus[0].toUpperCase()}${minus.substring(1)}$sufijo');
      } else {
        buffer.write('$prefijo$minus$sufijo');
      }
    }
    inicioOracion = cierraOracion;
  }
  return buffer.toString();
}

/// Primera letra en mayúscula («hace 2 h» → «Hace 2 h»).
String mayusculaInicial(String texto) => texto.isEmpty ? texto : '${texto[0].toUpperCase()}${texto.substring(1)}';

/// Primera letra en minúscula para usar un nombre dentro de una frase.
String minusculaInicial(String texto) => texto.isEmpty ? texto : '${texto[0].toLowerCase()}${texto.substring(1)}';

/// Hasta dos iniciales de un nombre o razón social («Reciclajes del Oriente» → «RO»).
String iniciales(String? nombre) {
  final palabras = (nombre ?? '')
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty && p[0].toUpperCase() != p[0].toLowerCase())
      .where((p) => !const {'de', 'del', 'la', 'las', 'los', 'y'}.contains(p.toLowerCase()))
      .toList();
  if (palabras.isEmpty) return 'E';
  if (palabras.length == 1) return palabras.first[0].toUpperCase();
  return '${palabras[0][0]}${palabras[1][0]}'.toUpperCase();
}
