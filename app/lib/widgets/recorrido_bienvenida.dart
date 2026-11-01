import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coach_mark.dart';
export 'coach_mark.dart' show CoachMarkPaso, FormaSpotlight, mostrarCoachMarks;

// Claves en SharedPreferences. Subir la versión vuelve a mostrar los
// recorridos a quien ya los vio (v4: bienvenida con el proceso completo).
const _prefijoBienvenida = 'bienvenida_v4_';
const _prefijoPantalla = 'recorrido_v2_';

/// Avisa a las pantallas abiertas que se pidió repetir los recorridos desde
/// la cuenta, para que lo muestren sin tener que salir y volver.
final reinicioRecorridos = ValueNotifier<int>(0);

/// Borra lo visto: cada recorrido se vuelve a mostrar una vez.
Future<void> reiniciarRecorridos() async {
  final prefs = await SharedPreferences.getInstance();
  for (final clave in prefs.getKeys().toList()) {
    if (clave.startsWith(_prefijoBienvenida) || clave.startsWith(_prefijoPantalla)) await prefs.remove(clave);
  }
  reinicioRecorridos.value++;
}

/// Muestra una vez el recorrido de una pantalla. Queda como visto cuando la
/// persona lo termina o lo salta, no cuando aparece: si cierra la app a
/// mitad, lo verá de nuevo.
Future<void> mostrarRecorridoPantallaSiNecesario(
  BuildContext context,
  String pantalla,
  List<CoachMarkPaso> pasos,
) =>
    _mostrarUnaVez(context, '$_prefijoPantalla$pantalla', pasos);

/// Recorrido de primer ingreso del inicio, distinto para generador y gestor:
/// primero una bienvenida con el proceso completo y luego los elementos de la
/// pantalla. Los pasos cuyo elemento no está (un usuario nuevo aún no tiene
/// cifras) se omiten.
Future<void> mostrarRecorridoSiNecesario(
  BuildContext context,
  String rol, {
  required GlobalKey keyTarjeta,
  GlobalKey? keyCifras,
  GlobalKey? keyFab,
  GlobalKey? keyNav,
}) {
  final esGestor = rol.toUpperCase() == 'GESTOR';
  final pasos = esGestor
      ? pasosGestor(keyTarjeta: keyTarjeta, keyCifras: keyCifras, keyNav: keyNav)
      : pasosGenerador(keyTarjeta: keyTarjeta, keyCifras: keyCifras, keyFab: keyFab, keyNav: keyNav);
  return _mostrarUnaVez(context, '$_prefijoBienvenida${rol.toLowerCase()}', pasos);
}

Future<void> _mostrarUnaVez(BuildContext context, String clave, List<CoachMarkPaso> pasos) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(clave) == true || !context.mounted) return;
  final mostrado = await mostrarCoachMarks(context, pasos);
  if (mostrado) await prefs.setBool(clave, true);
}

const _notaRepetir = 'Puedes repetir este recorrido cuando quieras desde tu cuenta (tu foto, arriba a la derecha).';

// ─── Generador ────────────────────────────────────────────────────────────────

