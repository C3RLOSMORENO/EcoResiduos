import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/postulacion_recoleccion.dart';
import '../../../services/archivo_pdf.dart';
import '../../../services/certificados_service.dart';
import '../../../services/fotos_service.dart';
import '../../../utils/sesion.dart';
import '../models/material_residuo.dart';
import '../models/solicitud_recoleccion.dart';

/// Contrato para las operaciones de datos del módulo de solicitudes.
abstract class SolicitudesRepository {
  /// Obtiene el catálogo completo de materiales disponibles para recolección.
  Future<List<MaterialResiduo>> getMateriales();

  /// Obtiene el ID del generador vinculado al usuario autenticado actual.
  Future<int?> getGeneradorId();

  /// Obtiene el ID del gestor vinculado al usuario autenticado actual.
  Future<int?> getGestorId();

  /// Sube la imagen local al almacenamiento de Supabase y retorna la URL pública.
  Future<String> subirFoto(String localPath);

  /// Borra una foto subida antes (al reemplazarla o si la publicación falla).
  Future<void> eliminarFoto(String? url);

  /// Inserta una nueva solicitud de recolección y retorna la entidad creada.
  Future<SolicitudRecoleccion> crearSolicitud(SolicitudRecoleccion solicitud);

  /// Actualiza los datos de una solicitud de recolección existente.
  Future<void> actualizarSolicitud(SolicitudRecoleccion solicitud);

  /// Obtiene las publicaciones creadas por el generador.
  Future<List<SolicitudRecoleccion>> getMisPublicaciones({int? generadorId});

  /// Cancela lógicamente una solicitud de recolección actualizando su estado a 'CANCELADO'.
  Future<void> cancelarSolicitud(int id);

  /// Obtiene los IDs de materiales verificados por el administrador para el
  /// gestor autenticado. Vacío si aún no tiene ninguno aprobado.
  Future<List<int>> getMaterialesAutorizadosGestor();

  /// Resume los materiales que declaró el gestor y cuántos están verificados.
  Future<EstadoMaterialesGestor> getEstadoMaterialesGestor();

  /// Materiales que el gestor tiene guardados: id → true si ya está verificado.
  Future<Map<int, bool>> getMisMateriales();

  /// Reemplaza los materiales del gestor por [materialIds]. Los nuevos quedan
  /// en verificación. Devuelve cuántos materiales nuevos agregó.
  Future<int> guardarMisMateriales(List<int> materialIds);

  /// Obtiene las solicitudes disponibles filtradas por los materiales autorizados del gestor.
  Future<List<SolicitudRecoleccion>> getSolicitudesDisponibles({List<int>? materialesAutorizados});

  /// Registra la postulación de un gestor con el valor que cobra por recoger
  /// o que paga por el material.
  Future<void> postularASolicitud({
    required int solicitudId,
    required TipoValor tipoValor,
    required int valor,
    int? gestorId,
    String? propuesta,
    ModalidadEntrega? modalidadEntrega,
  });

  /// Postulación del gestor autenticado a una solicitud, o null si no se ha postulado.
  Future<PostulacionRecoleccion?> getMiPostulacion(int solicitudId);

  /// Vuelve a leer una solicitud para mostrar su estado actual.
  Future<SolicitudRecoleccion?> getSolicitud(int id);

  /// Fecha en que la solicitud llegó a cada estado (la más reciente por estado).
  Future<Map<String, DateTime>> getHistorialEstados(int solicitudId);

  /// Obtiene las postulaciones del gestor autenticado con su solicitud.
  Future<List<PostulacionRecoleccion>> getMisPostulaciones();

  /// Cuenta, por solicitud, las propuestas pendientes y el gestor aceptado.
  Future<Map<int, ResumenPostulaciones>> getResumenPostulaciones(List<int> solicitudIds);

  /// Obtiene las postulaciones recibidas para una solicitud específica.
  Future<List<PostulacionRecoleccion>> getPostulacionesDeSolicitud(int solicitudId);

