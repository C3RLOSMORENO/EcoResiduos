import 'dart:io';

import 'package:flutter/material.dart';

import '../models/waste_item.dart';
import '../theme/eco_colors.dart';

/// WF-06 — Resultado de identificación
class ResultadoScreen extends StatelessWidget {
  const ResultadoScreen({
    super.key,
    required this.item,
    this.onVerInformacion,
    this.onReintentar,
  });

  final WasteItem item;
  final void Function(BuildContext)? onVerInformacion;
  final void Function(BuildContext)? onReintentar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: 'Resultado'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FotoResultado(imagenPath: item.imagenPath),
                    const SizedBox(height: 16),
                    Text(
                      item.nombre,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 32 / 24,
                        fontWeight: FontWeight.bold,
                        color: EcoColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: EcoColors.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${item.confianza}% de confianza',
                        style: const TextStyle(
                          fontSize: 14,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w500,
                          color: EcoColors.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Categoría: ${item.categoria}',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: EcoColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        onPressed: onVerInformacion == null ? null : () => onVerInformacion!(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: EcoColors.primary,
                          foregroundColor: EcoColors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text(
                          'VER INFORMACIÓN',
                          style: TextStyle(fontSize: 14, letterSpacing: 0.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: onReintentar == null ? null : () => onReintentar!(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: EcoColors.primary,
                          side: const BorderSide(
                            color: Color(0xFF73796D),
                            width: 1.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text(
                          'REINTENTAR',
                          style: TextStyle(fontSize: 14, letterSpacing: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: EcoColors.background,
        border: Border(bottom: BorderSide(color: EcoColors.outline)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: EcoColors.onSurface,
            onPressed: () => Navigator.maybePop(context),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              height: 28 / 20,
              fontWeight: FontWeight.bold,
              color: EcoColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Miniatura de la foto capturada. Si aún no hay imagen real disponible,
/// cae en un placeholder con el ícono de cámara, tal como en el wireframe.
class _FotoResultado extends StatelessWidget {
  const _FotoResultado({this.imagenPath});

  final String? imagenPath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: imagenPath != null
            ? Image.file(File(imagenPath!), fit: BoxFit.cover)
            : Container(
                color: const Color(0xFFDFE4D7),
                child: const Center(
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.photo_camera_rounded,
                      color: EcoColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
