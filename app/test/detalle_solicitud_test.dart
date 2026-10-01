import 'package:ecoresiduos/features/solicitudes/models/solicitud_recoleccion.dart';
import 'package:ecoresiduos/features/solicitudes/screens/detalle_solicitud_screen.dart';
import 'package:ecoresiduos/models/postulacion_recoleccion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('Detalle · generador', () {
    testWidgets('muestra el valor que propone cada gestor y lo repite al aceptar', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository(
        postulaciones: [postulacion(id: 1, tipoValor: TipoValor.cobroRecoleccion, valor: 50000)],
      );
      await tester.pumpWidget(app(DetalleSolicitudScreen(solicitud: solicitud(), repository: repo, rol: 'GENERADOR')));
      await tester.pumpAndSettle();

      expect(find.text('Valor cobrado por recolección externa'), findsOneWidget);
      expect(find.text('\$ 50.000'), findsOneWidget);

      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Valor cobrado por recolección externa: \$ 50.000'), findsOneWidget);
    });

    testWidgets('descarga el certificado cuando el gestor lo carga', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository(postulaciones: [postulacion(id: 1, estado: 'ACEPTADA')]);
      await tester.pumpWidget(
        app(
          DetalleSolicitudScreen(
            solicitud: solicitud(
              estado: 'RECOLECTADO',
              recolectadoAt: DateTime.now().subtract(const Duration(days: 1)),
              confirmadoAt: DateTime.now(),
              certificadoUrl: 'https://ejemplo.co/storage/v1/object/public/certificados/u/10/1.pdf',
              certificadoTipo: TipoCertificado.aprovechamiento,
            ),
            repository: repo,
            rol: 'GENERADOR',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Certificado de aprovechamiento'), findsOneWidget);
      expect(find.text('Ver PDF'), findsOneWidget);
      expect(find.text('Reemplazar'), findsNothing);
    });

    testWidgets('sin certificado le dice al generador que está pendiente', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository(postulaciones: [postulacion(id: 1, estado: 'ACEPTADA')]);
      await tester.pumpWidget(
        app(
          DetalleSolicitudScreen(
            solicitud: solicitud(estado: 'RECOLECTADO', recolectadoAt: DateTime.now()),
            repository: repo,
            rol: 'GENERADOR',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Certificado pendiente'), findsOneWidget);
    });

    testWidgets('acepta una postulación y avisa que las demás quedan asignadas a otro gestor', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository(
        postulaciones: [
          postulacion(id: 1, propuesta: 'Paso el jueves en la mañana'),
          postulacion(id: 2, gestor: 'Cartones y Vidrios Provenza'),
        ],
      );
      await tester.pumpWidget(app(DetalleSolicitudScreen(solicitud: solicitud(), repository: repo, rol: 'GENERADOR')));
      await tester.pumpAndSettle();

      expect(find.text('Postulaciones · 2'), findsOneWidget);
      expect(find.text('«Paso el jueves en la mañana»'), findsOneWidget);

      await tester.ensureVisible(find.text('Aceptar').first);
      await tester.tap(find.text('Aceptar').first);
      await tester.pumpAndSettle();

      expect(find.text('¿Aceptar a Reciclajes del Oriente S.A.S.?'), findsOneWidget);
      expect(find.textContaining('les avisaremos que la solicitud se asignó a otro gestor'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Aceptar').last);
      await tester.pumpAndSettle();

      expect(repo.llamadas, contains('aceptar:1'));
      expect(repo.llamadas, isNot(contains('aceptar:2')));
    });

    testWidgets('rechazar descarta solo esa propuesta', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository(postulaciones: [postulacion(id: 1), postulacion(id: 2)]);
      await tester.pumpWidget(app(DetalleSolicitudScreen(solicitud: solicitud(), repository: repo, rol: 'GENERADOR')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Rechazar').last);
      await tester.tap(find.text('Rechazar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Rechazar'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, ['rechazar:2']);
    });

    testWidgets('sin postulaciones muestra el estado vacío', (tester) async {
      usarPantallaAlta(tester);
      await tester.pumpWidget(
        app(DetalleSolicitudScreen(solicitud: solicitud(), repository: FakeSolicitudesRepository(), rol: 'GENERADOR')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Aún no hay postulaciones'), findsOneWidget);
    });

    testWidgets('confirma una recolección que el gestor marcó', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository(postulaciones: [postulacion(id: 1, estado: 'ACEPTADA')]);
      final recolectada = solicitud(estado: 'RECOLECTADO', recolectadoAt: DateTime.now());
      await tester.pumpWidget(app(DetalleSolicitudScreen(solicitud: recolectada, repository: repo, rol: 'GENERADOR')));
      await tester.pumpAndSettle();

      expect(find.text('Recolectado · por confirmar'), findsOneWidget);
      expect(find.text('Si no respondes en 72 h, la confirmamos automáticamente.'), findsOneWidget);

      await tester.tap(find.text('Sí, confirmar recolección'));
      await tester.pumpAndSettle();
      expect(repo.llamadas, ['confirmar:10']);
    });

    testWidgets('editar solo existe en PUBLICADO y cancelar pide confirmación', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository();
      await tester.pumpWidget(app(DetalleSolicitudScreen(solicitud: solicitud(), repository: repo, rol: 'GENERADOR')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Opciones'));
      await tester.pumpAndSettle();
      expect(find.text('Editar publicación'), findsOneWidget);

      await tester.tap(find.text('Cancelar publicación'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cancelar esta publicación?'), findsOneWidget);
      expect(repo.llamadas, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar publicación'));
      await tester.pumpAndSettle();
      expect(repo.llamadas, ['cancelar:10']);
      expect(find.text('Cancelaste esta publicación'), findsOneWidget);
      expect(find.text('Publicar de nuevo'), findsOneWidget);
    });
  });

  group('Detalle · gestor', () {
    testWidgets('se postula con su propuesta', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository();
      await tester.pumpWidget(app(DetalleSolicitudScreen(solicitud: solicitud(), repository: repo, rol: 'GESTOR')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '1250000');
      await tester.enterText(find.byType(TextField).last, 'Paso el jueves con camión');
      await tester.pump();
      expect(find.text('1.250.000'), findsOneWidget);

      await tester.tap(find.text('Postularme para recolección'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, ['postular:10']);
      expect(repo.tipoValorEnviado, TipoValor.pagoAprovechamiento);
      expect(repo.valorEnviado, 1250000);
      expect(repo.propuestaEnviada, 'Paso el jueves con camión');
      expect(find.text('Ya te postulaste'), findsOneWidget);
    });

    testWidgets('no se postula sin escribir el valor', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository();
      await tester.pumpWidget(
        app(
          DetalleSolicitudScreen(
            solicitud: solicitud(material: luminarias),
            repository: repo,
            rol: 'GESTOR',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Valor cobrado por recolección externa'), findsOneWidget);
      await tester.tap(find.text('Postularme para recolección'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, isEmpty);
      expect(find.text('Escribe el valor. Si no cobras ni pagas, escribe 0.'), findsOneWidget);
    });

    testWidgets('después de recoger le pide cargar el certificado', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository(
        miPostulacion: postulacion(id: 1, estado: 'ACEPTADA', tipoValor: TipoValor.pagoAprovechamiento, valor: 80000),
      );
      await tester.pumpWidget(
        app(
          DetalleSolicitudScreen(
            solicitud: solicitud(estado: 'RECOLECTADO', recolectadoAt: DateTime.now()),
            repository: repo,
            rol: 'GESTOR',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Valor pagado por aprovechamiento'), findsOneWidget);
      expect(find.text('Falta cargar el certificado'), findsOneWidget);

      await tester.tap(find.text('Cargar certificado (PDF)'));
      await tester.pumpAndSettle();

      expect(find.text('¿Qué certificado vas a cargar?'), findsOneWidget);
      expect(find.text('Elegir PDF'), findsOneWidget);
    });

    testWidgets('con la postulación aceptada puede marcar la recolección', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository(miPostulacion: postulacion(id: 1, estado: 'ACEPTADA'));
      await tester.pumpWidget(
        app(
          DetalleSolicitudScreen(
            solicitud: solicitud(estado: 'EN_NEGOCIACION'),
            repository: repo,
            rol: 'GESTOR',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Te eligieron para esta recolección'), findsOneWidget);
      await tester.tap(find.text('Marcar recolectado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, lo recogí'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, ['recolectado:10']);
    });

    testWidgets('una postulación no elegida se muestra en tono neutro', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository(miPostulacion: postulacion(id: 1, estado: 'NO_SELECCIONADA'));
      await tester.pumpWidget(
        app(
          DetalleSolicitudScreen(
            solicitud: solicitud(estado: 'EN_NEGOCIACION'),
            repository: repo,
            rol: 'GESTOR',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Asignada a otro gestor'), findsOneWidget);
      expect(find.text('Postularme para recolección'), findsNothing);
    });
  });
}
