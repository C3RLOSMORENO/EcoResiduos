import 'package:ecoresiduos/features/auth/models/gestor_directorio.dart';
import 'package:ecoresiduos/features/auth/repositories/auth_repository.dart';
import 'package:ecoresiduos/features/solicitudes/models/material_residuo.dart';
import 'package:ecoresiduos/features/solicitudes/models/solicitud_recoleccion.dart';
import 'package:ecoresiduos/features/solicitudes/repositories/solicitudes_repository.dart';
import 'package:ecoresiduos/models/perfil_generador.dart';
import 'package:ecoresiduos/models/perfil_gestor.dart';
import 'package:ecoresiduos/models/postulacion_recoleccion.dart';
import 'package:ecoresiduos/services/archivo_pdf.dart';
import 'package:ecoresiduos/theme/eco_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Widget app(Widget home) => MaterialApp(theme: ecoTheme(Brightness.light), home: home);

/// Pantalla de teléfono alta (412 × 2000 dp) para que las listas construyan todo su contenido.
void usarPantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const carton = MaterialResiduo(
  id: 1,
  nombreComun: 'Cartón corrugado',
  categoria: 'APROVECHABLE',
  subcategoria: 'Papel y cartón',
  guiaManejo: '1. Dóblalo\n2. Amárralo',
);

const luminarias = MaterialResiduo(
  id: 2,
  nombreComun: 'Luminarias fluorescentes',
  categoria: 'PELIGROSO',
  subcategoria: 'Luminarias',
  advertenciaManejo: 'No rompas los tubos: contienen mercurio.',
);

SolicitudRecoleccion solicitud({
  int id = 10,
  String estado = 'PUBLICADO',
  MaterialResiduo material = carton,
  DateTime? recolectadoAt,
  DateTime? confirmadoAt,
  String? certificadoUrl,
  TipoCertificado? certificadoTipo,
}) => SolicitudRecoleccion(
  id: id,
  generadorId: 1,
  materialId: material.id,
  cantidadEstimada: 120,
  unidadMedida: 'KG',
  direccionRecoleccion: 'Cl 30 # 26-15, Cañaveral',
  municipio: 'FLORIDABLANCA',
  telefono: '3164829051',
  estado: estado,
  material: material,
  createdAt: DateTime.now().subtract(const Duration(days: 2)),
  updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
  recolectadoAt: recolectadoAt,
  confirmadoAt: confirmadoAt,
  certificadoUrl: certificadoUrl,
  certificadoTipo: certificadoTipo,
  certificadoAt: certificadoUrl == null ? null : DateTime.now().subtract(const Duration(hours: 2)),
);

PostulacionRecoleccion postulacion({
  required int id,
  int solicitudId = 10,
  String estado = 'PROPUESTA',
  String gestor = 'Reciclajes del Oriente S.A.S.',
  String? propuesta,
  TipoValor? tipoValor,
  int? valor,
  SolicitudRecoleccion? solicitud,
}) => PostulacionRecoleccion(
  id: id,
  solicitudId: solicitudId,
  gestorId: id * 100,
  estado: estado,
  propuesta: propuesta,
  tipoValor: tipoValor,
  valor: valor,
  gestorRazonSocial: gestor,
  gestorMunicipio: 'Girón',
  createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  solicitud: solicitud,
);

/// Repositorio en memoria que registra las llamadas que hace la interfaz.
class FakeSolicitudesRepository implements SolicitudesRepository {
  FakeSolicitudesRepository({
    this.publicaciones = const [],
    this.disponibles = const [],
    this.postulaciones = const [],
    this.misPostulaciones = const [],
    this.materiales = const [carton, luminarias],
    this.estadoMateriales = const EstadoMaterialesGestor(totalDeclarados: 1, totalVerificados: 1),
    this.resumen = const {},
    this.miPostulacion,
  });

