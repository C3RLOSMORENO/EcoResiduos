import 'package:ecoresiduos/features/auth/models/gestor_padron.dart';
import 'package:ecoresiduos/features/auth/screens/login_screen.dart';
import 'package:ecoresiduos/features/auth/screens/registro_screen.dart';
import 'package:ecoresiduos/features/auth/screens/restablecer_password_screen.dart';
import 'package:ecoresiduos/features/auth/screens/verificar_recuperacion_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes.dart';

const _padron = GestorPadron(
  id: 7,
  nit: '900456789',
  razonSocial: 'Reciclajes del Oriente S.A.S.',
  emailOficial: 'operaciones@reciclajes.co',
  estadoVerificacion: 'APROBADO',
);

void main() {
  group('Login', () {
    testWidgets('credenciales incorrectas muestran el aviso sin perder los datos', (tester) async {
      final auth = FakeAuthRepository()
        ..errorAlEntrar = const AuthException('El correo o la contraseña no coinciden.', code: 'invalid_credentials');
      await tester.pumpWidget(app(LoginScreen(authRepository: auth)));

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
      await tester.pumpWidget(app(LoginScreen(authRepository: auth)));

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
      await tester.pumpWidget(app(LoginScreen(authRepository: auth)));
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), 'no-es-correo');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un correo electrónico válido'), findsOneWidget);
      expect(auth.llamadas, isEmpty);
    });
  });

  group('Registro de gestor', () {
    Future<void> irAVerificacion(WidgetTester tester, FakeAuthRepository auth) async {
      await tester.pumpWidget(app(RegistroScreen(authRepository: auth, cargarMateriales: () async => [carton])));
      await tester.tap(find.text('Soy gestor certificado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }

    testWidgets('un NIT fuera del padrón no puede registrarse', (tester) async {
      final auth = FakeAuthRepository();
      await irAVerificacion(tester, auth);

      await tester.enterText(find.widgetWithText(TextField, 'NIT'), '900.456.789-2');
      await tester.enterText(find.widgetWithText(TextField, 'Correo de la empresa'), 'operaciones@reciclajes.co');
      await tester.tap(find.text('Verificar en el padrón'));
      await tester.pumpAndSettle();

      expect(find.text('No encontramos ese NIT en el padrón'), findsOneWidget);
    });

    testWidgets('el correo debe ser el que tiene la empresa en el padrón', (tester) async {
      final auth = FakeAuthRepository()..padron = _padron;
      await irAVerificacion(tester, auth);

      await tester.enterText(find.widgetWithText(TextField, 'NIT'), '900456789');
      await tester.enterText(find.widgetWithText(TextField, 'Correo de la empresa'), 'otro@correo.co');
      await tester.tap(find.text('Verificar en el padrón'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ese correo no es el que tiene la empresa en el padrón'), findsOneWidget);
    });

    testWidgets('declara materiales y envía la cuenta a verificación', (tester) async {
      usarPantallaAlta(tester);
      final auth = FakeAuthRepository()..padron = _padron;
      await irAVerificacion(tester, auth);

      await tester.enterText(find.widgetWithText(TextField, 'NIT'), '900456789');
      await tester.enterText(find.widgetWithText(TextField, 'Correo de la empresa'), 'operaciones@reciclajes.co');
      await tester.tap(find.text('Verificar en el padrón'));
      await tester.pumpAndSettle();

      expect(find.text('Encontramos tu empresa'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Teléfono'), '6076462210');
      await tester.enterText(find.widgetWithText(TextField, 'Dirección'), 'Cra 15 # 8-42');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Girón').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'clave1234');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enviar para verificación'));
      await tester.pumpAndSettle();
      expect(find.text('Elige al menos un material que tu licencia te permita recibir.'), findsOneWidget);

      await tester.tap(find.text('Aprovechable'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cartón corrugado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar para verificación'));
      await tester.pumpAndSettle();

      expect(auth.llamadas.last, 'registroGestor:1');
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
      expect(find.text('Cumple las tres reglas para continuar.'), findsOneWidget);
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
