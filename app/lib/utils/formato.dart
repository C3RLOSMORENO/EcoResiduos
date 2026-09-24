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

/// Cada palabra con mayúscula inicial («FLORIDABLANCA» → «Floridablanca»).
String capitalizar(String texto) => texto
    .toLowerCase()
    .split(' ')
    .map((p) => p.isEmpty || const {'de', 'del', 'y'}.contains(p) ? p : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

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
