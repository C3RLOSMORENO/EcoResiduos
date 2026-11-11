import 'package:flutter/material.dart';

/// Contenido del manual de uso que se abre desde la hoja de cuenta. Es el
/// mismo del Apéndice E del libro, separado por rol: cada persona ve solo las
/// secciones de su rol. Va en el código para que funcione sin internet.
///
/// En los textos, lo que va entre `**` es el nombre de un botón o de una
/// pantalla tal como aparece en la app, y se muestra en negrita.
class SeccionManual {
  const SeccionManual({required this.titulo, required this.icono, this.intro, this.pasos = const [], this.notas = const []});

  final String titulo;
  final IconData icono;

  /// Párrafo opcional antes de los pasos.
  final String? intro;

  /// Pasos numerados, en orden.
  final List<String> pasos;

  /// Párrafos opcionales después de los pasos.
  final List<String> notas;
}

/// Fecha de la última revisión del manual. Cámbiala cuando cambie el contenido.
const manualActualizado = '11 de noviembre de 2026';

/// Aviso sobre datos personales (Ley 1581 de 2012) que abre el manual de cada rol.
const avisoDatosGenerador =
    'La identificación se hace en tu teléfono y la foto no se sube. La foto de un residuo se sube solo cuando lo publicas, '
    'y la ven los gestores autorizados para ese material.';
const avisoDatosGestor =
    'Los datos de los generadores que ves (nombre, teléfono, dirección y foto del residuo) son solo para coordinar la '
    'recolección. No los uses para otro fin (Ley 1581 de 2012).';

/// Una pregunta frecuente con su respuesta.
class PreguntaManual {
  const PreguntaManual(this.pregunta, this.respuesta);

  final String pregunta;
  final String respuesta;
}

const _cuenta = SeccionManual(
  titulo: 'Tu cuenta',
  icono: Icons.person_outline,
  pasos: [
    'Para entrar, escribe tu correo y contraseña y toca **Entrar**. Si olvidaste la contraseña, toca **¿Olvidaste tu contraseña?** y sigue el enlace que llega a tu correo.',
    'La primera vez, la app te pide autorizar el tratamiento de tus datos personales (Ley 1581 de 2012). Lee la política y toca **Aceptar y continuar**.',
    'Toca tu foto o tus iniciales, en la barra superior, para abrir tu cuenta. Ahí cambias tus datos, tu municipio, tu foto y tu contraseña, y cierras sesión.',
  ],
);

