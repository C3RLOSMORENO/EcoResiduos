import 'package:ecoresiduos/features/auth/models/gestor_directorio.dart';
import 'package:ecoresiduos/features/auth/repositories/auth_repository.dart' show traducirErrorAuth;
import 'package:ecoresiduos/features/auth/screens/login_screen.dart';
import 'package:ecoresiduos/features/auth/screens/registro_screen.dart';
import 'package:ecoresiduos/features/auth/screens/restablecer_password_screen.dart';
import 'package:ecoresiduos/features/auth/screens/verificar_recuperacion_screen.dart';
import 'package:ecoresiduos/features/auth/widgets/casilla_autorizacion_datos.dart';
import 'package:ecoresiduos/services/archivo_pdf.dart';
import 'package:ecoresiduos/widgets/boton_fijo_inferior.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes.dart';

const _gestorDirectorio = GestorDirectorio(
  id: 7,
  nit: '900456789',
  razonSocial: 'Reciclajes del Oriente S.A.S.',
  emailOficial: 'operaciones@reciclajes.co',
  estadoVerificacion: 'APROBADO',
  telefono: '6076462210',
  direccion: 'Cra 15 # 8-42',
  municipio: 'GIRÓN',
  materialIds: [1],
);

void main() {
  group('Login', () {
    Future<void> abrirLogin(WidgetTester tester, FakeAuthRepository auth) async {
      usarPantallaAlta(tester);
      reducirMovimiento(tester);
      await tester.pumpWidget(app(LoginScreen(authRepository: auth)));
    }

    testWidgets('al entrar bien confirma que se inició sesión', (tester) async {
      final auth = FakeAuthRepository();
      await abrirLogin(tester, auth);

      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'mariana@correo.co');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'clave1234');
      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(find.text('Iniciaste sesión.'), findsOneWidget);
    });

    testWidgets('credenciales incorrectas muestran el aviso sin perder los datos', (tester) async {
      final auth = FakeAuthRepository()
        ..errorAlEntrar = const AuthException('El correo o la contraseña no coinciden.', code: 'invalid_credentials');
      await abrirLogin(tester, auth);

      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'mariana@correo.co');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'clave1234');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(auth.llamadas, ['entrar:mariana@correo.co']);
      expect(find.text('El correo o la contraseña no coinciden'), findsOneWidget);
      expect(find.text('mariana@correo.co'), findsOneWidget);
    });

    testWidgets('una cuenta sin activar ofrece reenviar el enlace', (tester) async {
      final auth = FakeAuthRepository()
        ..errorAlEntrar = const AuthException('Aún no has activado tu cuenta.', code: 'email_not_confirmed');
      await abrirLogin(tester, auth);

      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'mariana@correo.co');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'clave1234');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reenviar enlace'));
      await tester.pumpAndSettle();

      expect(auth.llamadas.last, 'reenviar:mariana@correo.co');
    });

    testWidgets('valida el correo antes de llamar al servidor', (tester) async {
      final auth = FakeAuthRepository();
      await abrirLogin(tester, auth);
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'no-es-correo');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Escribe un correo válido, por ejemplo ana@gmail.com'), findsOneWidget);
      expect(auth.llamadas, isEmpty);
    });

    testWidgets('el aviso sale junto al botón Entrar y se quita al corregir', (tester) async {
      final auth = FakeAuthRepository()
        ..errorAlEntrar = const AuthException('El correo o la contraseña no coinciden.', code: 'invalid_credentials');
      await abrirLogin(tester, auth);

      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'mariana@correo.co');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'clave1234');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      // Debajo de los campos y del enlace de recuperar, encima del botón.
      final aviso = tester.getRect(find.text('El correo o la contraseña no coinciden'));
      expect(aviso.top, greaterThan(tester.getRect(find.text('¿Olvidaste tu contraseña?')).bottom));
      expect(aviso.bottom, lessThan(tester.getRect(find.text('Entrar')).top));

      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'clave12345');
      await tester.pump();
      expect(find.text('El correo o la contraseña no coinciden'), findsNothing);
    });

    testWidgets('sin conexión explica qué hacer, en español', (tester) async {
      final auth = FakeAuthRepository()..errorAlEntrar = traducirErrorAuth(AuthRetryableFetchException());
      await abrirLogin(tester, auth);

      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'mariana@correo.co');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'clave1234');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('No pudimos iniciar sesión'), findsOneWidget);
      expect(find.text('No hay conexión con el servidor. Revisa tu internet e inténtalo de nuevo.'), findsOneWidget);
    });
  });

  group('Registro de gestor', () {
    Future<void> autorizarDatos(WidgetTester tester) async {
      final casilla = find.byType(CasillaAutorizacionDatos);
      await tester.ensureVisible(casilla);
      await tester.tap(find.descendant(of: casilla, matching: find.byType(Checkbox)));
      await tester.pump();
    }

    Future<void> irAVerificacion(WidgetTester tester, FakeAuthRepository auth, {ArchivoPdf? permiso}) async {
      usarPantallaAlta(tester);
      await tester.pumpWidget(
        app(
          RegistroScreen(
            authRepository: auth,
            cargarMateriales: () async => [carton],
            elegirPermiso: () async => permiso,
          ),
        ),
      );
      await tester.tap(find.text('Soy gestor certificado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }

    Future<void> verificarNit(WidgetTester tester, String nit) async {
      await tester.enterText(find.widgetWithText(TextField, 'NIT'), nit);
      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();
    }

    testWidgets('el error al verificar sale en la barra, junto al botón que lo provocó', (tester) async {
      final auth = FakeAuthRepository()
        ..gestorDirectorio = GestorDirectorio(
          id: _gestorDirectorio.id,
          nit: _gestorDirectorio.nit,
          razonSocial: _gestorDirectorio.razonSocial,
          emailOficial: _gestorDirectorio.emailOficial,
          estadoVerificacion: 'APROBADO',
          usuarioId: 'cuenta-existente',
        );
      await irAVerificacion(tester, auth);
      await verificarNit(tester, '900.456.789-2');

      final mensaje = find.text('Esta empresa ya tiene una cuenta. Inicia sesión con el correo de la empresa.');
      expect(find.descendant(of: find.byType(BotonFijoInferior), matching: mensaje), findsOneWidget);
    });

    testWidgets('con el NIT de una empresa registrada se llenan los datos y los materiales', (tester) async {
      final auth = FakeAuthRepository()..gestorDirectorio = _gestorDirectorio;
      await irAVerificacion(tester, auth);
      await verificarNit(tester, '900.456.789-2');

      expect(find.text('Encontramos tu empresa'), findsOneWidget);
      expect(find.text('operaciones@reciclajes.co'), findsOneWidget);
      expect(find.text('6076462210'), findsOneWidget);
      expect(find.text('Cra 15 # 8-42'), findsOneWidget);
      expect(find.text('Girón'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'clave1234');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirma la contraseña'), 'clave1234');

      // Sin la autorización de datos (Ley 1581) no se avanza.
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Para crear la cuenta debes autorizar el tratamiento de tus datos.'), findsOneWidget);
      expect(find.textContaining('Marcamos los que tu empresa ya tiene registrados'), findsNothing);

      await autorizarDatos(tester);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Marcamos los que tu empresa ya tiene registrados'), findsOneWidget);

      await tester.tap(find.text('Enviar para verificación'));
      await tester.pumpAndSettle();

      expect(auth.llamadas.last, 'registroGestor:1');
      expect(find.text('Revisa tu correo'), findsOneWidget);
    });

    testWidgets('una empresa registrada sin correo no puede activar la cuenta', (tester) async {
      final auth = FakeAuthRepository()
        ..gestorDirectorio = const GestorDirectorio(
          id: 8,
          nit: '900111222',
          razonSocial: 'Sin Correo S.A.S.',
          estadoVerificacion: 'APROBADO',
        );
      await irAVerificacion(tester, auth);
      await verificarNit(tester, '900111222');

      expect(find.textContaining('no tiene un correo registrado'), findsOneWidget);
    });

    testWidgets('un NIT que no encontramos registra la empresa con su permiso en PDF', (tester) async {
      final auth = FakeAuthRepository();
      await irAVerificacion(
        tester,
        auth,
        permiso: ArchivoPdf(nombre: 'licencia_cdmb.pdf', bytes: Uint8List.fromList([37, 80, 68, 70])),
      );
      await verificarNit(tester, '901234567');

      expect(find.text('No encontramos tu empresa'), findsOneWidget);
      await tester.tap(find.text('Registrar mi empresa'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Razón social'), 'Recuperadora Santander S.A.S.');
      await tester.enterText(find.widgetWithText(TextField, 'Representante legal'), 'Laura Gómez');
      await tester.enterText(find.widgetWithText(TextField, 'Teléfono'), '3001234567');
      await tester.enterText(find.widgetWithText(TextField, 'Dirección'), 'Cl 45 # 12-30');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bucaramanga').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Correo de la empresa'), 'gerencia@recuperadora.co');
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'clave1234');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirma la contraseña'), 'clave1234');
      await autorizarDatos(tester);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Adjunta el permiso en PDF'), findsOneWidget);

      await tester.tap(find.text('Elegir PDF'));
      await tester.pumpAndSettle();
      expect(find.text('licencia_cdmb.pdf'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aprovechable'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cartón corrugado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar para verificación'));
      await tester.pumpAndSettle();

      expect(
        auth.llamadas,
        containsAllInOrder(['permiso:licencia_cdmb.pdf', 'registroGestorNuevo:901234567:registro/abc.pdf:1']),
      );
      expect(find.text('Revisa tu correo'), findsOneWidget);
    });
  });

  group('Recuperar contraseña', () {
    testWidgets('el código se verifica solo al escribir el sexto dígito', (tester) async {
      final auth = FakeAuthRepository();
      await tester.pumpWidget(app(VerificarRecuperacionScreen(email: 'mariana@correo.co', authRepository: auth)));
      expect(find.text('Lo enviamos a m•••••@correo.co. Vence en 10 minutos.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '481902');
      await tester.pumpAndSettle();

      expect(auth.llamadas, ['otp:481902']);
      expect(find.byType(RestablecerPasswordScreen), findsOneWidget);
    });

    testWidgets('un código incorrecto se explica sin salir de la pantalla', (tester) async {
      final auth = FakeAuthRepository()
        ..errorOtp = const AuthException('El código no coincide. Revisa el correo más reciente.');
      await tester.pumpWidget(app(VerificarRecuperacionScreen(email: 'mariana@correo.co', authRepository: auth)));
      await tester.enterText(find.byType(TextField), '000000');
      await tester.pumpAndSettle();

      expect(find.text('El código no coincide. Revisa el correo más reciente.'), findsOneWidget);
      expect(find.byType(RestablecerPasswordScreen), findsNothing);
    });

    testWidgets('la contraseña nueva cumple las reglas antes de guardarse', (tester) async {
      final auth = FakeAuthRepository();
      await tester.pumpWidget(app(RestablecerPasswordScreen(authRepository: auth)));

      await tester.enterText(find.widgetWithText(TextFormField, 'Nueva contraseña'), 'corta');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('La contraseña necesita al menos 8 caracteres.'), findsOneWidget);
      expect(auth.llamadas, isEmpty);

      // Solo números: la lista exige también una letra, como el registro.
      await tester.enterText(find.widgetWithText(TextFormField, 'Nueva contraseña'), '12345678');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confírmala'), '12345678');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('La contraseña necesita al menos una letra.'), findsOneWidget);
      expect(auth.llamadas, isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nueva contraseña'), 'clave1234');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confírmala'), 'clave1234');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();

      expect(auth.llamadas, ['contrasena', 'salir']);
      expect(find.text('Contraseña actualizada'), findsOneWidget);
    });
  });
}
