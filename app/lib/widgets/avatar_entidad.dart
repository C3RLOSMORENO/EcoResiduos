import 'package:flutter/material.dart';
import '../theme/eco_theme.dart';
import '../utils/formato.dart';
import 'imagen_foto.dart';

class AvatarEntidad extends StatelessWidget {
  const AvatarEntidad({
    super.key,
    required this.nombre,
    this.size = 40,
    this.secundario = false,
    this.texto,
    this.fotoUrl,
  });

  final String nombre;
  final double size;
  final bool secundario;
  final String? fotoUrl;

  /// Texto a mostrar en lugar de las iniciales (p. ej. la sigla).
  final String? texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fondo = secundario ? scheme.secondaryContainer : scheme.tertiaryContainer;
    final frente = secundario ? scheme.onSecondaryContainer : scheme.onTertiaryContainer;
    
    final inicialesWidget = FittedBox(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Text(texto ?? iniciales(nombre), style: theme.textTheme.titleMedium?.copyWith(color: frente, fontWeight: FontWeight.bold)),
      ),
    );
    
    final interior = fotoUrl != null && fotoUrl!.isNotEmpty
        ? SizedBox.expand(child: ImagenFoto(ruta: fotoUrl, respaldo: inicialesWidget, fit: BoxFit.cover))
        : inicialesWidget;
          
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: fondo,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(EcoRadius.small))),
      ),
      child: interior,
    );
  }
}
