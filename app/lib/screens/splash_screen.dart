import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/eco_theme.dart';
import '../widgets/eco_logo.dart';

/// Carga inicial (01). Si tarda más de 400 ms explica qué se está preparando.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _lenta = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _lenta = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primario = ecoLightColorScheme.primary;
    final suave = Colors.white.withValues(alpha: 0.78);

    return Scaffold(
      backgroundColor: primario,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: EcoSpace.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EcoLogo(),
              const SizedBox(height: EcoSpace.s24),
              Text(
                'EcoResiduos',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 48, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Bucaramanga y área metropolitana',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: suave),
              ),
              const SizedBox(height: EcoSpace.s48),
              SizedBox(
                width: 160,
                child: LinearProgressIndicator(
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  color: ecoLightColorScheme.primaryContainer,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              AnimatedOpacity(
                opacity: _lenta ? 1 : 0,
                duration: EcoMotion.duracion(context, EcoMotion.estado),
                child: Padding(
                  padding: const EdgeInsets.only(top: EcoSpace.s16),
                  child: Text('Preparando tu cuenta…', style: theme.textTheme.bodyMedium?.copyWith(color: suave)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