const List<SeccionManual> manualGenerador = [
  SeccionManual(
    titulo: 'Cómo está organizada la app',
    icono: Icons.dashboard_outlined,
    intro:
        'La barra de abajo tiene cuatro secciones: **Inicio** (tu resumen y lo pendiente), **Residuos** (catálogo y normativa), '
        '**Gestores** (empresas y autoridades) y **Actividad** (tus publicaciones y escaneos). El botón **Identificar**, '
        'abajo a la derecha, abre la cámara.',
  ),
  SeccionManual(
    titulo: 'Identificar un residuo',
    icono: Icons.photo_camera_outlined,
    pasos: [
      'Toca **Identificar**. La primera vez, toca **Permitir cámara**. La identificación se hace en tu teléfono y funciona sin internet.',
      'Centra el residuo en el recuadro y toca **Tomar foto**. También puedes elegir una imagen de la **Galería** o encender el flash.',
      'Verás la categoría, la **Confianza de la IA** y qué incluye esa categoría.',
      'Si no te parece correcto, revisa **¿No es correcto? También podría ser:**, con hasta dos alternativas.',
      'Si el residuo lo recoge un gestor, toca **Publicar para recolección**. Los orgánicos y ordinarios no se publican: toca **¿Cómo separarlo correctamente?** para ver cómo entregarlos.',
    ],
    notas: [
      'Si aparece **No vemos un residuo** o **No pudimos identificarlo**, toca **Tomar otra foto** acercándote un poco más, elige una opción de **¿Es alguno de estos?**, usa **Buscar por nombre** o sigue con **Publicar sin clasificar**.',
    ],
  ),
  SeccionManual(
    titulo: 'Consultar el catálogo de residuos',
    icono: Icons.manage_search,
    intro:
        'En **Residuos** escribe el nombre de un residuo (por ejemplo «pilas» o «cartón») o explora las categorías. '
        'Cada una explica qué incluye y cómo entregarla. En **Normativa y guías** está la **Guía de manejo general**. '
        'El catálogo funciona sin internet.',
  ),
  SeccionManual(
    titulo: 'Publicar un residuo para que lo recojan',
    icono: Icons.add_box_outlined,
    pasos: [
      'Toca **Publicar para recolección** desde el resultado, o **Publicar residuo** en **Actividad** si ya sabes qué material es.',
      'Agrega la **Foto del residuo**. Es obligatoria: le muestra al gestor qué va a recoger.',
      'Elige el **Material**, escribe la **Cantidad estimada** y su **Unidad**, el **Municipio**, la **Dirección de recolección** y el **Teléfono de contacto**. La descripción es opcional.',
      'Cuando veas **Todo listo. Revisa y publica.**, toca **Publicar**. Los gestores autorizados para ese material reciben un aviso.',
    ],
    notas: [
      'Si no tienes internet, la publicación queda **Guardada para publicar** en tu teléfono. Se envía sola cuando abres la app o vuelves a ella con conexión; también puedes tocar **Enviar ahora**. Tus datos no se pierden.',
    ],
  ),
  SeccionManual(
    titulo: 'Elegir una propuesta',
    icono: Icons.handshake_outlined,
    pasos: [
      'Cuando un gestor se postula te llega un aviso. Abre la publicación desde **Inicio** (**Revisar postulaciones**) o desde **Actividad**.',
      'Cada propuesta muestra la empresa, si el gestor recoge o tú lo llevas, el valor (cobro, pago o gratuito) y su mensaje.',
      'Toca **Aceptar** en la que prefieras. Las demás se rechazan solas y esos gestores reciben un aviso. Si una no te interesa, toca **Rechazar**.',
    ],
    notas: [
      'Mientras no tengas gestor, puedes usar **Editar publicación** o **Cancelar publicación**, y volver a activarla con **Publicar de nuevo**.',
    ],
  ),
  SeccionManual(
    titulo: 'Confirmar la recolección o reportar un problema',
    icono: Icons.task_alt,
    pasos: [
      'Coordina con el gestor desde el detalle con **Llamar** o **Cómo llegar**.',
      'Cuando el gestor marca que recogió el residuo, la publicación queda en **Recolectado · por confirmar**. Si todo salió bien, toca **Sí, confirmar recolección**.',
      'Si algo salió mal, toca **Reportar un problema**, elige qué pasó, cuéntanos más si quieres y toca **Enviar reporte**. El administrador de EcoResiduos revisa el caso.',
      'Si no respondes en 72 horas, la recolección se confirma automáticamente.',
      'Cuando el gestor carga el certificado o acta, te llega un aviso y puedes abrirlo con **Ver PDF**.',
    ],
  ),
  SeccionManual(
    titulo: 'Directorio y novedades',
    icono: Icons.notifications_none,
    intro:
        'En **Gestores** ves las empresas certificadas, qué materiales reciben y cómo contactarlas; en la pestaña **Autoridades**, '
        'las entidades ambientales de tu municipio. Si compartes tu ubicación, **Cerca de ti** las ordena por distancia. '
        'La campana abre **Novedades**, con los avisos de propuestas, cambios de estado y certificados.',
  ),
  _cuenta,
];