  /// Acepta atómicamente una postulación: asigna la solicitud, pasa la postulación
  /// a 'ACEPTADA' y las demás de la solicitud a 'NO_SELECCIONADA'.
  Future<void> aceptarPostulacion({required int solicitudId, required int postulacionId, required int gestorId});

  /// Descarta o rechaza una postulación concreta por parte del generador.
  Future<void> rechazarPostulacion({required int postulacionId});

  /// El gestor ambiental marca la solicitud como recolectada.
  Future<void> marcarRecolectado({required int solicitudId, int? gestorId});

  /// El gestor asignado sube el certificado en PDF y lo deja disponible para
  /// el generador. Si ya había uno, lo reemplaza.
  Future<void> cargarCertificado({required int solicitudId, required ArchivoPdf pdf, required TipoCertificado tipo});

  /// El generador confirma la recolección completada.
  Future<void> confirmarRecoleccion({required int solicitudId, int? generadorId});

  /// El generador reporta un problema durante la recolección.
  Future<void> reportarProblemaRecoleccion({required int solicitudId, required String detalle});

  /// Determina el rol del usuario autenticado ('GENERADOR' o 'GESTOR').
  Future<String> getRolUsuario();
}

/// Resumen de las postulaciones de una solicitud para las tarjetas y el Inicio.
class ResumenPostulaciones {
  const ResumenPostulaciones({this.pendientes = 0, this.gestorAceptado});

  final int pendientes;
  final String? gestorAceptado;
}

/// Materiales declarados por un gestor, su avance de verificación y el estado
/// de la empresa: sin la empresa aprobada no ve solicitudes aunque tenga
/// materiales verificados.
class EstadoMaterialesGestor {
  const EstadoMaterialesGestor({
    this.categoriasDeclaradas = const [],
    this.totalDeclarados = 0,
    this.totalVerificados = 0,
    this.estadoEmpresa = 'APROBADO',
  });

  final List<String> categoriasDeclaradas;
  final int totalDeclarados;
  final int totalVerificados;

  /// `estado_verificacion` de la empresa: PENDIENTE, APROBADO, RECHAZADO o SUSPENDIDO.
  final String estadoEmpresa;

  bool get empresaPendiente => estadoEmpresa == 'PENDIENTE';
  bool get empresaRechazada => estadoEmpresa == 'RECHAZADO';
  bool get empresaSuspendida => estadoEmpresa == 'SUSPENDIDO';
  bool get sinDeclarar => totalDeclarados == 0;
  bool get enVerificacion => totalDeclarados > 0 && totalVerificados == 0;
  bool get verificado => estadoEmpresa == 'APROBADO' && totalVerificados > 0;
}

/// Implementación del repositorio de solicitudes respaldada por Supabase.
class SupabaseSolicitudesRepository implements SolicitudesRepository {
  final SupabaseClient? client;

  SupabaseSolicitudesRepository({this.client});

