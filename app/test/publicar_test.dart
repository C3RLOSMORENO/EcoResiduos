import 'package:ecoresiduos/features/solicitudes/screens/publicar_residuo_screen.dart';
import 'package:ecoresiduos/widgets/selector_cascada_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('la meta de avance dice qué falta y al publicar marca todos los errores', (tester) async {
    usarPantallaAlta(tester);
    final repo = FakeSolicitudesRepository();
    await tester.pumpWidget(app(PublicarResiduoScreen(repository: repo, materialesIniciales: repo.materiales)));
    await tester.pumpAndSettle();

    expect(find.text('Te faltan: foto, material, cantidad, dirección, municipio y teléfono'), findsOneWidget);
    expect(find.text('0 de 6 campos'), findsOneWidget);

    await tester.tap(find.text('Publicar residuo').last);
    await tester.pumpAndSettle();

    expect(find.text('La foto es obligatoria: ayuda al gestor a saber qué va a recoger.'), findsOneWidget);
    expect(find.text('Elige qué material vas a publicar.'), findsOneWidget);
    expect(find.text('Escribe cuánto hay, aunque sea aproximado.'), findsOneWidget);
    expect(find.text('Escribe la dirección donde el gestor recogerá el residuo.'), findsOneWidget);
    expect(repo.creada, isNull);
  });

  testWidgets('editar precarga los datos y guarda sin pedir confirmación', (tester) async {
    usarPantallaAlta(tester);
    final repo = FakeSolicitudesRepository();
    final original = solicitud().copyWith(fotoUrl: 'https://ejemplo.co/foto.jpg');
    await tester.pumpWidget(
      app(PublicarResiduoScreen(solicitudAEditar: original, repository: repo, materialesIniciales: repo.materiales)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editar publicación'), findsOneWidget);
    expect(find.text('Cartón corrugado'), findsOneWidget);
    expect(find.text('Floridablanca'), findsOneWidget);
    expect(find.text('0 de 6 campos'), findsNothing);

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(repo.llamadas, ['actualizar']);
  });

  testWidgets('el selector en cascada lleva de la categoría al material y avisa la advertencia', (tester) async {
    usarPantallaAlta(tester);
    final repo = FakeSolicitudesRepository();
    await tester.pumpWidget(app(PublicarResiduoScreen(repository: repo, materialesIniciales: repo.materiales)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Elige qué es'));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué tipo de residuo es?'), findsOneWidget);
    expect(find.text('1 DE 3'), findsOneWidget);

    await tester.tap(find.text('Peligroso (RESPEL)'));
    await tester.pumpAndSettle();
    expect(find.text('3 DE 3'), findsOneWidget, reason: 'una sola subcategoría salta directo al material');
    expect(find.text('Tiene advertencia técnica'), findsOneWidget);

    await tester.tap(find.text('Luminarias fluorescentes'));
    await tester.pumpAndSettle();

    expect(find.byType(SelectorCascadaSheet), findsNothing);
    expect(find.text('Advertencia técnica'), findsOneWidget);
    expect(find.text('No rompas los tubos: contienen mercurio.'), findsOneWidget);
  });

  testWidgets('la sugerencia de la IA abre el selector en la categoría detectada', (tester) async {
    usarPantallaAlta(tester);
    final repo = FakeSolicitudesRepository();
    await tester.pumpWidget(
      app(
        PublicarResiduoScreen(
          repository: repo,
          materialesIniciales: repo.materiales,
          fotoInicial: 'no-existe.jpg',
          analizarFoto: (_) async => (categoria: 'APROVECHABLE', confianza: 92),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('La IA sugiere: Aprovechable · 92 %'), findsOneWidget);
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.text('Cartón corrugado'), findsOneWidget);
    expect(find.text('3 DE 3'), findsOneWidget);
  });

  testWidgets('si guardar falla, borra la foto que alcanzó a subir', (tester) async {
    usarPantallaAlta(tester);
    final repo = FakeSolicitudesRepository()..fallarAlGuardar = true;
    await tester.pumpWidget(
      app(
        PublicarResiduoScreen(
          solicitudAEditar: solicitud().copyWith(fotoUrl: 'https://ejemplo.co/anterior.jpg'),
          repository: repo,
          materialesIniciales: repo.materiales,
          fotoInicial: 'nueva.jpg',
          categoriaSugerida: 'APROVECHABLE',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(repo.llamadas, ['eliminarFoto:https://ejemplo.co/foto.jpg']);
    expect(find.text('No se pudieron guardar los cambios.'), findsOneWidget);
  });
}
