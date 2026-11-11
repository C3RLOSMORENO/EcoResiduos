import 'package:ecoresiduos/data/manual_usuario.dart';
import 'package:ecoresiduos/screens/manual_usuario_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> abrir(WidgetTester tester, {required bool esGestor}) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: ManualUsuarioScreen(esGestor: esGestor)));
  }

  testWidgets('el generador ve solo las secciones de su rol', (tester) async {
    await abrir(tester, esGestor: false);

    expect(find.text('Guía para quienes tienen residuos'), findsOneWidget);
    expect(find.text('Identificar un residuo'), findsOneWidget);
    expect(find.text('Publicar un residuo para que lo recojan'), findsOneWidget);
    expect(find.text('Buscar solicitudes y postularte'), findsNothing);
  });

  testWidgets('el gestor ve solo las secciones de su rol', (tester) async {
    await abrir(tester, esGestor: true);

    expect(find.text('Guía para gestores certificados'), findsOneWidget);
    expect(find.text('Buscar solicitudes y postularte'), findsOneWidget);
    expect(find.text('Recoger el residuo y cargar el certificado'), findsOneWidget);
    expect(find.text('Identificar un residuo'), findsNothing);
  });

  testWidgets('trae fecha, recorrido, aviso de datos y soporte (ISO/IEC/IEEE 26514)', (tester) async {
    await abrir(tester, esGestor: false);

    expect(find.text('Actualizado el $manualActualizado'), findsOneWidget);
    expect(find.text('Ver el recorrido en pantalla'), findsOneWidget);
    expect(find.text(avisoDatosGenerador), findsOneWidget);
    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('soporte.ecoresiduos@gmail.com'), findsOneWidget);
  });

  testWidgets('el gestor ve su propio aviso de datos', (tester) async {
    await abrir(tester, esGestor: true);

    expect(find.text(avisoDatosGestor), findsOneWidget);
    expect(find.text(avisoDatosGenerador), findsNothing);
  });

  testWidgets('al tocar una sección se ven sus pasos numerados', (tester) async {
    await abrir(tester, esGestor: false);

    await tester.tap(find.text('Identificar un residuo'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining('Permitir cámara', findRichText: true), findsOneWidget);
  });

  testWidgets('lo que va entre ** se muestra en negrita y sin asteriscos', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TextoManual('Toca **Publicar** ahora.'))));

    final texto = tester.widget<Text>(find.byType(Text));
    final spans = (texto.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.map((s) => s.text).join(), 'Toca Publicar ahora.');
    expect(spans[1].style?.fontWeight, FontWeight.w700);
  });

  test('todos los textos del manual cierran sus negritas', () {
    final textos = [
      for (final s in [...manualGenerador, ...manualGestor]) ...[?s.intro, ...s.pasos, ...s.notas],
      for (final p in [...preguntasGenerador, ...preguntasGestor]) ...[p.pregunta, p.respuesta],
    ];
    for (final t in textos) {
      expect('**'.allMatches(t).length.isEven, isTrue, reason: t);
    }
  });
}
