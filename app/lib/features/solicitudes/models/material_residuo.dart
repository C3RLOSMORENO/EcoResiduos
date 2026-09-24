/// Modelo de dominio fuertemente tipado para la tabla 'public.materiales_residuos'.
class MaterialResiduo {
  final int id;
  final String? codigo;
  final String nombreComun;
  final String? descripcion;
  final String categoria;
  final String? guiaManejo;
  final String? subcategoria;
  final String? advertenciaManejo;
  final DateTime? createdAt;

  const MaterialResiduo({
    required this.id,
    this.codigo,
    required this.nombreComun,
    this.descripcion,
    required this.categoria,
    this.guiaManejo,
    this.subcategoria,
    this.advertenciaManejo,
    this.createdAt,
  });

  /// Crea una instancia a partir de un mapa proveniente de la base de datos o API.
  factory MaterialResiduo.fromMap(Map<String, dynamic> map) {
    return MaterialResiduo(
      id: (map['id'] as num).toInt(),
      codigo: map['codigo']?.toString(),
      nombreComun: (map['nombre_comun'] ?? '').toString(),
      descripcion: map['descripcion']?.toString(),
      categoria: (map['categoria'] ?? '').toString(),
      guiaManejo: map['guia_manejo']?.toString(),
      subcategoria: map['subcategoria']?.toString(),
      advertenciaManejo: map['advertencia_manejo']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  /// Serializa la entidad a un mapa para operaciones de persistencia.
  Map<String, dynamic> toMap({bool forInsert = false}) {
    final map = <String, dynamic>{
      if (codigo != null) 'codigo': codigo,
      'nombre_comun': nombreComun,
      if (descripcion != null) 'descripcion': descripcion,
      'categoria': categoria,
      if (guiaManejo != null) 'guia_manejo': guiaManejo,
      if (subcategoria != null) 'subcategoria': subcategoria,
      if (advertenciaManejo != null) 'advertencia_manejo': advertenciaManejo,
    };
    if (!forInsert && id != 0) {
      map['id'] = id;
    }
    return map;
  }

  /// Retorna una copia con campos modificados.
  MaterialResiduo copyWith({
    int? id,
    String? codigo,
    String? nombreComun,
    String? descripcion,
    String? categoria,
    String? guiaManejo,
    String? subcategoria,
    String? advertenciaManejo,
    DateTime? createdAt,
  }) {
    return MaterialResiduo(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      nombreComun: nombreComun ?? this.nombreComun,
      descripcion: descripcion ?? this.descripcion,
      categoria: categoria ?? this.categoria,
      guiaManejo: guiaManejo ?? this.guiaManejo,
      subcategoria: subcategoria ?? this.subcategoria,
      advertenciaManejo: advertenciaManejo ?? this.advertenciaManejo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Indica si este residuo cuenta con una advertencia técnica registrada.
  bool get tieneAdvertencia => advertenciaManejo?.trim().isNotEmpty ?? false;

  /// Pasos de manejo seguro: una línea de `guia_manejo` por paso, sin la
  /// numeración que traiga el texto.
  List<String> get pasosManejo => (guiaManejo ?? '')
      .split(RegExp(r'\r?\n'))
      .map((linea) => linea.replaceFirst(RegExp(r'^\s*(\d+[.)-]|[-•*])\s*'), '').trim())
      .where((linea) => linea.isNotEmpty)
      .toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MaterialResiduo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
