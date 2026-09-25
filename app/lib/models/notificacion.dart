/// Aviso de la tabla `notificaciones`. Lo crean los triggers del servidor
/// cuando cambia una solicitud o una postulación del usuario.
class Notificacion {
  const Notificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.createdAt,
    this.solicitudId,
    this.leidaAt,
  });

  factory Notificacion.fromMap(Map<String, dynamic> map) => Notificacion(
    id: (map['id'] as num).toInt(),
    tipo: (map['tipo'] ?? '').toString().toUpperCase(),
    titulo: (map['titulo'] ?? '').toString(),
    solicitudId: (map['solicitud_id'] as num?)?.toInt(),
    leidaAt: map['leida_at'] != null ? DateTime.tryParse(map['leida_at'].toString()) : null,
    createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
  );

  final int id;
  final String tipo;
  final String titulo;
  final int? solicitudId;
  final DateTime? leidaAt;
  final DateTime createdAt;

  bool get leida => leidaAt != null;

  Notificacion marcadaComoLeida() => Notificacion(
    id: id,
    tipo: tipo,
    titulo: titulo,
    solicitudId: solicitudId,
    leidaAt: leidaAt ?? DateTime.now(),
    createdAt: createdAt,
  );
}
