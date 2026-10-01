import 'package:ecoresiduos/features/solicitudes/repositories/solicitudes_repository.dart';
import 'package:ecoresiduos/features/solicitudes/screens/mis_materiales_screen.dart';
import 'package:ecoresiduos/widgets/materiales_en_verificacion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('Materiales que recibo', () {
    testWidgets('muestra qué está verificado y guarda los materiales nuevos', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository()..misMateriales = {1: true};
      await tester.pumpWidget(app(MisMaterialesScreen(repository: repo)));
      await tester.pumpAndSettle();

      final guardar = find.widgetWithText(FilledButton, 'Guardar materiales');
      expect(tester.widget<FilledButton>(guardar).onPressed, isNull);

      await tester.tap(find.text('Aprovechable'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Verificado'), findsOneWidget);

      await tester.tap(find.text('Peligroso (RESPEL)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Luminarias fluorescentes'));
      await tester.pumpAndSettle();
      await tester.tap(guardar);
      await tester.pumpAndSettle();

      expect(repo.llamadas, ['materiales:1,2']);
    });

    testWidgets('no deja guardar sin ningún material', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository()..misMateriales = {1: true};
      await tester.pumpWidget(app(MisMaterialesScreen(repository: repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aprovechable'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cartón corrugado'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar materiales'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, isEmpty);
      expect(find.text('Elige al menos un material que tu licencia te permita recibir.'), findsOneWidget);
    });

    testWidgets('sin materiales, el gestor puede elegirlos desde el aviso', (tester) async {
      usarPantallaAlta(tester);
      final repo = FakeSolicitudesRepository();
      var recargo = false;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: MaterialesEnVerificacion(
              estado: const EstadoMaterialesGestor(),
              repository: repo,
              onMaterialesCambiados: () => recargo = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Elegir materiales'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aprovechable'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cartón corrugado'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar materiales'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, ['materiales:1']);
      expect(recargo, isTrue);
      expect(find.textContaining('Los nuevos quedan en verificación'), findsOneWidget);
    });
  });
}
