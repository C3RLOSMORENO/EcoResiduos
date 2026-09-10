import 'dart:io';

import 'package:flutter/material.dart';

import '../models/waste_item.dart';
import '../theme/eco_colors.dart';

/// WF-07 — Información del residuo
class InformacionResiduoScreen extends StatelessWidget {
  const InformacionResiduoScreen({
    super.key,
    required this.item,
    this.onVerManejo,
  });

  final WasteItem item;
  final VoidCallback? onVerManejo;

  Color _obtenerColorCategoria(String categoria) {
    final cat = categoria.toUpperCase();
    if (cat.contains('PELIGROSO') || cat.contains('BIOSANITARIO')) return Colors.red.shade700;
    if (cat.contains('INDUSTRIAL') || cat.contains('RAEE')) return Colors.orange.shade700;
    if (cat.contains('RECICLABLE') || cat.contains('ORGANICO')) return Colors.green.shade700;
    if (cat.contains('ORDINARIO')) return Colors.grey.shade700;
    return EcoColors.primary;
  }

  IconData _obtenerIconoCategoria(String categoria) {
    final cat = categoria.toUpperCase();
    if (cat.contains('PELIGROSO') || cat.contains('BIOSANITARIO')) return Icons.warning_rounded;
    if (cat.contains('INDUSTRIAL')) return Icons.factory_rounded;
    if (cat.contains('RAEE')) return Icons.memory_rounded;
    if (cat.contains('RECICLABLE')) return Icons.recycling_rounded;
    if (cat.contains('ORGANICO')) return Icons.compost_rounded;
    return Icons.delete_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final colorCategoria = _obtenerColorCategoria(item.categoria);
    final iconoCategoria = _obtenerIconoCategoria(item.categoria);

    // Ocultar características si solo dice "Código: N/A" o "Sin características"
    final bool mostrarCaracteristicas = 
        !item.caracteristicas.contains('N/A') && 
        !item.caracteristicas.contains('Sin características');

    return Scaffold(
      backgroundColor: EcoColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: item.nombre),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FotoResiduo(imagenPath: item.imagenPath),
                    const SizedBox(height: 20),
                    
                    // Chip de Categoría Mejorado
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorCategoria.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colorCategoria.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconoCategoria, size: 18, color: colorCategoria),
                          const SizedBox(width: 8),
                          Text(
                            item.etiquetaCategoria.toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.bold,
                              color: colorCategoria,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Sección Descripción
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: EcoColors.primary, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Descripción e Impacto',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: EcoColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: EcoColors.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        item.descripcion,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: EcoColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    
                    // Sección Características (opcional)
                    if (mostrarCaracteristicas) ...[
                      const SizedBox(height: 24),
                      const Row(
                        children: [
                          Icon(Icons.list_alt_rounded, color: EcoColors.primary, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Detalles',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: EcoColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: EcoColors.surfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: EcoColors.outlineVariant),
                        ),
                        child: Text(
                          item.caracteristicas,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: EcoColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    
                    // Botón de Manejo
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: onVerManejo,
                        icon: const Icon(Icons.eco_rounded),
                        label: const Text(
                          'VER GUÍA DE MANEJO',
                          style: TextStyle(
                            fontSize: 15, 
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: EcoColors.primary,
                          foregroundColor: EcoColors.onPrimary,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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
      decoration: BoxDecoration(
        color: EcoColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: EcoColors.onSurface,
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: EcoColors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance visual con el back button
        ],
      ),
    );
  }
}

class _FotoResiduo extends StatelessWidget {
  const _FotoResiduo({this.imagenPath});

  final String? imagenPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 240, // Más alta para mayor impacto visual
          width: double.infinity,
          child: imagenPath != null
              ? Image.file(File(imagenPath!), fit: BoxFit.cover)
              : Container(
                  color: const Color(0xFFDFE4D7),
                  child: const Center(
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.photo_camera_rounded,
                        color: EcoColors.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