const List<SeccionManual> manualGestor = [
  SeccionManual(
    titulo: 'Cómo está organizada la app',
    icono: Icons.dashboard_outlined,
    intro:
        'La barra de abajo tiene cuatro secciones: **Inicio** (tu resumen y lo pendiente), **Solicitudes** (residuos de tus materiales), '
        '**Postulaciones** (tus propuestas) y **Directorio**. Tu empresa recibe solicitudes solo cuando el administrador de '
        'EcoResiduos aprueba su licencia y sus materiales.',
  ),
  SeccionManual(
    titulo: 'Buscar solicitudes y postularte',
    icono: Icons.search,
    pasos: [
      'Entra a **Solicitudes**. Solo ves los materiales que estás autorizado a recibir; cada tarjeta muestra el residuo, el municipio, la distancia y la fecha.',
      'Si lo necesitas, filtra por **Categoría**, **Municipio** o **Distancia**. Toca **Quitar filtros** para ver todo.',
      'Abre una solicitud y toca **Postularme para recolección**.',
      'Elige si pasas a recoger el residuo o si el generador lo lleva a tu punto de recepción.',
      'Escribe el valor: lo que cobras por recoger o lo que pagas por el material. Si no hay cobro ni pago, escribe 0.',
      'Cuéntale al generador cuándo puedes pasar y cómo lo recoges, y envía la propuesta.',
    ],
  ),
  SeccionManual(
    titulo: 'Seguir tus postulaciones',
    icono: Icons.list_alt,
    intro:
        'En **Postulaciones** tus propuestas están en cuatro grupos: **Enviadas** (esperando respuesta), **Aceptadas**, '
        '**Rechazadas** (el generador descartó tu oferta) y **Asignadas a otro gestor** (eligió otra oferta).',
  ),
  SeccionManual(
    titulo: 'Recoger el residuo y cargar el certificado',
    icono: Icons.local_shipping_outlined,
    pasos: [
      'Cuando te eligen, te llega el aviso **Te eligieron para esta recolección**. Coordina con **Llamar al generador** y **Cómo llegar**.',
      'Después de recoger el residuo, toca **Marcar recolectado** y confirma con **Sí, lo recogí**. El generador recibe un aviso para confirmar.',
      'Toca **Cargar certificado o acta expedida (PDF)**, indica si es de disposición final o de aprovechamiento y elige el archivo (máximo 10 MB). Si te equivocas, usa **Reemplazar**.',
    ],
  ),
  SeccionManual(
    titulo: 'Tus materiales y tu licencia',
    icono: Icons.recycling,
    intro:
        'Desde tu cuenta, en **Materiales que recibo**, revisas y actualizas los materiales que tu licencia te permite recibir. '
        'Cada material nuevo queda pendiente hasta que el administrador de EcoResiduos lo verifique. Con **Actualizar permiso ambiental** '
        'subes una nueva versión de la licencia en PDF.',
  ),
  _cuenta,
];

const List<PreguntaManual> preguntasGenerador = [
  PreguntaManual('No tengo internet.', 'La identificación con la cámara y el catálogo funcionan sin conexión. Si publicas sin señal, la publicación se guarda en tu teléfono y se envía cuando abres la app o vuelves a ella con conexión, o al tocar **Enviar ahora**.'),
  PreguntaManual('La app no reconoce mi residuo.', 'Centra el objeto, acércate y toma otra foto con buena luz. También puedes elegir una opción sugerida, buscar por nombre o publicar sin clasificar.'),
  PreguntaManual('No me llegó el correo de activación.', 'Revisa la carpeta de spam o toca **Reenviar enlace** en la pantalla **Revisa tu correo**.'),
  PreguntaManual('El gestor no vino a recoger.', 'En el detalle de la publicación toca **Reportar un problema** y elige **No vinieron a recoger**. El administrador de EcoResiduos revisa el caso.'),
];

const List<PreguntaManual> preguntasGestor = [
  PreguntaManual('No veo solicitudes.', 'Revisa que el administrador de EcoResiduos ya aprobó tu empresa y tus materiales: solo ves solicitudes de los materiales verificados. Revisa también los filtros.'),
  PreguntaManual('El generador no confirma la recolección.', 'Si no responde en 72 horas, la recolección se confirma automáticamente.'),
  PreguntaManual('Necesito cambiar el NIT o la razón social.', 'Desde tu cuenta, toca **Solicitar cambio al administrador** y describe el cambio.'),
];