  SupabaseClient? get _supabase {
    if (client != null) return client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MaterialResiduo>> getMateriales() async {
    final client = _supabase;
    if (client == null) return [];

    final List<dynamic> res = await client.from('materiales_residuos').select().order('nombre_comun', ascending: true);

    return res.map((item) => MaterialResiduo.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<int?> getGeneradorId() async {
    final client = _supabase;
    if (client == null) return null;

    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;

    final perfil = await client.from('perfiles_generador').select('id').eq('usuario_id', userId).maybeSingle();

    if (perfil == null) return null;
    return (perfil['id'] as num?)?.toInt();
  }

  @override
  Future<String> subirFoto(String localPath) {
    final client = _supabase;
    if (client == null) throw Exception('Cliente de Supabase no disponible para subir fotografía.');
    return FotosService(client: client).subir(localPath, CarpetaFoto.solicitudes);
  }

  @override
  Future<void> eliminarFoto(String? url) async {
    final client = _supabase;
    if (client == null) return;
    await FotosService(client: client).eliminar(url);
  }

  @override
  Future<SolicitudRecoleccion> crearSolicitud(SolicitudRecoleccion solicitud) async {
    final client = _supabase;
    if (client == null) throw Exception('Cliente de Supabase no disponible.');

    final insertData = solicitud.toMap(forInsert: true);
    final res = await client
        .from('solicitudes_recoleccion')
        .insert(insertData)
        .select('*, materiales_residuos(*)')
        .single();

    return SolicitudRecoleccion.fromMap(res);
  }

  @override
  Future<void> actualizarSolicitud(SolicitudRecoleccion solicitud) async {
    final client = _supabase;
    if (client == null) throw Exception('Cliente de Supabase no disponible.');
    if (solicitud.id == null) throw Exception('El ID de la solicitud es obligatorio para actualizar.');

    await client
        .from('solicitudes_recoleccion')
        .update(solicitud.toMapEdicion())
        .eq('id', solicitud.id!)
        .eq('estado', 'PUBLICADO');
  }

  @override
  Future<List<SolicitudRecoleccion>> getMisPublicaciones({int? generadorId}) async {
    final client = _supabase;
    if (client == null) return [];

    final targetGeneradorId = generadorId ?? await getGeneradorId();
    if (targetGeneradorId == null) return [];

    final List<dynamic> data = await client
        .from('solicitudes_recoleccion')
        .select('*, materiales_residuos(*)')
        .eq('generador_id', targetGeneradorId)
        .order('created_at', ascending: false);
    return data.map((item) => SolicitudRecoleccion.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> cancelarSolicitud(int id) async {
    final client = _supabase;
    if (client == null) throw Exception('Cliente de Supabase no disponible.');

    await client.rpc('cancelar_solicitud_generador', params: {'p_solicitud_id': id});
  }

  @override
  Future<List<int>> getMaterialesAutorizadosGestor() async {
    final client = _supabase;
    if (client == null) return [];

    final gestorId = await getGestorId();
    if (gestorId == null) return [];

    final List<dynamic> filas = await client
        .from('gestor_material')
        .select('material_id')
        .eq('gestor_id', gestorId)
        .eq('verificado', true);

    return filas.map((r) => (r['material_id'] as num).toInt()).toList();
  }

  @override
  Future<EstadoMaterialesGestor> getEstadoMaterialesGestor() async {
    final client = _supabase;
    if (client == null) return const EstadoMaterialesGestor();

    final userId = client.auth.currentUser?.id;
    if (userId == null) return const EstadoMaterialesGestor();

    final perfil = await client
        .from('perfiles_gestor')
        .select('id, estado_verificacion')
        .eq('usuario_id', userId)
        .maybeSingle();
    if (perfil == null) return const EstadoMaterialesGestor();

    final List<dynamic> filas = await client
        .from('gestor_material')
        .select('verificado, materiales_residuos(categoria)')
        .eq('gestor_id', (perfil['id'] as num).toInt());

    final categorias = <String>{};
    var verificados = 0;
    for (final fila in filas) {
      if (fila['verificado'] == true) verificados++;
      final categoria = fila['materiales_residuos']?['categoria']?.toString();
      if (categoria != null && categoria.isNotEmpty) categorias.add(categoria);
    }

    return EstadoMaterialesGestor(
      categoriasDeclaradas: categorias.toList(),
      totalDeclarados: filas.length,
      totalVerificados: verificados,
      estadoEmpresa: (perfil['estado_verificacion'] ?? 'APROBADO').toString().toUpperCase(),
    );
  }

  @override
  Future<Map<int, bool>> getMisMateriales() async {
    final client = _supabase;
    if (client == null) return {};

    final gestorId = await getGestorId();
    if (gestorId == null) return {};

    final List<dynamic> filas = await client
        .from('gestor_material')
        .select('material_id, verificado')
        .eq('gestor_id', gestorId);
    return {for (final f in filas) (f['material_id'] as num).toInt(): f['verificado'] == true};
  }

  @override
  Future<int> guardarMisMateriales(List<int> materialIds) async {
    final client = _supabase;
    if (client == null) throw Exception('Cliente de Supabase no disponible.');

    final respuesta = await client.rpc('actualizar_materiales_gestor', params: {'p_materiales': materialIds});
    return ((respuesta as Map?)?['nuevos'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<Map<int, ResumenPostulaciones>> getResumenPostulaciones(List<int> solicitudIds) async {
    final client = _supabase;
    if (client == null || solicitudIds.isEmpty) return {};

    final List<dynamic> filas = await client
        .from('postulaciones_recoleccion')
        .select('solicitud_id, estado, perfiles_gestor(razon_social)')
        .inFilter('solicitud_id', solicitudIds);

    final pendientes = <int, int>{};
    final aceptados = <int, String?>{};
    for (final fila in filas) {
      final id = (fila['solicitud_id'] as num).toInt();
      final estado = fila['estado']?.toString().toUpperCase();
      if (estado == 'PROPUESTA') pendientes[id] = (pendientes[id] ?? 0) + 1;
      if (estado == 'ACEPTADA') aceptados[id] = fila['perfiles_gestor']?['razon_social']?.toString();
    }

    return {
      for (final id in {...pendientes.keys, ...aceptados.keys})
        id: ResumenPostulaciones(pendientes: pendientes[id] ?? 0, gestorAceptado: aceptados[id]),
    };
  }

  @override
  Future<List<PostulacionRecoleccion>> getPostulacionesDeSolicitud(int solicitudId) async {
    final client = _supabase;
    if (client == null) return [];

    final List<dynamic> data = await client
        .from('postulaciones_recoleccion')
        .select('*, perfiles_gestor(*)')
        .eq('solicitud_id', solicitudId)
        .order('created_at', ascending: true);

    return data.map((item) => PostulacionRecoleccion.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> aceptarPostulacion({required int solicitudId, required int postulacionId, required int gestorId}) async {
    final client = _supabase;
    if (client == null) throw Exception('Cliente de Supabase no disponible.');

    await client.rpc(
      'aceptar_postulacion_recoleccion',
      params: {'p_solicitud_id': solicitudId, 'p_postulacion_id': postulacionId},
    );
  }

  @override
  Future<void> rechazarPostulacion({required int postulacionId}) async {
    final client = _supabase;
    if (client == null) throw Exception('Cliente de Supabase no disponible.');

    await client.rpc('rechazar_postulacion_recoleccion', params: {'p_postulacion_id': postulacionId});
  }

  @override
  Future<void> marcarRecolectado({required int solicitudId, int? gestorId}) async {
    final client = _supabase;
    if (client == null) throw Exception('Cliente de Supabase no disponible.');

    await client.rpc('marcar_recolectado_gestor', params: {'p_solicitud_id': solicitudId});
  }

  @override
  Future<void> cargarCertificado({
    required int solicitudId,
    required ArchivoPdf pdf,
    required TipoCertificado tipo,
  }) async {
    final client = _supabase;
    if (client == null) throw Exception('Cliente de Supabase no disponible.');

    final certificados = CertificadosService(client: client);
    final url = await certificados.subir(pdf, solicitudId: solicitudId);
    try {
      final respuesta = await client.rpc(
        'cargar_certificado_gestor',
        params: {'p_solicitud_id': solicitudId, 'p_url': url, 'p_tipo': tipo.valor},
      );
      await certificados.eliminar((respuesta as Map?)?['anterior']?.toString());
    } catch (_) {
      // Sin el registro en la solicitud el archivo queda huérfano.
      await certificados.eliminar(url);
      rethrow;
    }
  }

  @override
  Future<void> confirmarRecoleccion({required int solicitudId, int? generadorId}) async {
    final client = _supabase;
    if (client == null) throw Exception('Cliente de Supabase no disponible.');

    await client.rpc('confirmar_recoleccion_generador', params: {'p_solicitud_id': solicitudId});
  }

  @override
  Future<void> reportarProblemaRecoleccion({required int solicitudId, required String detalle}) async {
    final client = _supabase;
    if (client == null) throw Exception('Cliente de Supabase no disponible.');

    await client.rpc('reportar_problema_recoleccion', params: {'p_solicitud_id': solicitudId, 'p_detalle': detalle});
  }

  @override
  Future<List<SolicitudRecoleccion>> getSolicitudesDisponibles({List<int>? materialesAutorizados}) async {
    final client = _supabase;
    if (client == null) return [];

    final autorizados = materialesAutorizados ?? await getMaterialesAutorizadosGestor();
    if (autorizados.isEmpty) return [];

    final List<dynamic> data = await client
        .from('solicitudes_recoleccion')
        .select('*, materiales_residuos(*)')
        .eq('estado', 'PUBLICADO')
        .inFilter('material_id', autorizados)
        .order('created_at', ascending: false);

    return data.map((item) => SolicitudRecoleccion.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<int?> getGestorId() async {
    final client = _supabase;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return null;

    final perfil = await client.from('perfiles_gestor').select('id').eq('usuario_id', userId).maybeSingle();
    return (perfil?['id'] as num?)?.toInt();
  }

  @override
  Future<void> postularASolicitud({
    required int solicitudId,
    required TipoValor tipoValor,
    required int valor,
    int? gestorId,
    String? propuesta,
    ModalidadEntrega? modalidadEntrega,
  }) async {
    final client = _supabase;
    if (client == null) throw Exception('Cliente de Supabase no disponible.');

    final targetGestorId = gestorId ?? await getGestorId();
    if (targetGestorId == null) {
      throw Exception('No se encontró el perfil de gestor correspondiente para postularse.');
    }

    final postulacion = PostulacionRecoleccion(
      solicitudId: solicitudId,
      gestorId: targetGestorId,
      propuesta: propuesta,
      tipoValor: tipoValor,
      valor: valor,
      modalidadEntrega: modalidadEntrega,
    );
    await client.from('postulaciones_recoleccion').insert(postulacion.toMap(forInsert: true));
  }

  @override
  Future<PostulacionRecoleccion?> getMiPostulacion(int solicitudId) async {
    final client = _supabase;
    if (client == null) return null;

    final gestorId = await getGestorId();
    if (gestorId == null) return null;

    final fila = await client
        .from('postulaciones_recoleccion')
        .select()
        .eq('solicitud_id', solicitudId)
        .eq('gestor_id', gestorId)
        .maybeSingle();
    return fila == null ? null : PostulacionRecoleccion.fromMap(fila);
  }

  @override
  Future<Map<String, DateTime>> getHistorialEstados(int solicitudId) async {
    final client = _supabase;
    if (client == null) return {};

    final List<dynamic> filas = await client
        .from('solicitudes_historial_estados')
        .select('estado, created_at')
        .eq('solicitud_id', solicitudId)
        .order('created_at');
    return {
      for (final f in filas.cast<Map<String, dynamic>>())
        f['estado'].toString().toUpperCase(): DateTime.parse(f['created_at'].toString()),
    };
  }

  @override
  Future<SolicitudRecoleccion?> getSolicitud(int id) async {
    final client = _supabase;
    if (client == null) return null;

    final fila = await client
        .from('solicitudes_recoleccion')
        .select('*, materiales_residuos(*)')
        .eq('id', id)
        .maybeSingle();
    return fila == null ? null : SolicitudRecoleccion.fromMap(fila);
  }

  @override
  Future<List<PostulacionRecoleccion>> getMisPostulaciones() async {
    final client = _supabase;
    if (client == null) return [];

    final gestorId = await getGestorId();
    if (gestorId == null) return [];

    final List<dynamic> data = await client
        .from('postulaciones_recoleccion')
        .select('*, solicitudes_recoleccion(*, materiales_residuos(*))')
        .eq('gestor_id', gestorId)
        .order('created_at', ascending: false);

    return data.map((item) => PostulacionRecoleccion.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<String> getRolUsuario() async {
    final client = _supabase;
    if (client == null) return 'GENERADOR';
    return consultarRol(client);
  }
}
