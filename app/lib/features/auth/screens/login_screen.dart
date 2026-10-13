import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/eco_theme.dart';
import '../../../widgets/eco_logo.dart';
import '../repositories/auth_repository.dart';
import '../widgets/campo_contrasena.dart';
import 'registro_screen.dart';
import 'solicitar_recuperacion_screen.dart';

/// Inicio de sesión con correo y contraseña, con enlaces al registro y a
/// recuperar la contraseña. [authRepository] se reemplaza en las pruebas.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _AvisoLogin { ninguno, credenciales, sinActivar, otro }

class _LoginScreenState extends State<LoginScreen> {
  late final AuthRepository _auth = widget.authRepository ?? SupabaseAuthRepository();
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();

  bool _cargando = false;
  _AvisoLogin _aviso = _AvisoLogin.ninguno;
  String _mensajeOtro = '';

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _aviso = _AvisoLogin.ninguno;
    });
    try {
      await _auth.signIn(email: _correo.text.trim(), password: _contrasena.text);
    } on AuthException catch (e) {
      setState(() {
        if (e.code == 'email_not_confirmed') {
          _aviso = _AvisoLogin.sinActivar;
        } else if (e.code == 'invalid_credentials' || e.message.contains('no coinciden')) {
          _aviso = _AvisoLogin.credenciales;
        } else {
          _aviso = _AvisoLogin.otro;
          _mensajeOtro = e.message;
        }
      });
    } catch (e) {
      setState(() {
        _aviso = _AvisoLogin.otro;
        _mensajeOtro = 'No pudimos conectarnos. Revisa tu conexión e inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _reenviarEnlace() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _auth.reenviarConfirmacion(_correo.text.trim());
      messenger.showSnackBar(
        const SnackBar(content: Text('Enviamos un enlace nuevo. Revisa también la carpeta de spam.')),
      );
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('No pudimos reenviar el enlace. Inténtalo en un minuto.')));
    }
  }

  Widget _buildCategoryChip(String label, IconData icon, Color color, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(EcoRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Colores basados en el diseño de referencia
    final headerBgColor = scheme.primary; // Dark green
    final contentBgColor = isDark ? scheme.surface : const Color(0xFFF8F6EE); // Cream/Off-white
    final fieldBgColor = isDark ? scheme.surfaceContainerHigh : const Color(0xFFE6E3DB); // Input fields
    final textColorLight = Colors.white.withValues(alpha: 0.9);
    // Los íconos del encabezado flotan sin parar; se dejan quietos si el
    // usuario pidió reducir el movimiento en los ajustes de accesibilidad.
    final animarFondo = !MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: contentBgColor,
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header verde con borde ondulado
            ClipPath(
              clipper: _HeaderWaveClipper(),
              child: Container(
                color: headerBgColor,
                child: Stack(
                  children: [
                    // Iconos decorativos de fondo (flotantes y tenues)
                    Positioned(
                      top: 40,
                      right: 20,
                      child: Icon(Icons.recycling_rounded, size: 80, color: Colors.white.withValues(alpha: 0.05))
                          .animate(onPlay: (c) => animarFondo ? c.repeat(reverse: true) : c.stop())
                          .moveY(begin: -5, end: 5, duration: 4.seconds, curve: Curves.easeInOut),
                    ),
                    Positioned(
                      top: 150,
                      right: 30,
                      child: Icon(Icons.eco_rounded, size: 50, color: Colors.white.withValues(alpha: 0.04))
                          .animate(onPlay: (c) => animarFondo ? c.repeat(reverse: true) : c.stop())
                          .moveY(begin: 5, end: -5, duration: 3.seconds, curve: Curves.easeInOut),
                    ),
                    Positioned(
                      bottom: 80,
                      right: 40,
                      child:
                          Icon(
                                Icons.battery_charging_full_rounded,
                                size: 60,
                                color: Colors.white.withValues(alpha: 0.06),
                              )
                              .animate(onPlay: (c) => animarFondo ? c.repeat(reverse: true) : c.stop())
                              .moveX(begin: -5, end: 5, duration: 5.seconds, curve: Curves.easeInOut),
                    ),

                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(EcoSpace.s24, EcoSpace.s16, EcoSpace.s24, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Logo y marca
                            Row(
                              children: [
                                const EcoLogo(width: 48, showBadge: true),
                                const SizedBox(width: EcoSpace.s12),
                                Text(
                                  'EcoResiduos',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1),

                            const SizedBox(height: EcoSpace.s16),

                            // Titulo principal
                            Text(
                              'Lo que sobra,\nvuelve a servir.',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                letterSpacing: -0.5,
                              ),
                            ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.1),

                            const SizedBox(height: EcoSpace.s8),

                            // Subtítulo
                            Text(
                              'Identifica tus residuos, publícalos y conecta con gestores ambientales de Santander.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: textColorLight, height: 1.4),
                            ).animate().fadeIn(duration: 600.ms, delay: 300.ms),

                            const SizedBox(height: EcoSpace.s16),

                            // Chips de categorias
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildCategoryChip(
                                  'Aprovechables',
                                  Icons.recycling_rounded,
                                  const Color(0xFFCDEBF5),
                                  const Color(0xFF003544),
                                ),
                                _buildCategoryChip(
                                  'Electrónicos',
                                  Icons.devices_rounded,
                                  const Color(0xFFE8DEFF),
                                  const Color(0xFF2F1A75),
                                ),
                                _buildCategoryChip(
                                  'Peligrosos',
                                  Icons.science_rounded,
                                  const Color(0xFFFFE08A),
                                  const Color(0xFF1F1600),
                                ),
                                _buildCategoryChip(
                                  'Escombros',
                                  Icons.construction_rounded,
                                  const Color(0xFFF0E2D6),
                                  const Color(0xFF3A2C20),
                                ),
                              ],
                            ).animate().fadeIn(duration: 600.ms, delay: 400.ms).scaleXY(begin: 0.95),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Formulario inferior (Crema)
            Padding(
              padding: const EdgeInsets.fromLTRB(EcoSpace.s24, 0, EcoSpace.s24, EcoSpace.s16),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Hola de nuevo',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: isDark ? Colors.white : const Color(0xFF192313),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 500.ms),

                      const SizedBox(height: 4),
                      Text(
                        'Entra para seguir con tus residuos y\nrecolecciones.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white70 : const Color(0xFF4A4A4A),
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 600.ms),

                      const SizedBox(height: EcoSpace.s12),

                      if (_aviso != _AvisoLogin.ninguno) ...[
                        _banner().animate().fadeIn().slideY(begin: -0.1),
                        const SizedBox(height: EcoSpace.s16),
                      ],

                      // Campo Correo
                      TextFormField(
                        controller: _correo,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: validarCorreo,
                        style: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Correo',
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                          filled: true,
                          fillColor: fieldBgColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(EcoRadius.medium),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 700.ms).slideY(begin: 0.1),

                      const SizedBox(height: EcoSpace.s12),

                      // Campo Contraseña
                      CampoContrasena(
                        controller: _contrasena,
                        validator: (v) => (v ?? '').isEmpty ? 'Escribe tu contraseña' : null,
                        onSubmitted: (_) => _entrar(),
                        fillColor: fieldBgColor,
                      ).animate().fadeIn(duration: 600.ms, delay: 800.ms).slideY(begin: 0.1),

                      const SizedBox(height: 4),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SolicitarRecuperacionScreen(authRepository: _auth)),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.primary,
                            textStyle: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          child: const Text('¿Olvidaste tu contraseña?'),
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 900.ms),

                      const SizedBox(height: EcoSpace.s24),

                      // Botón principal
                      FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(EcoRadius.full), // Pastilla completa
                              ),
                              elevation: 0,
                            ),
                            onPressed: _cargando ? null : _entrar,
                            child: _cargando
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded, size: 20),
                                    ],
                                  ),
                          )
                          .animate(target: _cargando ? 0 : 1)
                          .shimmer(duration: 2.5.seconds, color: Colors.white.withValues(alpha: 0.2)),

                      const SizedBox(height: EcoSpace.s12),

                      // Enlace a registro. Wrap en lugar de Row: con letra grande
                      // «Regístrate» pasa a la línea siguiente en vez de desbordarse.
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '¿No tienes cuenta?',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white70 : const Color(0xFF4A4A4A),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    RegistroScreen(authRepository: _auth),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.05),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: scheme.primary,
                              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            child: const Text('Regístrate'),
                          ),
                        ],
                      ).animate().fadeIn(duration: 600.ms, delay: 1000.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final (icono, titulo, texto) = switch (_aviso) {
      _AvisoLogin.credenciales => (
        Icons.warning_amber_rounded,
        'El correo o la contraseña no coinciden',
        'Revísalos o recupera tu contraseña.',
      ),
      _AvisoLogin.sinActivar => (
        Icons.mark_email_unread_outlined,
        'Aún no has activado tu cuenta',
        'Abre el enlace que te enviamos a tu correo.',
      ),
      _ => (Icons.error_outline, 'No pudimos iniciar sesión', _mensajeOtro),
    };
    final sinActivar = _aviso == _AvisoLogin.sinActivar;

    return Container(
      padding: const EdgeInsets.all(EcoSpace.s16),
      decoration: BoxDecoration(
        color: sinActivar
            ? scheme.secondaryContainer.withValues(alpha: isDark ? 0.5 : 0.8)
            : scheme.errorContainer.withValues(alpha: isDark ? 0.5 : 0.8),
        borderRadius: BorderRadius.circular(EcoRadius.medium),
        border: Border.all(
          color: sinActivar ? scheme.primary.withValues(alpha: 0.3) : scheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: sinActivar ? scheme.onSecondaryContainer : scheme.onErrorContainer),
              const SizedBox(width: EcoSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    if (texto.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(texto, style: theme.textTheme.bodyMedium),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (sinActivar)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _reenviarEnlace,
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Reenviar enlace'),
                style: TextButton.styleFrom(foregroundColor: scheme.onSecondaryContainer),
              ),
            ),
        ],
      ),
    );
  }
}

// Custom Clipper para la forma ondulada del encabezado
class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 25);

    // Curva principal (suave y asimétrica)
    path.quadraticBezierTo(size.width * 0.35, size.height, size.width * 0.65, size.height - 15);
    path.quadraticBezierTo(size.width * 0.85, size.height - 25, size.width, size.height - 10);

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
