import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coach_mark.dart';
export 'coach_mark.dart' show CoachMarkPaso, FormaSpotlight, mostrarCoachMarks;

/// Recorrido genérico por pantalla: [pantalla] es la clave única en SharedPrefs.
/// Los pasos cuyo objetivo no esté en el árbol se omiten automáticamente.
Future<void> mostrarRecorridoPantallaSiNecesario(
  BuildContext context,
  String pantalla,
  List<CoachMarkPaso> pasos,
) async {
  final prefs = await SharedPreferences.getInstance();
  final clave = 'recorrido_v1_$pantalla';
  if (prefs.getBool(clave) == true) return;
  if (!context.mounted) return;
  mostrarCoachMarks(context, pasos);
  await prefs.setBool(clave, true);
}

/// Muestra el recorrido de primer ingreso una sola vez por rol.
/// Versión 3: coach marks con spotlight sobre los elementos reales.
///
/// Llama a [mostrarCoachMarks] con los pasos filtrados según qué claves
/// tienen widget adjunto en ese momento (maneja el caso de usuario nuevo
/// sin datos, donde FranjaCifras todavía no está en el árbol).
Future<void> mostrarRecorridoSiNecesario(
  BuildContext context,
  String rol, {
  required GlobalKey keyTarjeta,
  GlobalKey? keyCifras,
  GlobalKey? keyFab,
  GlobalKey? keyNav,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final clave = 'bienvenida_v3_${rol.toLowerCase()}';
  if (prefs.getBool(clave) == true) return;
  if (!context.mounted) return;

  final pasos = rol.toUpperCase() == 'GESTOR'
      ? _pasosGestor(keyTarjeta: keyTarjeta, keyCifras: keyCifras, keyNav: keyNav)
      : _pasosGenerador(keyTarjeta: keyTarjeta, keyCifras: keyCifras, keyFab: keyFab);

  mostrarCoachMarks(context, pasos);
  await prefs.setBool(clave, true);
}

// ─── Generador ────────────────────────────────────────────────────────────────

List<CoachMarkPaso> _pasosGenerador({
  required GlobalKey keyTarjeta,
  GlobalKey? keyCifras,
  GlobalKey? keyFab,
}) {
  return [
    CoachMarkPaso(
      keyObjetivo: keyTarjeta,
      titulo: 'Tu siguiente paso',
      descripcion:
          'Esta tarjeta cambia sola: si un gestor se postula, te lo muestra; '
          'si ya recogieron el residuo, te pide confirmación. '
          'Cuando todo está al día, también lo dice.',
      nota: 'Empieza siempre leyendo esta tarjeta.',
    ),
    if (keyCifras != null)
      CoachMarkPaso(
        keyObjetivo: keyCifras,
        titulo: 'Cómo va todo',
        descripcion:
            'Publicados: visibles para gestores. '
            'En negociación: ya aceptaste uno, pendiente de recoger. '
            'Completados: recogidos y con certificado de aprovechamiento.',
      ),
    if (keyFab != null)
      CoachMarkPaso(
        keyObjetivo: keyFab,
        titulo: 'Por aquí se empieza',
        descripcion:
            'Toca para fotografiar un residuo: la IA lo identifica, '
            'te dice cómo manejarlo y qué gestores certificados '
            'lo reciben en tu municipio. Funciona sin internet.',
        nota: 'Cada publicación nace aquí.',
        forma: FormaSpotlight.circulo,
      ),
  ];
}

// ─── Gestor ───────────────────────────────────────────────────────────────────

List<CoachMarkPaso> _pasosGestor({
  required GlobalKey keyTarjeta,
  GlobalKey? keyCifras,
  GlobalKey? keyNav,
}) {
  return [
    CoachMarkPaso(
      keyObjetivo: keyTarjeta,
      titulo: 'Lo más urgente, primero',
      descripcion:
          'Si te aceptaron una recolección, aparece aquí para coordinar '
          'la recogida. Si hay solicitudes nuevas de tus materiales, también. '
          'Cuando no hay nada pendiente, lo dice.',
      nota: 'Tócala para ir al detalle.',
    ),
    if (keyCifras != null)
      CoachMarkPaso(
        keyObjetivo: keyCifras,
        titulo: 'Tu actividad de un vistazo',
        descripcion:
            'Disponibles: solicitudes de tus materiales sin gestionar. '
            'Postuladas: propuestas que enviaste y esperan respuesta. '
            'Completadas: recolecciones con certificado.',
      ),
    if (keyNav != null)
      CoachMarkPaso(
        keyObjetivo: keyNav,
        titulo: 'Tres pestañas clave',
        descripcion:
            'Solicitudes: residuos que coinciden con tus materiales. '
            'Postulaciones: seguimiento de tus propuestas y coordinación. '
            'Directorio: perfil de tu empresa y materiales declarados.',
      ),
  ];
}
