import 'package:ecoresiduos/features/auth/screens/autorizacion_datos_screen.dart';
import 'package:ecoresiduos/features/auth/screens/politica_datos_screen.dart';
import 'package:ecoresiduos/features/auth/widgets/campo_contrasena.dart';
import 'package:ecoresiduos/legal/politica_datos.dart';
import 'package:ecoresiduos/services/autorizacion_datos_service.dart';
import 'package:ecoresiduos/utils/validacion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ServicioFalso implements AutorizacionDatosService {
  _ServicioFalso({required this.yaAcepto});

  final bool yaAcepto;
  final aceptaciones = <String>[];

  @override
  Future<bool> vigente(String usuarioId) async => yaAcepto;

  @override
  Future<void> aceptar(String usuarioId) async => aceptaciones.add(usuarioId);
}

void main() {
  group('Teléfonos (mismas reglas que el panel)', () {
    test('celular, fijo de 10 o de 7 dígitos, 01 8000 y extensión', () {
      const casos = {
        '300 123 4567': '3001234567',
        '+57 300-123-4567': '3001234567',
        '573001234567': '3001234567',
        '(607) 634 5678': '6076345678',
        '634 5678': '6076345678',
        '01 8000 123456': '018000123456',
        '607 6970000 ext 123': '6076970000 ext. 123',
      };
      casos.forEach((entrada, guardado) => expect(normalizarTelefono(entrada), guardado, reason: entrada));
    });

    test('lo que no es un teléfono colombiano se rechaza con el mensaje', () {
      for (final malo in ['abc', '12345', '2001234567', '30012345678']) {
        expect(normalizarTelefono(malo), isNull, reason: malo);
        expect(validarTelefono(malo), mensajeTelefono, reason: malo);
      }
      expect(validarTelefono(''), 'Escribe el teléfono');
    });
  });

  test('NIT: dígito de verificación de la DIAN con NIT reales', () {
    expect(digitoVerificacion('890903938'), 8);
    expect(digitoVerificacion('899999068'), 1);
    expect(digitoVerificacion('800197268'), 4);
    expect(validarNit('890.903.938-8'), isNull);
    expect(validarNit('890903938'), isNull);
    expect(validarNit('890903938-7'), contains('no corresponde'));
    expect(validarNit('1234567'), contains('entre 8 y 15'));
  });

  test('la contraseña necesita 8 caracteres, una letra y un número', () {
    expect(validarContrasena('clave1234'), isNull);
    expect(validarContrasena('12345678'), contains('una letra'));
    expect(validarContrasena('claveclave'), contains('un número'));
    expect(validarContrasena('cl4ve'), contains('8 caracteres'));
  });

  testWidgets('la política muestra todas sus secciones y la versión', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PoliticaDatosScreen()));
    expect(find.textContaining(versionPoliticaDatos), findsOneWidget);
    for (final seccion in politicaDatos) {
      await tester.scrollUntilVisible(find.text(seccion.titulo), 200);
      expect(find.text(seccion.titulo), findsOneWidget);
    }
  });

  group('Autorización de datos al entrar', () {
    testWidgets('quien no ha aceptado la versión vigente ve la autorización y no entra sin marcarla', (tester) async {
      final servicio = _ServicioFalso(yaAcepto: false);
      await tester.pumpWidget(MaterialApp(
        home: PuertaAutorizacionDatos(usuarioId: 'u1', servicio: servicio, child: const Text('Inicio de la app')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Antes de continuar'), findsOneWidget);
      expect(find.text('Inicio de la app'), findsNothing);

      await tester.tap(find.text('Aceptar y continuar'));
      await tester.pump();
      expect(find.text('Para crear la cuenta debes autorizar el tratamiento de tus datos.'), findsOneWidget);
      expect(servicio.aceptaciones, isEmpty);

      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('Aceptar y continuar'));
      await tester.pumpAndSettle();
      expect(servicio.aceptaciones, ['u1']);
      expect(find.text('Inicio de la app'), findsOneWidget);
    });

    testWidgets('quien ya aceptó entra directo', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: PuertaAutorizacionDatos(
          usuarioId: 'u2',
          servicio: _ServicioFalso(yaAcepto: true),
          child: const Text('Inicio de la app'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Inicio de la app'), findsOneWidget);
      expect(find.text('Antes de continuar'), findsNothing);
    });
  });
}
