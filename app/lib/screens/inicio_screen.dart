import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/eco_colors.dart';
import 'historial_screen.dart';

/// WF-01 — Inicio
///
/// Pantalla de inicio de EcoResiduos, recreada a partir del wireframe
/// "Wireframes MD3 — Gestión de residuos" (Figma). Ofrece accesos rápidos
/// para identificar un residuo con cámara, buscarlo, consultar guías de
/// manejo, gestores certificados y autoridades ambientales.
class InicioScreen extends StatelessWidget {
  const InicioScreen({
    super.key,
    this.onAbrirCamara,
    this.onBuscarResiduo,
    this.onGuiaDeManejo,
    this.onGestoresCertificados,
    this.onAutoridadesAmbientales,
    this.onPerfil,
  });

  final VoidCallback? onAbrirCamara;
  final VoidCallback? onBuscarResiduo;
  final VoidCallback? onGuiaDeManejo;
  final VoidCallback? onGestoresCertificados;
  final VoidCallback? onAutoridadesAmbientales;
  final VoidCallback? onPerfil;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String?;
    final firstName = fullName?.split(' ').first ?? '';
    final userInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: EcoColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(userInitial: userInitial, onPerfil: onPerfil),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  Text(
                    firstName.isNotEmpty 
                        ? 'Hola, $firstName 👋\n¿Qué residuo tienes?' 
                        : '¿Qué residuo tienes?',
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.3,
                      fontWeight: FontWeight.bold,
                      color: EcoColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _IdentificarResiduoCard(onAbrirCamara: onAbrirCamara),
                  const SizedBox(height: 16),
                  _AccionItem(
                    icon: Icons.history_rounded,
                    title: 'Mi Historial',
                    subtitle: 'Tus residuos identificados',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistorialScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _AccionItem(
                    icon: Icons.search_rounded,
                    title: 'Buscar residuo',
                    subtitle: 'Consulta por nombre o categoría',
                    onTap: onBuscarResiduo,
                  ),
                  const SizedBox(height: 12),
                  _AccionItem(
                    icon: Icons.menu_book_rounded,
                    title: 'Guía de manejo',
                    subtitle: 'Recomendaciones generales',
                    onTap: onGuiaDeManejo,
                  ),
                  const SizedBox(height: 12),
                  _AccionItem(
                    icon: Icons.recycling_rounded,
                    title: 'Gestores certificados',
                    subtitle: 'Empresas autorizadas cercanas',
                    onTap: onGestoresCertificados,
                  ),
                  const SizedBox(height: 12),
                  _AccionItem(
                    icon: Icons.shield_outlined,
                    title: 'Autoridades ambientales',
                    subtitle: 'Contactos oficiales',
                    onTap: onAutoridadesAmbientales,
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                      },
                      icon: const Icon(Icons.logout_rounded, color: EcoColors.error),
                      label: const Text(
                        'Cerrar Sesión',
                        style: TextStyle(color: EcoColors.error, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.userInitial, this.onPerfil});

  final String userInitial;
  final VoidCallback? onPerfil;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: EcoColors.background,
        border: Border(bottom: BorderSide(color: EcoColors.outline)),
      ),
      child: Row(
        children: [
          const Text(
            'EcoResiduos',
            style: TextStyle(
              fontSize: 20,
              height: 28 / 20,
              fontWeight: FontWeight.bold,
              color: EcoColors.onSurface,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: onPerfil,
            customBorder: const CircleBorder(),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: EcoColors.primaryContainer,
              child: Text(
                userInitial,
                style: const TextStyle(
                  color: EcoColors.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentificarResiduoCard extends StatelessWidget {
  const _IdentificarResiduoCard({this.onAbrirCamara});

  final VoidCallback? onAbrirCamara;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EcoColors.background,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: EcoColors.primaryContainer,
                child: Icon(
                  Icons.photo_camera_rounded,
                  color: EcoColors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Identificar residuo',
                      style: TextStyle(
                        fontSize: 16,
                        height: 24 / 16,
                        fontWeight: FontWeight.w500,
                        color: EcoColors.onSurface,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Usa la cámara con IA',
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: EcoColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            height: 44,
            child: FilledButton(
              onPressed: onAbrirCamara,
              style: FilledButton.styleFrom(
                backgroundColor: EcoColors.primary,
                foregroundColor: EcoColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                'ABRIR CÁMARA',
                style: TextStyle(fontSize: 14, letterSpacing: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccionItem extends StatelessWidget {
  const _AccionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EcoColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EcoColors.outline, width: 1.4),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: EcoColors.primaryContainer,
                child: Icon(
                  icon,
                  size: 18,
                  color: EcoColors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 24 / 16,
                        fontWeight: FontWeight.w500,
                        color: EcoColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: EcoColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: EcoColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
