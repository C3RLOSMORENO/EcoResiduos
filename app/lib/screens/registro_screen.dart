import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/eco_colors.dart';

/// Pantalla de Registro y Verificación de EcoResiduos.
/// Implementa Material Design 3 con soporte para dos perfiles:
/// 1. Generador (Persona / Empresa) - Registro directo con datos de contacto y municipio.
/// 2. Gestor Ambiental - Flujo de verificación y reclamo de empresa precargada con OTP.
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _generadorFormKey = GlobalKey<FormState>();
  final _gestorFormKey = GlobalKey<FormState>();

  // Controladores - Generador
  final _nombreController = TextEditingController();
  final _documentoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _municipioSeleccionado = 'BUCARAMANGA';

  // Controladores - Gestor
  final _gestorNitEmailController = TextEditingController();
  final _gestorOtpController = TextEditingController();
  final _gestorPasswordController = TextEditingController();
  final _gestorConfirmPasswordController = TextEditingController();
  bool _otpEnviado = false;
  String? _gestorEmailDestino;

  // Estados UI
  int _selectedTabIndex = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  final List<String> _municipios = const [
    'BUCARAMANGA',
    'FLORIDABLANCA',
    'GIRÓN',
    'PIEDECUESTA',
    'OTRO',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _selectedTabIndex) {
        setState(() {
          _selectedTabIndex = _tabController.index;
          _errorMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nombreController.dispose();
    _documentoController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _gestorNitEmailController.dispose();
    _gestorOtpController.dispose();
    _gestorPasswordController.dispose();
    _gestorConfirmPasswordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LÓGICA DE REGISTRO - GENERADOR
  // ---------------------------------------------------------------------------
  Future<void> _registrarGenerador() async {
    if (!_generadorFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final nombre = _nombreController.text.trim();
      final documento = _documentoController.text.trim();
      final telefono = _telefonoController.text.trim();
      final supabase = Supabase.instance.client;

      // Registro en Supabase Auth con metadatos (el Trigger del servidor crea usuarios y perfiles_generador)
      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'rol': 'GENERADOR',
          'nombre_completo_o_empresa': nombre,
          'documento_nit': documento,
          'telefono': telefono,
          'municipio': _municipioSeleccionado,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cuenta de generador creada con éxito!'),
            backgroundColor: EcoColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (error) {
      debugPrint('Error de Auth: ${error.message}');
      setState(() => _errorMessage = error.message);
    } catch (e) {
      debugPrint('Error inesperado: $e');
      setState(
        () => _errorMessage =
            'Ocurrió un error al registrar la cuenta.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // LÓGICA DE VERIFICACIÓN - GESTOR AMBIENTAL
  // ---------------------------------------------------------------------------
  Future<void> _solicitarOtpGestor() async {
    if (!_gestorFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final query = _gestorNitEmailController.text.trim();
      final supabase = Supabase.instance.client;

      // 1. Buscar en la tabla perfiles_gestor por NIT o por email_contacto
      final response = await supabase
          .from('perfiles_gestor')
          .select('id, razon_social, email_contacto, usuario_id')
          .or('nit.eq.$query,email_contacto.eq.$query')
          .maybeSingle();

      if (response == null) {
        throw const AuthException(
          'No se encontró ningún gestor autorizado con ese NIT o correo. Contacta a la autoridad ambiental.',
        );
      }

      if (response['usuario_id'] != null) {
        throw const AuthException(
          'Este gestor ya ha sido verificado y reclamado. Por favor inicia sesión con tu correo y contraseña.',
        );
      }

      final emailDestino = response['email_contacto'] as String;
      _gestorEmailDestino = emailDestino;

      // 2. Enviar código OTP oficial de Supabase Auth
      await supabase.auth.signInWithOtp(
        email: emailDestino,
        shouldCreateUser: true,
      );

      setState(() {
        _otpEnviado = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Código de verificación enviado a $emailDestino'),
            backgroundColor: EcoColors.primary,
          ),
        );
      }
    } on AuthException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (e) {
      setState(() => _errorMessage = 'Error al validar el gestor ambiental.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verificarCodigoGestor() async {
    final token = _gestorOtpController.text.trim();
    final password = _gestorPasswordController.text;
    final confirmPassword = _gestorConfirmPasswordController.text;

    if (token.isEmpty) {
      setState(
        () => _errorMessage = 'Por favor ingresa el código de 6 dígitos.',
      );
      return;
    }

    if (password.length < 6) {
      setState(
        () => _errorMessage = 'La contraseña debe tener al menos 6 caracteres.',
      );
      return;
    }

    if (password != confirmPassword) {
      setState(
        () => _errorMessage = 'Las contraseñas no coinciden.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // 1. Validar OTP con Supabase Auth
      final authResponse = await supabase.auth.verifyOTP(
        type: OtpType.magiclink,
        token: token,
        email: _gestorEmailDestino,
      );

      final user = authResponse.user ?? supabase.auth.currentUser;
      if (user != null) {
        // 2. Establecer la contraseña definitiva y asignar rol GESTOR en auth
        await supabase.auth.updateUser(
          UserAttributes(
            password: password,
            data: {'rol': 'GESTOR'},
          ),
        );

        // 3. Crear/Actualizar en la tabla pública usuarios con rol GESTOR
        await supabase.from('usuarios').upsert({
          'id': user.id,
          'email': user.email ?? _gestorEmailDestino,
          'rol': 'GESTOR',
        });

        // 4. Actualizar el perfil del gestor vinculando el usuario_id y aprobando
        await supabase
            .from('perfiles_gestor')
            .update({'usuario_id': user.id, 'estado_verificacion': 'APROBADO'})
            .eq('email_contacto', _gestorEmailDestino!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Gestor verificado y contraseña guardada con éxito!'),
              backgroundColor: EcoColors.primary,
            ),
          );
          Navigator.pop(context);
        }
      }
    } on AuthException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (e) {
      setState(() => _errorMessage = 'Código inválido o expirado.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS DE UI (MD3 COMPLIANT)
  // ---------------------------------------------------------------------------
  Widget _crearTextFormField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, color: EcoColors.onSurfaceVariant),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: EcoColors.surfaceVariant.withValues(alpha: 0.35),
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
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: EcoColors.error, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: EcoColors.onSurface),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Crea tu Cuenta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: EcoColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Selecciona tu tipo de perfil para continuar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: EcoColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Selector Material Design 3 de Perfiles
              Container(
                decoration: BoxDecoration(
                  color: EcoColors.surfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  onTap: (index) {
                    setState(() {
                      _selectedTabIndex = index;
                      _errorMessage = null;
                    });
                  },
                  dividerColor: Colors.transparent,
                  dividerHeight: 0.0,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: EcoColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: EcoColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: EcoColors.onSurfaceVariant,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.recycling_rounded, size: 20),
                      text: 'Generador',
                    ),
                    Tab(
                      icon: Icon(Icons.verified_rounded, size: 20),
                      text: 'Gestor Ambiental',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Mensaje de Error global
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: EcoColors.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: EcoColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: EcoColors.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: EcoColors.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Vistas según la pestaña seleccionada con auto-ajuste de altura y animación
              AnimatedCrossFade(
                firstChild: _buildFormGenerador(),
                secondChild: _buildFormGestor(),
                crossFadeState: _selectedTabIndex == 0
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 250),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FORMULARIO: GENERADOR (Persona / Empresa)
  // ---------------------------------------------------------------------------
  Widget _buildFormGenerador() {
    return Form(
      key: _generadorFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _crearTextFormField(
            controller: _nombreController,
            labelText: 'Nombre Completo o Empresa',
            hintText: 'Ej. María Pérez o EcoEmpresa S.A.S.',
            prefixIcon: Icons.person_outline_rounded,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Ingresa tu nombre o empresa'
                : null,
          ),
          const SizedBox(height: 14),

          _crearTextFormField(
            controller: _documentoController,
            labelText: 'Documento o NIT',
            hintText: 'Ej. 1098765432 o 900123456-1',
            prefixIcon: Icons.badge_outlined,
            keyboardType: TextInputType.text,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Ingresa el documento o NIT'
                : null,
          ),
          const SizedBox(height: 14),

          _crearTextFormField(
            controller: _telefonoController,
            labelText: 'Teléfono',
            hintText: 'Ej. 3001234567',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Ingresa un número de contacto'
                : null,
          ),
          const SizedBox(height: 14),

          // Selector Desplegable de Municipio
          DropdownButtonFormField<String>(
            initialValue: _municipioSeleccionado,
            isExpanded: true,
            dropdownColor: EcoColors.background,
            borderRadius: BorderRadius.circular(16),
            menuMaxHeight: 260,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: EcoColors.onSurfaceVariant,
            ),
            decoration: InputDecoration(
              labelText: 'Municipio',
              prefixIcon: const Icon(
                Icons.location_city_rounded,
                color: EcoColors.onSurfaceVariant,
              ),
              filled: true,
              fillColor: EcoColors.surfaceVariant.withValues(alpha: 0.35),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: EcoColors.primary, width: 2),
              ),
            ),
            items: _municipios.map((m) {
              return DropdownMenuItem(
                value: m,
                child: Text(
                  m,
                  style: const TextStyle(
                    fontSize: 15,
                    color: EcoColors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _municipioSeleccionado = val);
            },
          ),
          const SizedBox(height: 14),

          _crearTextFormField(
            controller: _emailController,
            labelText: 'Correo electrónico',
            hintText: 'ejemplo@correo.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Ingresa tu correo';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                return 'Correo inválido';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          _crearTextFormField(
            controller: _passwordController,
            labelText: 'Contraseña',
            hintText: 'Mínimo 6 caracteres',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: EcoColors.onSurfaceVariant,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
          ),
          const SizedBox(height: 14),

          _crearTextFormField(
            controller: _confirmPasswordController,
            labelText: 'Confirmar Contraseña',
            hintText: 'Repite tu contraseña',
            prefixIcon: Icons.lock_reset_rounded,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: EcoColors.onSurfaceVariant,
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Confirma tu contraseña';
              }
              if (v != _passwordController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _isLoading ? null : _registrarGenerador,
              style: FilledButton.styleFrom(
                backgroundColor: EcoColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'CREAR CUENTA DE GENERADOR',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FORMULARIO: GESTOR AMBIENTAL (Verificación OTP de Empresa Precargada)
  // ---------------------------------------------------------------------------
  Widget _buildFormGestor() {
    return Form(
      key: _gestorFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: EcoColors.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: EcoColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Los gestores ambientales deben estar previamente autorizados. Ingresa tu NIT o correo registrado para verificar tu empresa.',
                    style: TextStyle(
                      fontSize: 13,
                      color: EcoColors.onPrimaryContainer,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (!_otpEnviado) ...[
            _crearTextFormField(
              controller: _gestorNitEmailController,
              labelText: 'NIT o Correo Oficial de la Empresa',
              hintText: 'Ej. 900987654 o contacto@gestor.com',
              prefixIcon: Icons.domain_rounded,
              textInputAction: TextInputAction.done,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Ingresa el NIT o correo registrado'
                  : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _solicitarOtpGestor,
                icon: const Icon(Icons.send_rounded),
                label: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'ENVIAR CÓDIGO DE VERIFICACIÓN',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                style: FilledButton.styleFrom(
                  backgroundColor: EcoColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ] else ...[
            _crearTextFormField(
              controller: _gestorOtpController,
              labelText: 'Código de 6 dígitos',
              hintText: 'Ingresa el código enviado a tu correo',
              prefixIcon: Icons.pin_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),

            _crearTextFormField(
              controller: _gestorPasswordController,
              labelText: 'Crear Contraseña de Acceso',
              hintText: 'Mínimo 6 caracteres',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: EcoColors.onSurfaceVariant,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
            ),
            const SizedBox(height: 14),

            _crearTextFormField(
              controller: _gestorConfirmPasswordController,
              labelText: 'Confirmar Contraseña',
              hintText: 'Repite tu contraseña',
              prefixIcon: Icons.lock_reset_rounded,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: EcoColors.onSurfaceVariant,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Confirma tu contraseña';
                }
                if (v != _gestorPasswordController.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _otpEnviado = false),
              child: const Text('Cambiar NIT o correo de búsqueda'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _isLoading ? null : _verificarCodigoGestor,
                style: FilledButton.styleFrom(
                  backgroundColor: EcoColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'VERIFICAR Y GUARDAR CONTRASEÑA',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
