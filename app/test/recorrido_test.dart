import 'package:ecoresiduos/widgets/recorrido_bienvenida.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Pantalla de inicio de mentira con los tres elementos que señala el recorrido.
class _Inicio extends StatelessWidget {
  const _Inicio({required this.keyTarjeta, required this.keyCifras, required this.keyFab, required this.keyNav});

  final GlobalKey keyTarjeta;
  final GlobalKey keyCifras;
  final GlobalKey keyFab;
  final GlobalKey keyNav;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(key: keyTarjeta, height: 120, margin: const EdgeInsets.all(16), color: Colors.green),
          Container(key: keyCifras, height: 80, margin: const EdgeInsets.all(16), color: Colors.blue),
        ],
      ),
      floatingActionButton: FloatingActionButton(key: keyFab, onPressed: () {}, child: const Icon(Icons.camera)),
      bottomNavigationBar: SizedBox(key: keyNav, height: 80, child: const Placeholder()),
    );
  }
}

void main() {
  late GlobalKey keyTarjeta, keyCifras, keyFab, keyNav;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    keyTarjeta = GlobalKey();
    keyCifras = GlobalKey();
    keyFab = GlobalKey();
    keyNav = GlobalKey();
  });

  Future<BuildContext> montar(WidgetTester tester) async {
    usarPantallaAlta(tester);
    await tester.pumpWidget(
      app(_Inicio(keyTarjeta: keyTarjeta, keyCifras: keyCifras, keyFab: keyFab, keyNav: keyNav)),
    );
    return tester.element(find.byType(_Inicio));
  }

  Future<void> iniciar(WidgetTester tester, BuildContext contexto) async {
    mostrarRecorridoSiNecesario(contexto, 'GENERADOR',
        keyTarjeta: keyTarjeta, keyCifras: keyCifras, keyFab: keyFab, keyNav: keyNav);
    await tester.pumpAndSettle();
  }

  Future<bool?> visto() async => (await SharedPreferences.getInstance()).getBool('bienvenida_v4_generador');

  testWidgets('empieza con la bienvenida y el proceso, recorre con Anterior y Siguiente y queda visto al terminar',
      (tester) async {
    final contexto = await montar(tester);
    await iniciar(tester, contexto);

    expect(find.text('Bienvenido a EcoResiduos'), findsOneWidget);
    expect(find.text('Paso 1 de 5'), findsOneWidget);
    expect(find.textContaining('Publica una solicitud'), findsOneWidget);
    expect(find.text('Anterior'), findsNothing);
    expect(await visto(), isNull, reason: 'no se marca al aparecer');

    await tester.tap(find.text('Empezar'));
    await tester.pumpAndSettle();
    expect(find.text('Todo empieza aquí'), findsOneWidget);

    await tester.tap(find.text('Anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido a EcoResiduos'), findsOneWidget);

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text(i == 0 ? 'Empezar' : 'Siguiente'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Las cuatro secciones'), findsOneWidget);
    expect(find.text('Saltar recorrido'), findsNothing, reason: 'en el último paso solo queda «Listo»');

    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(find.text('Las cuatro secciones'), findsNothing);
    expect(await visto(), isTrue);

    // Ya visto: no vuelve a salir.
    await iniciar(tester, contexto);
    expect(find.text('Bienvenido a EcoResiduos'), findsNothing);
  });

  testWidgets('tocar fuera de la tarjeta no avanza; Atrás del sistema lo cierra como «Saltar»', (tester) async {
    final contexto = await montar(tester);
    await iniciar(tester, contexto);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Paso 1 de 5'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido a EcoResiduos'), findsNothing);
    expect(find.byType(_Inicio), findsOneWidget, reason: 'Atrás cierra el recorrido, no la pantalla de debajo');
    expect(await visto(), isTrue);
  });

  testWidgets('repetir desde la cuenta lo vuelve a mostrar', (tester) async {
    final contexto = await montar(tester);
    await iniciar(tester, contexto);
    await tester.tap(find.text('Saltar recorrido'));
    await tester.pumpAndSettle();
    expect(await visto(), isTrue);

    final antes = reinicioRecorridos.value;
    await reiniciarRecorridos();
    expect(reinicioRecorridos.value, antes + 1);
    expect(await visto(), isNull);
    await iniciar(tester, contexto);
    expect(find.text('Bienvenido a EcoResiduos'), findsOneWidget);
  });

  testWidgets('la tarjeta queda dentro de la pantalla en cada paso', (tester) async {
    final contexto = await montar(tester);
    await iniciar(tester, contexto);
    final pantalla = tester.view.physicalSize / tester.view.devicePixelRatio;
    for (var paso = 0; paso < 5; paso++) {
      final tarjeta = tester.getRect(find.ancestor(of: find.textContaining('Paso ${paso + 1} de'), matching: find.byType(Material)).first);
      expect(tarjeta.left, greaterThanOrEqualTo(0));
      expect(tarjeta.right, lessThanOrEqualTo(pantalla.width));
      expect(tarjeta.top, greaterThanOrEqualTo(0));
      expect(tarjeta.bottom, lessThanOrEqualTo(pantalla.height));
      if (paso < 4) {
        await tester.tap(find.text(paso == 0 ? 'Empezar' : 'Siguiente'));
        await tester.pumpAndSettle();
      }
    }
  });

  test('los textos del gestor describen sus pestañas reales', () {
    final pasos = pasosGestor(keyTarjeta: GlobalKey(), keyCifras: GlobalKey(), keyNav: GlobalKey());
    final secciones = pasos.last.descripcion;
    for (final pestana in ['Inicio', 'Solicitudes', 'Postulaciones', 'Directorio']) {
      expect(secciones, contains(pestana));
    }
    expect(pasos.first.puntos, hasLength(4));
  });
}
