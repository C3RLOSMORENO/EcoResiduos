import 'package:ecoresiduos/features/solicitudes/repositories/solicitudes_repository.dart';
import 'package:ecoresiduos/features/solicitudes/screens/mis_postulaciones_screen.dart';
import 'package:ecoresiduos/features/solicitudes/screens/mis_publicaciones_screen.dart';
import 'package:ecoresiduos/features/solicitudes/screens/solicitudes_disponibles_screen.dart';
import 'package:ecoresiduos/screens/inicio_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('Actividad · generador', () {
    testWidgets('muestra cada publicación con su estado y sus postulaciones, y filtra por estado', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository(
        publicaciones: [
          solicitud(id: 1),
          solicitud(id: 2, estado: 'CANCELADO', material: luminarias),
        ],
        resumen: {1: const ResumenPostulaciones(pendientes: 3)},
      );
      await tester.pumpWidget(app(MisPublicacionesScreen(repository: repo, cargarEscaneos: () async => [])));
      await tester.pumpAndSettle();

      expect(find.text('Cartón corrugado'), findsOneWidget);
      expect(find.text('120 kg'), findsNWidgets(2));
      expect(find.text('3 postulaciones'), findsOneWidget);
      expect(find.text('Luminarias fluorescentes'), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Cancelado'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Cancelado'));
      await tester.pumpAndSettle();
      expect(find.text('Cartón corrugado'), findsNothing);
      expect(find.text('Luminarias fluorescentes'), findsOneWidget);
    });

    testWidgets('sin publicaciones ofrece publicar o identificar y oculta el FAB', (tester) async {
      await tester.pumpWidget(
        app(MisPublicacionesScreen(repository: FakeSolicitudesRepository(), cargarEscaneos: () async => [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aún no has publicado residuos'), findsOneWidget);
      expect(find.text('Publicar residuo'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('Postulaciones · gestor', () {
    testWidgets('separa por estado y ofrece marcar recolectado en las aceptadas', (tester) async {
      usarPantallaAlta(tester);
      final enNegociacion = solicitud(id: 11, estado: 'EN_NEGOCIACION', material: luminarias);
      final repo = FakeSolicitudesRepository(
        misPostulaciones: [
          postulacion(id: 1, solicitudId: 10, solicitud: solicitud(id: 10)),
          postulacion(id: 2, solicitudId: 11, estado: 'ACEPTADA', solicitud: enNegociacion),
          postulacion(id: 3, solicitudId: 12, estado: 'NO_SELECCIONADA', solicitud: solicitud(id: 12)),
        ],
      );
      await tester.pumpWidget(app(MisPostulacionesScreen(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Enviadas · 1'), findsOneWidget);
      expect(find.text('Aceptadas · 1'), findsOneWidget);
      expect(find.text('Asignadas a otro gestor · 1'), findsOneWidget);
      expect(find.text('Rechazadas · 0'), findsOneWidget);

      await tester.tap(find.text('Aceptadas · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar recolectado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, lo recogí'));
      await tester.pumpAndSettle();
      expect(repo.llamadas, ['recolectado:11']);

      await tester.ensureVisible(find.text('Asignadas a otro gestor · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asignadas a otro gestor · 1'));
      await tester.pumpAndSettle();
      expect(find.text('El generador eligió a otro gestor'), findsOneWidget);
    });
  });

  group('Solicitudes disponibles · gestor', () {
    testWidgets('sin materiales verificados muestra «en verificación» y ninguna solicitud', (tester) async {
      final repo = FakeSolicitudesRepository(
        estadoMateriales: const EstadoMaterialesGestor(
          categoriasDeclaradas: ['APROVECHABLE', 'RAEE'],
          totalDeclarados: 3,
        ),
        disponibles: [solicitud()],
      );
      await tester.pumpWidget(app(SolicitudesDisponiblesScreen(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Tus materiales están en verificación'), findsOneWidget);
      expect(find.text('Aprovechable'), findsOneWidget);
      expect(find.text('Cartón corrugado'), findsNothing);
    });

    testWidgets('con materiales verificados lista las solicitudes', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository(
        disponibles: [
          solicitud(),
          solicitud(id: 11, material: luminarias),
        ],
      );
      await tester.pumpWidget(app(SolicitudesDisponiblesScreen(repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Solo ves los materiales que estás autorizado a recibir.'), findsOneWidget);
      expect(find.text('2 solicitudes'), findsOneWidget);
      expect(find.text('Luminarias fluorescentes'), findsOneWidget);
    });
  });

  group('Inicio', () {
    testWidgets('el generador ve su siguiente paso, sus cifras y el botón Identificar', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository(
        publicaciones: [
          solicitud(id: 1),
          solicitud(id: 2, estado: 'EN_NEGOCIACION', material: luminarias),
        ],
        resumen: {1: const ResumenPostulaciones(pendientes: 2)},
      );
      await tester.pumpWidget(app(InicioScreen(rol: 'GENERADOR', repository: repo)));
      await tester.pumpAndSettle();

      for (final destino in ['Inicio', 'Residuos', 'Gestores', 'Actividad']) {
        expect(find.widgetWithText(NavigationDestination, destino), findsOneWidget);
      }
      expect(find.widgetWithText(FloatingActionButton, 'Identificar'), findsOneWidget);
      expect(find.text('2 gestores quieren recoger tu cartón corrugado'), findsOneWidget);
      expect(find.text('1 DE 2'), findsOneWidget);
      expect(find.text('Revisar postulaciones'), findsOneWidget);
      expect(find.text('Publicados'), findsOneWidget);
      expect(find.text('En negociación'), findsOneWidget);
    });

    testWidgets('el generador sin publicaciones ve el primer paso sin cifras', (tester) async {
      await tester.pumpWidget(app(InicioScreen(rol: 'GENERADOR', repository: FakeSolicitudesRepository())));
      await tester.pumpAndSettle();

      expect(find.text('Empieza por tu primer residuo'), findsOneWidget);
      expect(find.text('Publicados'), findsNothing);
    });

    testWidgets('el gestor tiene su propia barra y no tiene FAB', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository(disponibles: [solicitud()]);
      await tester.pumpWidget(app(InicioScreen(rol: 'GESTOR', repository: repo)));
      await tester.pumpAndSettle();

      for (final destino in ['Inicio', 'Solicitudes', 'Postulaciones', 'Directorio']) {
        expect(find.widgetWithText(NavigationDestination, destino), findsOneWidget);
      }
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Hay 1 solicitud de tus materiales'), findsOneWidget);

      await tester.tap(find.text('Ver solicitudes'));
      await tester.pumpAndSettle();
      expect(find.text('Solo ves los materiales que estás autorizado a recibir.'), findsOneWidget);
    });

    testWidgets('el gestor con materiales en verificación no ve cifras', (tester) async {
      final repo = FakeSolicitudesRepository(
        estadoMateriales: const EstadoMaterialesGestor(categoriasDeclaradas: ['RAEE'], totalDeclarados: 1),
      );
      await tester.pumpWidget(app(InicioScreen(rol: 'GESTOR', repository: repo)));
      await tester.pumpAndSettle();

      expect(find.text('Tus materiales están en verificación'), findsOneWidget);
      expect(find.text('Disponibles'), findsNothing);
    });
  });
}
