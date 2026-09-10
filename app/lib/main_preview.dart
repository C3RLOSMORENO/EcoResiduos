import 'package:flutter/material.dart';

import 'screens/inicio_screen.dart';
// A medida que te vaya entregando más pantallas, impórtalas aquí
// y agrégalas a `_screens` para poder alternar entre ellas.

void main() {
  runApp(const PreviewApp());
}

class PreviewApp extends StatefulWidget {
  const PreviewApp({super.key});

  @override
  State<PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<PreviewApp> {
  int _index = 0;

  // Registra aquí cada pantalla nueva: 'Nombre visible' -> widget
  final Map<String, WidgetBuilder> _screens = {
    'WF-01 — Inicio': (_) => const InicioScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final entries = _screens.entries.toList();

    return MaterialApp(
      title: 'EcoResiduos — Preview',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4A6B21),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: entries.length > 1
            ? AppBar(
                title: Text(entries[_index].key),
                actions: [
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.grid_view_rounded),
                    onSelected: (i) => setState(() => _index = i),
                    itemBuilder: (context) => [
                      for (var i = 0; i < entries.length; i++)
                        PopupMenuItem(value: i, child: Text(entries[i].key)),
                    ],
                  ),
                ],
              )
            : null,
        body: entries[_index].value(context),
      ),
    );
  }
}
