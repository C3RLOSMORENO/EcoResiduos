import 'package:ecoresiduos/features/auth/repositories/auth_repository.dart' show traducirErrorAuth;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String traducir(AuthException e) => traducirErrorAuth(e).message;

void main() {
  group('Errores de Supabase Auth en español', () {
    test('se reconocen por el código', () {
      expect(traducir(const AuthException('x', code: 'invalid_credentials')), 'El correo o la contraseña no coinciden.');
      expect(traducir(const AuthException('x', code: 'email_not_confirmed')), 'Aún no has activado tu cuenta.');
      expect(traducir(const AuthException('x', code: 'user_already_exists')), startsWith('Ya existe una cuenta'));
      expect(traducir(const AuthException('x', code: 'over_request_rate_limit')), startsWith('Hiciste varios intentos'));
      expect(traducir(const AuthException('x', code: 'over_email_send_rate_limit')), startsWith('Ya te enviamos un correo'));
    });

    test('la contraseña repetida no se confunde con una débil', () {
      expect(
        traducir(const AuthException('New password should be different from the old password.', code: 'same_password')),
        'La contraseña nueva debe ser distinta de la que tienes ahora.',
      );
      expect(
        traducir(const AuthException('Password should be at least 8 characters.', code: 'weak_password')),
        'La contraseña debe tener al menos 8 caracteres, con letras y números.',
      );
    });

    test('sin conexión se dice así, no con el error técnico', () {
      final mensaje = traducir(AuthRetryableFetchException(message: 'ClientException: Failed host lookup'));
      expect(mensaje, 'No hay conexión con el servidor. Revisa tu internet e inténtalo de nuevo.');
    });

    test('sin código, se reconoce por el texto en inglés', () {
      expect(traducir(const AuthException('Invalid login credentials')), 'El correo o la contraseña no coinciden.');
      expect(traducirErrorAuth(const AuthException('Invalid login credentials')).code, 'invalid_credentials');
    });

    test('un error desconocido nunca muestra el texto original', () {
      final mensaje = traducir(const AuthException('Database error saving new user', code: 'unexpected_failure'));
      expect(mensaje, 'Algo falló de nuestro lado. Inténtalo de nuevo en unos minutos.');
    });
  });
}
