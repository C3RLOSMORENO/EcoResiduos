import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/eco_theme.dart';
import '../../../widgets/eco_logo.dart';
import '../repositories/auth_repository.dart';
import '../widgets/campo_contrasena.dart';
import 'registro_screen.dart';
import 'solicitar_recuperacion_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Fondo base (Color sólido profundo)
          Container(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),

          // 2. Animaciones de Malla / Blobs de fondo (Mesh Gradient / Aurora effect)
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: isDark ? 0.3 : 0.4),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1.0, end: 1.3, duration: 6.seconds, curve: Curves.easeInOut)
            .move(begin: const Offset(0, 0), end: const Offset(50, 50), duration: 7.seconds, curve: Curves.easeInOut),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.tertiary.withValues(alpha: isDark ? 0.3 : 0.4),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1.0, end: 1.4, duration: 8.seconds, curve: Curves.easeInOut)
            .move(begin: const Offset(0, 0), end: const Offset(-50, -30), duration: 9.seconds, curve: Curves.easeInOut),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.3,
            right: -150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.secondary.withValues(alpha: isDark ? 0.2 : 0.3),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .move(begin: const Offset(0, 0), end: const Offset(-80, 80), duration: 10.seconds, curve: Curves.easeInOut),
          ),

          // 3. Filtro de desenfoque masivo para fusionar los colores (Efecto cristal en todo el fondo)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox(),
            ),
          ),

          // 4. Contenido principal
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s24, vertical: EcoSpace.s32),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Encabezado con animación de "flote"
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(EcoSpace.s16),
                              decoration: BoxDecoration(
                                color: scheme.surface.withValues(alpha: isDark ? 0.2 : 0.4),
                                shape: BoxShape.circle,
                                border: Border.all(color: scheme.outline.withValues(alpha: 0.1)),
                              ),
                              child: const EcoLogo(width: 80, showBadge: false),
                            )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .moveY(begin: -5, end: 5, duration: 3.seconds, curve: Curves.easeInOut),
                            
                            const SizedBox(height: EcoSpace.s24),
                            Text(
                              'Bienvenido de vuelta',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: isDark ? Colors.white : scheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: EcoSpace.s8),
                            Text(
                              'Ingresa tus datos para continuar',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: isDark ? Colors.white70 : scheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.2, end: 0, curve: Curves.easeOutBack),

                        const SizedBox(height: EcoSpace.s40),

                        // Tarjeta de Login Glassmorphism
                        ClipRRect(
                          borderRadius: BorderRadius.circular(EcoRadius.extraLarge),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: const EdgeInsets.all(EcoSpace.s24),
                              decoration: BoxDecoration(
                                color: scheme.surface.withValues(alpha: isDark ? 0.3 : 0.6),
                                borderRadius: BorderRadius.circular(EcoRadius.extraLarge),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 24,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_aviso != _AvisoLogin.ninguno) ...[
                                    _banner().animate().fadeIn().slideY(begin: -0.1),
                                    const SizedBox(height: EcoSpace.s24),
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
                                      labelText: 'Correo electrónico',
                                      prefixIcon: Icon(Icons.email_rounded, color: scheme.primary),
                                      filled: true,
                                      fillColor: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.7),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(EcoRadius.medium),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(EcoRadius.medium),
                                        borderSide: BorderSide(color: scheme.primary, width: 2),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: EcoSpace.s20),

                                  // Campo Contraseña
                                  CampoContrasena(
                                    controller: _contrasena,
                                    validator: (v) => (v ?? '').isEmpty ? 'Escribe tu contraseña' : null,
                                    onSubmitted: (_) => _entrar(),
                                  ),

                                  const SizedBox(height: EcoSpace.s8),

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => SolicitarRecuperacionScreen(authRepository: _auth)),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: isDark ? Colors.white70 : scheme.primary,
                                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      child: const Text('¿Olvidaste tu contraseña?'),
                                    ),
                                  ),

                                  const SizedBox(height: EcoSpace.s24),

                                  // Botón principal
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(56),
                                      backgroundColor: scheme.primary,
                                      foregroundColor: scheme.onPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(EcoRadius.medium),
                                      ),
                                      elevation: 8,
                                      shadowColor: scheme.primary.withValues(alpha: 0.5),
                                    ),
                                    onPressed: _cargando ? null : _entrar,
                                    child: _cargando
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                          )
                                        : const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                  ).animate(target: _cargando ? 0 : 1).shimmer(duration: 2.5.seconds, color: Colors.white.withValues(alpha: 0.2)),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(duration: 800.ms, delay: 200.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),

                        const SizedBox(height: EcoSpace.s32),

                        // Enlace a registro
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('¿No tienes cuenta?', style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white70 : scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            )),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => RegistroScreen(authRepository: _auth),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: scheme.primary,
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              child: const Text('Regístrate'),
                            ),
                          ],
                        ).animate().fadeIn(duration: 800.ms, delay: 400.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
          color: sinActivar ? scheme.primary.withValues(alpha: 0.3) : scheme.error.withValues(alpha: 0.3)
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
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSecondaryContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }
}


