import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/eco_theme.dart';

/// Bloque individual de esqueleto de carga.
class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({super.key, this.width, this.height = 16.0, this.radius = EcoRadius.small});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(radius)),
    );

    if (reduceMotion) {
      return box;
    }

    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHigh,
      highlightColor: scheme.surfaceContainerHighest,
      period: EcoMotion.skeleton,
      child: box,
    );
  }
}

/// Esqueleto completo para listas de tarjetas de solicitud o gestor.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 4, this.itemHeight = 84.0});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.all(EcoSpace.s16),
      itemCount: itemCount,
      separatorBuilder: (ctx, i) => const SizedBox(height: EcoSpace.s12),
      itemBuilder: (ctx, index) => Container(
        height: itemHeight,
        padding: const EdgeInsets.all(12),

        decoration: ShapeDecoration(
          color: scheme.surfaceContainerLowest,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(EcoRadius.medium))),
        ),
        child: Row(
          children: [
            const ShimmerLoading(width: 60, height: 60, radius: EcoRadius.small),
            const SizedBox(width: EcoSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ShimmerLoading(width: double.infinity, height: 16),
                  const SizedBox(height: 8),
                  ShimmerLoading(width: MediaQuery.of(context).size.width * 0.4, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
