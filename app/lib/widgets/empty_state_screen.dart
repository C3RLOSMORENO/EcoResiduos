import 'package:flutter/material.dart';

import '../theme/eco_colors.dart';

/// Plantilla reutilizable para pantallas de estado a pantalla completa:
/// permiso denegado, residuo no identificado, error de procesamiento,
/// error de conexión, etc. (WF-11, WF-12, WF-13, WF-14).
///
/// Un ícono circular arriba, título, subtítulo, y hasta dos botones
/// (uno principal relleno, uno secundario de texto).
class EmptyStateScreen extends StatelessWidget {
  const EmptyStateScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.iconBackgroundColor = EcoColors.errorContainer,
    this.iconColor = EcoColors.error,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final void Function(BuildContext)? onPrimary;
  final String? secondaryLabel;
  final void Function(BuildContext)? onSecondary;
  final Color iconBackgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const Spacer(flex: 3),
              CircleAvatar(
                radius: 32,
                backgroundColor: iconBackgroundColor,
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  height: 28 / 20,
                  fontWeight: FontWeight.bold,
                  color: EcoColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  color: EcoColors.onSurfaceVariant,
                ),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: onPrimary == null ? null : () => onPrimary!(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: EcoColors.primary,
                    foregroundColor: EcoColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    primaryLabel,
                    style: const TextStyle(fontSize: 14, letterSpacing: 0.4),
                  ),
                ),
              ),
              if (secondaryLabel != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed:
                        onSecondary != null ? () => onSecondary!(context) : () => Navigator.maybePop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: EcoColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      secondaryLabel!,
                      style: const TextStyle(fontSize: 14, letterSpacing: 0.4),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
