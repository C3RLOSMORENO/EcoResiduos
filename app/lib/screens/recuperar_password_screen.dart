import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/eco_colors.dart';

class RecuperarPasswordScreen extends StatefulWidget {
  const RecuperarPasswordScreen({super.key});

  @override
  State<RecuperarPasswordScreen> createState() => _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends State<RecuperarPasswordScreen> {
  // Controladores Paso 1 (Email)
  final _formKeyPaso1 = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  // Controladores Paso 2 (OTP y Nueva Clave)
  final _formKeyPaso2 = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _pasoActual = 1; // 1: Pedir Email, 2: OTP y nueva contraseña
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// PASO 1: Enviar código OTP de 8 dígitos al correo
  Future<void> _enviarCodigoOtp() async {
    if (!_formKeyPaso1.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();

      await Supabase.instance.client.auth.resetPasswordForEmail(email);

      if (mounted) {
        setState(() {
          _pasoActual = 2;
          _errorMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Código de 8 dígitos enviado a $email'),
            backgroundColor: EcoColors.primary,
          ),
        );
      }
    } on AuthException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (e) {
      setState(() => _errorMessage = 'No se pudo enviar el código. Verifica tu conexión.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// PASO 2: Verificar OTP de 8 dígitos y actualizar contraseña
  Future<void> _verificarYActualizarClave() async {
    if (!_formKeyPaso2.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final token = _otpController.text.trim();
      final newPassword = _passwordController.text;

      // 1. Verificar OTP con tipo 'recovery'
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );

      // 2. Actualizar a la nueva contraseña
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      // 3. Cerrar sesión por seguridad para que inicie sesión con su nueva clave
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Contraseña actualizada con éxito! Por favor inicia sesión.'),
            backgroundColor: EcoColors.primary,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (error) {
      setState(() {
        if (error.message.toLowerCase().contains('otp') || error.message.toLowerCase().contains('token')) {
          _errorMessage = 'Código incorrecto o expirado. Revisa los 8 dígitos.';
        } else {
          _errorMessage = error.message;
        }
      });
    } catch (e) {
      setState(() => _errorMessage = 'Ocurrió un error al restablecer la contraseña.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: EcoColors.onSurface),
          onPressed: () {
            if (_pasoActual == 2) {
              setState(() {
                _pasoActual = 1;
                _errorMessage = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
            child: _pasoActual == 1 ? _buildPaso1Email() : _buildPaso2OtpYClave(),
          ),
        ),
      ),
    );
  }

  /// Vista del Paso 1: Ingreso de correo electrónico
  Widget _buildPaso1Email() {
    return Form(
      key: _formKeyPaso1,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: EcoColors.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              size: 64,
              color: EcoColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Restablecer Contraseña',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: EcoColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ingresa tu correo para recibir el código de verificación de 8 dígitos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: EcoColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 36),

          if (_errorMessage != null) _buildErrorCard(_errorMessage!),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _enviarCodigoOtp(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa tu correo electrónico';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                return 'Ingresa un correo electrónico válido';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'ejemplo@correo.com',
              prefixIcon: const Icon(Icons.email_outlined),
              filled: true,
              fillColor: EcoColors.surfaceVariant.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: EcoColors.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: EcoColors.error, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _isLoading ? null : _enviarCodigoOtp,
              style: FilledButton.styleFrom(
                backgroundColor: EcoColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Text(
                      'ENVIAR CÓDIGO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Vista del Paso 2: Validación de 8 dígitos y cambio de contraseña
  Widget _buildPaso2OtpYClave() {
    return Form(
      key: _formKeyPaso2,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: EcoColors.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.password_rounded,
              size: 64,
              color: EcoColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Código de Verificación',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: EcoColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ingresa el código de 8 dígitos enviado a:\n${_emailController.text.trim()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: EcoColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),

          if (_errorMessage != null) _buildErrorCard(_errorMessage!),

          // Campo Código OTP de 8 dígitos
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 8,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 6.0,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa el código de 8 dígitos';
              }
              if (value.trim().length < 6) {
                return 'El código debe tener al menos 6 dígitos';
              }
              return null;
            },
            decoration: InputDecoration(
              counterText: '',
              hintText: '12345678',
              hintStyle: TextStyle(
                letterSpacing: 6.0,
                color: EcoColors.outline.withValues(alpha: 0.6),
              ),
              prefixIcon: const Icon(Icons.pin_outlined),
              filled: true,
              fillColor: EcoColors.surfaceVariant.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: EcoColors.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: EcoColors.error, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Campo Nueva Contraseña
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa la nueva contraseña';
              }
              if (value.length < 6) {
                return 'La contraseña debe tener al menos 6 caracteres';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: EcoColors.onSurfaceVariant,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              filled: true,
              fillColor: EcoColors.surfaceVariant.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: EcoColors.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: EcoColors.error, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Campo Confirmar Contraseña
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _verificarYActualizarClave(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirma la nueva contraseña';
              }
              if (value != _passwordController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Confirmar nueva contraseña',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: EcoColors.onSurfaceVariant,
                ),
                onPressed: () {
                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                },
              ),
              filled: true,
              fillColor: EcoColors.surfaceVariant.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: EcoColors.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: EcoColors.error, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _isLoading ? null : _verificarYActualizarClave,
              style: FilledButton.styleFrom(
                backgroundColor: EcoColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Text(
                      'RESTABLECER Y GUARDAR',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          TextButton(
            onPressed: () {
              setState(() {
                _pasoActual = 1;
                _errorMessage = null;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: EcoColors.primary,
            ),
            child: const Text('¿Cambiar de correo o reenviar código?'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: EcoColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EcoColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: EcoColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: EcoColors.onErrorContainer, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
