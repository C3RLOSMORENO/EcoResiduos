import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/eco_colors.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _historial = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await _supabase
          .from('historial_escaneos_ia')
          .select()
          .eq('usuario_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _historial = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error al cargar historial: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _obtenerColorCategoria(String categoria) {
    final cat = categoria.toUpperCase();
    if (cat.contains('PELIGROSO') || cat.contains('BIOSANITARIO')) return Colors.red.shade700;
    if (cat.contains('INDUSTRIAL') || cat.contains('RAEE')) return Colors.orange.shade700;
    if (cat.contains('RECICLABLE') || cat.contains('ORGANICO')) return Colors.green.shade700;
    return EcoColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoColors.background,
      appBar: AppBar(
        title: const Text('Mi Historial', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: EcoColors.background,
        foregroundColor: EcoColors.onSurface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: EcoColors.outline.withValues(alpha: 0.3), height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: EcoColors.primary))
          : _historial.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _historial.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _historial[index];
                    final colorCat = _obtenerColorCategoria(item['categoria_detectada'] ?? '');

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Miniatura
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                            child: SizedBox(
                              width: 100,
                              height: 100,
                              child: item['imagen_path'] != null
                                  ? Image.network(
                                      item['imagen_path'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => _placeholderIcon(),
                                    )
                                  : _placeholderIcon(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Textos
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['nombre_detectado'] ?? 'Desconocido',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: EcoColors.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorCat.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item['categoria_detectada'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colorCat,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatearFecha(item['created_at']),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: EcoColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      color: EcoColors.surfaceVariant,
      child: const Center(
        child: Icon(Icons.image_not_supported, color: EcoColors.onSurfaceVariant),
      ),
    );
  }

  String _formatearFecha(String? fechaIso) {
    if (fechaIso == null) return '';
    try {
      final date = DateTime.parse(fechaIso).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: EcoColors.outline),
          const SizedBox(height: 16),
          const Text(
            'Aún no hay escaneos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: EcoColors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tus próximos escaneos aparecerán aquí.',
            style: TextStyle(color: EcoColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
