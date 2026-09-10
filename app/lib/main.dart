import 'package:flutter/material.dart';

import 'screens/autoridades_ambientales_screen.dart';
import 'screens/buscar_residuo_screen.dart';
import 'screens/camara_screen.dart';
import 'screens/gestores_asociados_screen.dart';
import 'screens/guia_manejo_general_screen.dart';
import 'screens/identificar_residuo_screen.dart';
import 'screens/inicio_screen.dart';
import 'screens/permiso_camara_dialog.dart';
import 'screens/procesando_screen.dart';
import 'screens/login_screen.dart';
import 'theme/eco_theme.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");

  try {
    await Supabase.initialize(
      url: 'https://pjpuhhoaxkakvkmpyruk.supabase.co',
      publishableKey: 'sb_publishable_b3taKmvPTaoIa3nBffrr9A_YeJR2HL1',
    );
  } catch (e) {
    debugPrint('Nota: Supabase no inicializado correctamente. Falta Anon Key.');
  }

  runApp(const EcoResiduosApp());
}

class EcoResiduosApp extends StatelessWidget {
  const EcoResiduosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoResiduos',
      debugShowCheckedModeBanner: false,
      theme: ecoResiduosTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = Supabase.instance.client.auth.currentUser;
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _user = data.session?.user;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const LoginScreen();
    }

    return InicioScreen(
      onAbrirCamara: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IdentificarResiduoScreen(
            onAbrirCamara: () => _iniciarCaptura(context),
          ),
        ),
      ),
      onBuscarResiduo: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const BuscarResiduoScreen(),
        ),
      ),
      onGuiaDeManejo: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const GuiaManejoGeneralScreen(),
        ),
      ),
      onGestoresCertificados: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const GestoresAsociadosScreen(),
        ),
      ),
      onAutoridadesAmbientales: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AutoridadesAmbientalesScreen(),
        ),
      ),
    );
  }

  /// Flujo completo: WF-02 → WF-03 (diálogo) → WF-04 (cámara) →
  /// WF-05 (procesando) → WF-06 (resultado) → WF-07 (información) →
  /// WF-08 (manejo). Los estados de error (WF-12/13/14) y la navegación
  /// posterior al resultado ya quedan resueltos dentro de
  /// ProcesandoScreen — no hace falta tocar nada aquí para eso.
  Future<void> _iniciarCaptura(BuildContext context) async {
    // 1. Verificar si ya tenemos permiso
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (context.mounted) _irACamara(context);
      return;
    }

    // 2. Si no, mostramos el diálogo educativo
    if (!context.mounted) return;
    final permitido = await showPermisoCamaraDialog(context);
    if (permitido != true || !context.mounted) return;

    // 3. Solicitamos el permiso real al SO
    final nuevoStatus = await Permission.camera.request();
    if (nuevoStatus.isGranted && context.mounted) {
      _irACamara(context);
    }
  }

  void _irACamara(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CamaraScreen(
          onCapturar: (imagePath) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ProcesandoScreen(imagePath: imagePath),
              ),
            );
          },
        ),
      ),
    );
  }
}