  List<SolicitudRecoleccion> publicaciones;
  List<SolicitudRecoleccion> disponibles;
  List<PostulacionRecoleccion> postulaciones;
  List<PostulacionRecoleccion> misPostulaciones;
  List<MaterialResiduo> materiales;
  EstadoMaterialesGestor estadoMateriales;
  Map<int, ResumenPostulaciones> resumen;
  PostulacionRecoleccion? miPostulacion;
  Map<String, DateTime> historialEstados = {};

  /// Hace fallar el guardado para probar la limpieza de la foto subida.
  bool fallarAlGuardar = false;

  /// Error que lanza al crear una solicitud (p. ej. falta de conexión).
  Object? errorAlCrear;

  final llamadas = <String>[];
  SolicitudRecoleccion? creada;
  String? propuestaEnviada;
  TipoValor? tipoValorEnviado;
  int? valorEnviado;

  @override
  Future<List<MaterialResiduo>> getMateriales() async => materiales;

  @override
  Future<int?> getGeneradorId() async => 1;

  @override
  Future<int?> getGestorId() async => 2;

  @override
  Future<String> subirFoto(String localPath) async => 'https://ejemplo.co/foto.jpg';

  @override
  Future<void> eliminarFoto(String? url) async => llamadas.add('eliminarFoto:$url');

  @override
  Future<SolicitudRecoleccion> crearSolicitud(SolicitudRecoleccion solicitud) async {
    if (errorAlCrear != null) throw errorAlCrear!;
    creada = solicitud;
    return solicitud.copyWith(id: 99);
  }

  @override
  Future<void> actualizarSolicitud(SolicitudRecoleccion solicitud) async {
    if (fallarAlGuardar) throw Exception('sin conexión');
    llamadas.add('actualizar');
  }

  @override
  Future<List<SolicitudRecoleccion>> getMisPublicaciones({int? generadorId}) async => publicaciones;

  @override
  Future<void> cancelarSolicitud(int id) async => llamadas.add('cancelar:$id');

  @override
  Future<List<int>> getMaterialesAutorizadosGestor() async => [for (final m in materiales) m.id];

  @override
  Future<EstadoMaterialesGestor> getEstadoMaterialesGestor() async => estadoMateriales;

  /// Materiales guardados del gestor: id → verificado.
  Map<int, bool> misMateriales = {};

  @override
  Future<Map<int, bool>> getMisMateriales() async => misMateriales;

  @override
  Future<int> guardarMisMateriales(List<int> materialIds) async {
    llamadas.add('materiales:${(materialIds.toList()..sort()).join(',')}');
    final nuevos = materialIds.where((id) => !misMateriales.containsKey(id)).length;
    misMateriales = {for (final id in materialIds) id: misMateriales[id] ?? false};
    return nuevos;
  }

  @override
  Future<List<SolicitudRecoleccion>> getSolicitudesDisponibles({List<int>? materialesAutorizados}) async => disponibles;

  @override
  Future<void> postularASolicitud({
    required int solicitudId,
    required TipoValor tipoValor,
    required int valor,
    int? gestorId,
    String? propuesta,
  }) async {
    llamadas.add('postular:$solicitudId');
    propuestaEnviada = propuesta;
    tipoValorEnviado = tipoValor;
    valorEnviado = valor;
    miPostulacion = postulacion(id: 1, solicitudId: solicitudId, propuesta: propuesta);
  }

  @override
  Future<PostulacionRecoleccion?> getMiPostulacion(int solicitudId) async => miPostulacion;

  @override
  Future<SolicitudRecoleccion?> getSolicitud(int id) async => null;

  @override
  Future<Map<String, DateTime>> getHistorialEstados(int solicitudId) async => historialEstados;

  @override
  Future<List<PostulacionRecoleccion>> getMisPostulaciones() async => misPostulaciones;

  @override
  Future<Map<int, ResumenPostulaciones>> getResumenPostulaciones(List<int> solicitudIds) async => resumen;

  @override
  Future<List<PostulacionRecoleccion>> getPostulacionesDeSolicitud(int solicitudId) async => postulaciones;

