import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/screens/login_screen.dart';
import 'screens/inicio_screen.dart';
import 'theme/eco_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: 'https://pjpuhhoaxkakvkmpyruk.supabase.co',
    publishableKey: 'sb_publishable_b3taKmvPTaoIa3nBffrr9A_YeJR2HL1',
  );
  runApp(const EcoResiduosApp());
}

class EcoResiduosApp extends StatelessWidget {
  const EcoResiduosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoResiduos',
      debugShowCheckedModeBanner: false,
      theme: ecoTheme(Brightness.light),
      darkTheme: ecoTheme(Brightness.dark),
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AuthGate(),
    );
  }
}

/// Muestra el login o la app según haya una sesión activa.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late User? _usuario = Supabase.instance.client.auth.currentUser;
  late final StreamSubscription<AuthState> _suscripcion;

  @override
  void initState() {
    super.initState();
    _suscripcion = Supabase.instance.client.auth.onAuthStateChange.listen((cambio) {
      final usuario = cambio.session?.user;
      if (mounted && usuario?.id != _usuario?.id) setState(() => _usuario = usuario);
    });
  }

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usuario = _usuario;
    if (usuario == null) return const LoginScreen();
    return InicioScreen(key: ValueKey(usuario.id));
  }
}
