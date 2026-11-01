import 'package:ecoresiduos/utils/sesion.dart';
import 'package:ecoresiduos/widgets/cuenta_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _generador = SesionUsuario(
  nombre: 'Laura Gómez',
  correo: 'laura@correo.co',
  telefono: '3001234567',
  municipio: 'BUCARAMANGA',
  documento: '1098765432',
);

Future<FakeAuthRepository> _abrirCuenta(WidgetTester tester, SesionUsuario sesion) async {
  final auth = FakeAuthRepository();
  usarPantallaAlta(tester);
  await tester.pumpWidget(app(Scaffold(body: CuentaBottomSheet(authRepository: auth, sesion: sesion))));
  await tester.pump();
  return auth;
}

/// Toca «Cambiar» en la fila del dato.
Future<void> _cambiar(WidgetTester tester, String etiqueta) async {
  final fila = find.ancestor(of: find.text(etiqueta), matching: find.byType(Row)).first;
  await tester.tap(find.descendant(of: fila, matching: find.text('Cambiar')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el generador puede cambiar su nombre, documento y teléfono', (tester) async {
    await _abrirCuenta(tester, _generador);
    expect(find.text('Nombre o empresa'), findsOneWidget);
    expect(find.text('Documento'), findsOneWidget);
    // Nombre, correo de acceso, documento, teléfono y municipio.
    expect(find.text('Cambiar'), findsNWidgets(5));
  });

  testWidgets('un teléfono inválido no se guarda y uno fijo de 7 dígitos se guarda con el 607', (tester) async {
    final auth = await _abrirCuenta(tester, _generador);
    await _cambiar(tester, 'Teléfono');

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Escribe un celular'), findsOneWidget);
    expect(auth.llamadas.where((l) => l.startsWith('perfilGenerador')), isEmpty);

    await tester.enterText(find.byType(TextField), '634 5678');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(auth.llamadas.last, 'perfilGenerador:Laura Gómez|1098765432|6076345678');
    expect(find.text('6076345678'), findsOneWidget);
  });

  testWidgets('el nombre y el documento se validan antes de guardar', (tester) async {
    final auth = await _abrirCuenta(tester, _generador);

    await _cambiar(tester, 'Nombre o empresa');
    await tester.enterText(find.byType(TextField), 'Lu');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe entre 3 y 150 caracteres'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Laura Gómez Pérez');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(auth.llamadas.last, 'perfilGenerador:Laura Gómez Pérez|1098765432|3001234567');

    await _cambiar(tester, 'Documento');
    await tester.enterText(find.byType(TextField), '12.3');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe entre 5 y 15 letras o números'), findsOneWidget);
  });

  testWidgets('el gestor no edita su NIT desde la app: lo pide al administrador', (tester) async {
    await _abrirCuenta(
      tester,
      const SesionUsuario(nombre: 'Reciclajes', correo: 'r@r.co', documento: '900396512', esGestor: true),
    );
    final nit = find.ancestor(of: find.text('NIT'), matching: find.byType(Row)).first;
    expect(find.descendant(of: nit, matching: find.text('Cambiar')), findsNothing);
    expect(find.text('Solicitar cambio al administrador'), findsOneWidget);
  });

  testWidgets('el generador cambia su correo de acceso: se valida y queda pendiente hasta confirmarlo', (tester) async {
    final auth = await _abrirCuenta(tester, _generador);
    await _cambiar(tester, 'Correo de acceso');
    expect(find.textContaining('sigues entrando con laura@correo.co'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sin-arroba');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(auth.llamadas.where((l) => l.startsWith('correo:')), isEmpty);

    await tester.enterText(find.byType(TextField), 'LAURA@correo.co');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Es el mismo correo con el que entras ahora'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'laura.gomez@nuevo.co');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(auth.llamadas.last, 'correo:laura.gomez@nuevo.co');
    expect(find.text('laura@correo.co'), findsOneWidget, reason: 'sigue el actual hasta confirmar');
    expect(find.text('Pendiente: confirma desde laura.gomez@nuevo.co'), findsOneWidget);
  });

  testWidgets('el gestor no cambia su correo de acceso desde la app', (tester) async {
    await _abrirCuenta(tester, const SesionUsuario(nombre: 'Reciclajes', correo: 'r@r.co', esGestor: true));
    final correo = find.ancestor(of: find.text('Correo de acceso'), matching: find.byType(Row)).first;
    expect(find.descendant(of: correo, matching: find.text('Cambiar')), findsNothing);
  });

  testWidgets('el aviso de guardado sale encima de la hoja, no tapado por ella', (tester) async {
    usarPantallaAlta(tester);
    await tester.pumpWidget(app(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => CuentaBottomSheet.show(context, authRepository: FakeAuthRepository()),
            child: const Text('Abrir cuenta'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('Abrir cuenta'));
    await tester.pumpAndSettle();
    await _cambiar(tester, 'Teléfono');
    await tester.enterText(find.byType(TextField), '3001234567');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // hitTestable: se puede tocar, o sea que ninguna capa lo tapa.
    expect(find.text('Cambiamos tu teléfono.').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar aviso'));
    await tester.pump();
    expect(find.text('Cambiamos tu teléfono.'), findsNothing);
  });

  testWidgets('la solicitud vacía se marca en su campo', (tester) async {
    final auth = await _abrirCuenta(tester, const SesionUsuario(nombre: 'Reciclajes', correo: 'r@r.co', esGestor: true));
    await tester.tap(find.text('Solicitar cambio al administrador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pump();

    expect(find.text('Cuéntanos qué dato quieres cambiar'), findsOneWidget);
    expect(auth.llamadas, isEmpty);
  });

  testWidgets('al escribir, el teclado no tapa el campo que se está editando', (tester) async {
    usarPantallaAlta(tester);
    await tester.pumpWidget(app(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => CuentaBottomSheet.show(context, authRepository: FakeAuthRepository()),
            child: const Text('Abrir cuenta'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('Abrir cuenta'));
    await tester.pumpAndSettle();
    await _cambiar(tester, 'Teléfono');

    // Teclado de un tercio de la pantalla.
    final alto = tester.view.physicalSize.height;
    tester.view.viewInsets = FakeViewPadding(bottom: alto / 3);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final pantalla = alto / tester.view.devicePixelRatio;
    final bordeTeclado = pantalla - pantalla / 3;
    expect(tester.getRect(find.byType(TextField)).bottom, lessThanOrEqualTo(bordeTeclado));
    expect(tester.getRect(find.text('Guardar')).bottom, lessThanOrEqualTo(bordeTeclado));
  });
}
