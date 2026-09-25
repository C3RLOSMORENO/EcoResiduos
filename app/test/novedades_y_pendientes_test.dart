import 'dart:io';

import 'package:ecoresiduos/models/notificacion.dart';
import 'package:ecoresiduos/repositories/notificaciones_repository.dart';
import 'package:ecoresiduos/screens/notificaciones_screen.dart';
import 'package:ecoresiduos/services/cola_publicaciones.dart';
import 'package:ecoresiduos/utils/formato.dart';
import 'package:ecoresiduos/widgets/linea_tiempo_estado.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

class _FakeNotificaciones implements NotificacionesRepository {
  _FakeNotificaciones(this.avisos);

  List<Notificacion> avisos;
  final llamadas = <String>[];

  @override
  Future<List<Notificacion>> listar() async => avisos;

  @override
  Future<int> contarNoLeidas() async => avisos.where((a) => !a.leida).length;

  @override
  Future<void> marcarLeida(int id) async {
    llamadas.add('leida:$id');
    avisos = [for (final a in avisos) a.id == id ? a.marcadaComoLeida() : a];
  }

  @override
  Future<void> marcarTodasLeidas() async {
    llamadas.add('todas');
    avisos = [for (final a in avisos) a.marcadaComoLeida()];
  }

  @override
  Future<void> descartar(int id) async {
    llamadas.add('descartar:$id');
    avisos = [for (final a in avisos) if (a.id != id) a];
  }

  @override
  VoidCallback escucharCambios(VoidCallback alCambiar) => () {};
}

Notificacion _aviso(int id, String titulo, {bool leida = false}) => Notificacion(
  id: id,
  tipo: 'POSTULACION_NUEVA',
  titulo: titulo,
  solicitudId: 10,
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  leidaAt: leida ? DateTime.now() : null,
);

void main() {
  group('Novedades', () {
    testWidgets('marca todo como leído y se descarta deslizando', (tester) async {
      final repo = _FakeNotificaciones([
        _aviso(1, 'EcoPilas se postuló a tu cartón corrugado'),
        _aviso(2, 'Se confirmó la recolección de pilas', leida: true),
      ]);
      await tester.pumpWidget(app(NotificacionesScreen(repository: repo, solicitudes: FakeSolicitudesRepository())));
      await tester.pumpAndSettle();

      expect(find.text('EcoPilas se postuló a tu cartón corrugado'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Sin leer')), findsOneWidget);

      await tester.tap(find.byTooltip('Marcar todo como leído'));
      await tester.pumpAndSettle();
      expect(repo.llamadas, ['todas']);
      expect(find.byTooltip('Marcar todo como leído'), findsNothing);

      await tester.drag(find.text('Se confirmó la recolección de pilas'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(repo.llamadas.last, 'descartar:2');
      expect(find.text('Se confirmó la recolección de pilas'), findsNothing);
    });

    testWidgets('al abrir una novedad la marca como leída', (tester) async {
      final repo = _FakeNotificaciones([_aviso(1, 'Te aceptaron la recolección de pilas')]);
      await tester.pumpWidget(app(NotificacionesScreen(repository: repo, solicitudes: FakeSolicitudesRepository())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Te aceptaron la recolección de pilas'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, ['leida:1']);
      expect(find.text('Esta solicitud ya no está disponible.'), findsOneWidget);
    });

    testWidgets('sin avisos muestra el estado vacío', (tester) async {
      await tester.pumpWidget(
        app(NotificacionesScreen(repository: _FakeNotificaciones([]), solicitudes: FakeSolicitudesRepository())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin novedades'), findsOneWidget);
    });
  });

  group('Línea de tiempo', () {
    final recolectada = solicitud(estado: 'RECOLECTADO', recolectadoAt: DateTime(2026, 9, 20));

    testWidgets('usa la fecha del historial para «En negociación»', (tester) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: LineaTiempoEstado(solicitud: recolectada, fechas: {'EN_NEGOCIACION': DateTime(2026, 9, 18)}),
          ),
        ),
      );
      expect(find.text(fechaCorta(DateTime(2026, 9, 18))), findsOneWidget);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('sin historial muestra «—» en la fecha desconocida', (tester) async {
      await tester.pumpWidget(app(Scaffold(body: LineaTiempoEstado(solicitud: recolectada))));
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('Publicaciones sin conexión', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await ColaPublicaciones.cargar();
    });

    test('se guardan y se envían cuando vuelve la conexión', () async {
      final repo = FakeSolicitudesRepository()..errorAlCrear = const SocketException('sin red');
      await ColaPublicaciones.agregar(solicitud: solicitud(), nombreMaterial: 'Cartón corrugado');
      expect(ColaPublicaciones.pendientes.value, hasLength(1));

      expect(await ColaPublicaciones.enviar(repo), 0);
      expect(ColaPublicaciones.pendientes.value, hasLength(1), reason: 'sin red se conserva');

      repo.errorAlCrear = null;
      expect(await ColaPublicaciones.enviar(repo), 1);
      expect(ColaPublicaciones.pendientes.value, isEmpty);
      expect(repo.creada?.generadorId, 1, reason: 'el generador se resuelve al enviar');
      expect(repo.creada?.direccionRecoleccion, 'Cl 30 # 26-15, Cañaveral');

      await ColaPublicaciones.cargar();
      expect(ColaPublicaciones.pendientes.value, isEmpty, reason: 'la cola guardada también quedó vacía');
    });

    test('se pueden descartar', () async {
      await ColaPublicaciones.agregar(solicitud: solicitud(), nombreMaterial: 'Cartón corrugado');
      await ColaPublicaciones.descartar(ColaPublicaciones.pendientes.value.single);
      expect(ColaPublicaciones.pendientes.value, isEmpty);
    });

    test('distingue la falta de conexión de otros errores', () {
      expect(esErrorDeConexion(const SocketException('Failed host lookup')), isTrue);
      expect(esErrorDeConexion(Exception('ClientException: Connection closed')), isTrue);
      expect(esErrorDeConexion(StateError('No se encontró el perfil de generador.')), isFalse);
    });
  });
}
