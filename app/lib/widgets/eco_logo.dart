import 'package:flutter/material.dart';

/// Logo e isotipo oficial de EcoResiduos con acabado premium.
class EcoLogo extends StatelessWidget {
  const EcoLogo({super.key, this.width = 134, this.showBadge = true});

  final double width;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      'assets/branding/app_icon.png',
      width: showBadge ? width * 0.72 : width,
      height: showBadge ? width * 0.72 : width,
      fit: BoxFit.contain,
    );

    if (!showBadge) {
      return Semantics(label: 'EcoResiduos', image: true, child: image);
    }

    return Semantics(
      label: 'EcoResiduos',
      image: true,
      child: Container(
        width: width,
        height: width,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(width * 0.24),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: image,
      ),
    );
  }
}