  @override
  Future<void> aceptarPostulacion({required int solicitudId, required int postulacionId, required int gestorId}) async {
    llamadas.add('aceptar:$postulacionId');
  }

  @override
  Future<void> rechazarPostulacion({required int postulacionId}) async => llamadas.add('rechazar:$postulacionId');

  @override
  Future<void> marcarRecolectado({required int solicitudId, int? gestorId}) async =>
      llamadas.add('recolectado:$solicitudId');

  @override
  Future<void> cargarCertificado({
    required int solicitudId,
    required ArchivoPdf pdf,
    required TipoCertificado tipo,
  }) async => llamadas.add('certificado:$solicitudId:${tipo.valor}');

  @override
  Future<void> confirmarRecoleccion({required int solicitudId, int? generadorId}) async =>
      llamadas.add('confirmar:$solicitudId');

  @override
  Future<void> reportarProblemaRecoleccion({required int solicitudId, required String detalle}) async =>
      llamadas.add('problema:$detalle');

  @override
  Future<String> getRolUsuario() async => 'GENERADOR';
}

class FakeAuthRepository implements AuthRepository {
  AuthException? errorAlEntrar;
  GestorDirectorio? gestorDirectorio;
  AuthException? errorOtp;

  final llamadas = <String>[];

  @override
  User? get currentUser => null;

  @override
  Future<AuthResponse> signIn({required String email, required String password}) async {
    llamadas.add('entrar:$email');
    if (errorAlEntrar != null) throw errorAlEntrar!;
    return AuthResponse();
  }

  @override
  Future<void> reenviarConfirmacion(String email) async => llamadas.add('reenviar:$email');

  @override
  Future<AuthResponse> signUpGenerador({
    required String email,
    required String password,
    required String nombre,
    required String documento,
    required String telefono,
    required String municipio,
  }) async {
    llamadas.add('registroGenerador:$email:$municipio');
    return AuthResponse();
  }

  @override
  Future<GestorDirectorio?> buscarGestorEnDirectorio(String nit) async {
    llamadas.add('directorio:$nit');
    return gestorDirectorio;
  }

  @override
  Future<AuthResponse> signUpGestor({
    required String email,
    required String password,
    required GestorDirectorio gestorDirectorio,
    required String razonSocial,
    required String telefono,
    required String direccion,
    required String municipio,
    required List<int> materialesDeclarados,
  }) async {
    llamadas.add('registroGestor:${materialesDeclarados.join(',')}');
    return AuthResponse();
  }

  @override
  Future<String> subirPermisoAmbiental(ArchivoPdf pdf) async {
    llamadas.add('permiso:${pdf.nombre}');
    return 'registro/abc.pdf';
  }

  @override
  Future<AuthResponse> signUpGestorNuevo({
    required String email,
    required String password,
    required String nit,
    required String razonSocial,
    required String representanteLegal,
    required String telefono,
    required String direccion,
    required String municipio,
    String? horario,
    required String permisoPath,
    required List<int> materialesDeclarados,
  }) async {
    llamadas.add('registroGestorNuevo:$nit:$permisoPath:${materialesDeclarados.join(',')}');
    return AuthResponse();
  }

  @override
  Future<void> solicitarRecuperacionPassword(String email) async => llamadas.add('recuperar:$email');

  @override
  Future<AuthResponse> verificarOtpRecuperacion({required String email, required String token}) async {
    llamadas.add('otp:$token');
    if (errorOtp != null) throw errorOtp!;
    return AuthResponse();
  }

  @override
  Future<UserResponse> actualizarPassword(String nuevaPassword) async {
    llamadas.add('contrasena');
    return UserResponse.fromJson(const {});
  }

  @override
  Future<void> signOut() async => llamadas.add('salir');

  @override
  Future<String> getRolUsuario() async => 'GENERADOR';

  @override
  Future<PerfilGenerador?> getPerfilGenerador() async => null;

  @override
  Future<PerfilGestor?> getPerfilGestor() async => null;

  @override
  Future<void> actualizarMunicipio(String municipio) async => llamadas.add('municipio:$municipio');
}