@visibleForTesting
List<CoachMarkPaso> pasosGenerador({
  required GlobalKey keyTarjeta,
  GlobalKey? keyCifras,
  GlobalKey? keyFab,
  GlobalKey? keyNav,
}) {
  return [
    const CoachMarkPaso.bienvenida(
      titulo: 'Bienvenido a EcoResiduos',
      descripcion: 'Te ayudamos a separar bien tus residuos y a entregarlos a una empresa autorizada que los aproveche '
          'o les dé una disposición final segura. Así funciona:',
      puntos: [
        'Identifica el residuo con la cámara y aprende cómo separarlo.',
        'Publica una solicitud de recolección con foto, cantidad y dirección.',
        'Las empresas gestoras autorizadas te envían ofertas; tú eliges una.',
        'Confirma que recogieron el residuo y descarga el certificado.',
      ],
    ),
    if (keyFab != null)
      CoachMarkPaso(
        keyObjetivo: keyFab,
        titulo: 'Todo empieza aquí',
        descripcion: 'Toma una foto del residuo: la app lo clasifica en el teléfono, sin internet, según el código de '
            'colores de la Resolución 2184 de 2019. Te dice cómo manejarlo, qué empresas cercanas lo reciben y desde '
            'ahí puedes publicarlo.',
        nota: 'Si la foto no es clara, la app no adivina: te ofrece las opciones más probables.',
        forma: FormaSpotlight.circulo,
      ),
    CoachMarkPaso(
      keyObjetivo: keyTarjeta,
      titulo: 'Tu siguiente paso',
      descripcion: 'Esta tarjeta cambia según lo que necesites hacer: revisar una oferta nueva, confirmar que '
          'recogieron tu residuo o, si todo está al día, decírtelo.',
      nota: 'Empieza siempre por aquí.',
    ),
    if (keyCifras != null)
      CoachMarkPaso(
        keyObjetivo: keyCifras,
        titulo: 'Tus publicaciones',
        descripcion: 'Publicados: esperando ofertas de las empresas. En negociación: ya elegiste una y falta que '
            'recoja. Completados: ya recogidos; ahí verás el certificado cuando la empresa lo cargue.',
      ),
    if (keyNav != null)
      CoachMarkPaso(
        keyObjetivo: keyNav,
        titulo: 'Las cuatro secciones',
        descripcion: 'Inicio: este resumen. Residuos: la guía de cada categoría y cómo manejarla. Gestores: el '
            'directorio de empresas autorizadas. Actividad: tus publicaciones y las ofertas que recibes.',
        nota: _notaRepetir,
      ),
  ];
}

// ─── Gestor ───────────────────────────────────────────────────────────────────

@visibleForTesting
List<CoachMarkPaso> pasosGestor({
  required GlobalKey keyTarjeta,
  GlobalKey? keyCifras,
  GlobalKey? keyNav,
}) {
  return [
    const CoachMarkPaso.bienvenida(
      titulo: 'Bienvenido, empresa gestora',
      descripcion: 'EcoResiduos te conecta con ciudadanos y empresas de los seis municipios que necesitan entregar residuos '
          'de los materiales que tienes verificados. Así funciona:',
      puntos: [
        'Te avisamos cuando alguien publica un residuo de tus materiales.',
        'Envías tu oferta: un cobro por recogerlo o un pago por aprovecharlo.',
        'Si te eligen, coordinas y recoges el residuo.',
        'Marcas la recolección y cargas el certificado de disposición final o aprovechamiento.',
      ],
      nota: 'Solo ves solicitudes de los materiales que el administrador ya verificó en tu perfil.',
    ),
    CoachMarkPaso(
      keyObjetivo: keyTarjeta,
      titulo: 'Lo más urgente, primero',
      descripcion: 'Si te eligieron para una recolección, aparece aquí para coordinarla; si hay solicitudes nuevas '
          'de tus materiales, también. Cuando no hay nada pendiente, te lo dice.',
      nota: 'Tócala para ir al detalle.',
    ),
    if (keyCifras != null)
      CoachMarkPaso(
        keyObjetivo: keyCifras,
        titulo: 'Tu actividad',
        descripcion: 'Disponibles: solicitudes de tus materiales a las que puedes ofertar. Postuladas: ofertas que '
            'enviaste y esperan respuesta. Completadas: recolecciones que ya hiciste.',
      ),
    if (keyNav != null)
      CoachMarkPaso(
        keyObjetivo: keyNav,
        titulo: 'Las cuatro secciones',
        descripcion: 'Inicio: este resumen. Solicitudes: residuos publicados de tus materiales. Postulaciones: tus '
            'ofertas y las recolecciones que coordinas. Directorio: las demás empresas gestoras y la guía de residuos.',
        nota: _notaRepetir,
      ),
  ];
}
