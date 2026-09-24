/// Los 6 municipios de Santander donde opera EcoResiduos.
const municipiosAdmitidos = [
  'Bucaramanga',
  'Floridablanca',
  'Girón',
  'Piedecuesta',
  'Barrancabermeja',
  'Sabana de Torres',
];

/// Devuelve el municipio admitido que corresponde a [texto] sin importar
/// mayúsculas ni tildes, o null si no es uno de los 6.
String? municipioAdmitido(String? texto) {
  if (texto == null) return null;
  final buscado = _normalizar(texto);
  for (final municipio in municipiosAdmitidos) {
    if (_normalizar(municipio) == buscado) return municipio;
  }
  return null;
}

String _normalizar(String texto) => texto
    .trim()
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u');
