// Política de tratamiento de datos personales (Ley 1581 de 2012 y Decreto
// 1377 de 2013, compilado en el Decreto 1074 de 2015). El mismo texto se
// publica en el panel, en /privacidad (admin-panel/src/utils/politicaDatos.js):
// si cambias uno, cambia el otro y sube la versión, y la app volverá a pedir
// la autorización. admin-panel/pruebas/privacidad.test.js revisa que coincidan.

/// Versión vigente. Se guarda en `usuarios.autorizacion_datos_version` al
/// aceptar.
const versionPoliticaDatos = '2026-10-30';

/// Correo para consultas, reclamos y revocatorias.
const correoDatosPersonales = 'soporte@ecoresiduos.com';

class SeccionPolitica {
  const SeccionPolitica(this.titulo, this.parrafos);

  final String titulo;
  final List<String> parrafos;
}

const politicaDatos = [
  SeccionPolitica('Responsable', [
    'EcoResiduos es un proyecto de grado de la Universidad de Santander (UDES), en Bucaramanga, Santander. '
        'Es el responsable del tratamiento de los datos que recoge esta aplicación y su panel de administración. '
        'Contacto: $correoDatosPersonales.',
  ]),
  SeccionPolitica('Qué datos recogemos', [
    'Si te registras como ciudadano o empresa generadora: nombre o razón social, documento o NIT, teléfono, municipio y correo. '
        'En cada publicación: dirección de recolección, ubicación del teléfono en ese momento (solo si das el permiso), '
        'foto, material y cantidad del residuo.',
    'Si te registras como empresa gestora: razón social, NIT, representante legal, correo, teléfono, dirección, '
        'horario, permiso o licencia ambiental en PDF, materiales que recibes, logo, portada y los certificados que cargas.',
    'Cuando usas la cámara para identificar un residuo, la foto se analiza en tu teléfono y se guarda en tu historial de escaneos.',
    'No recogemos datos sensibles (salud, origen étnico, orientación política, religiosa o sexual, ni datos biométricos). '
        'La aplicación no está dirigida a menores de 18 años.',
  ]),
  SeccionPolitica('Para qué los usamos', [
    'Crear y administrar tu cuenta.',
    'Publicar tus solicitudes de recolección y conectarlas con empresas gestoras autorizadas.',
    'Coordinar la recolección y enviarte notificaciones sobre ella.',
    'Verificar que las empresas gestoras tengan permiso ambiental vigente.',
    'Generar estadísticas por municipio para las autoridades ambientales (CDMB, AMB y CAS). '
        'Estas estadísticas son agregadas y no incluyen datos personales.',
  ]),
  SeccionPolitica('Quién ve tus datos', [
    'Mientras tu solicitud está publicada, la ven las empresas gestoras aprobadas que reciben ese material: '
        'material, cantidad, foto, dirección, municipio, ubicación y teléfono de contacto, para que puedan hacer su oferta. '
        'Cuando eliges una empresa, la solicitud deja de estar a la vista de las demás; '
        'la siguen viendo la empresa elegida y las que ya habían hecho una oferta.',
    'Los administradores de EcoResiduos ven los datos necesarios para verificar empresas y resolver problemas.',
    'Los datos de las empresas gestoras (razón social, contacto, dirección, horario y materiales) aparecen en el directorio público de la aplicación.',
  ]),
  SeccionPolitica('Dónde se guardan', [
    'Los datos se guardan en Supabase, un servicio de base de datos y almacenamiento en la nube con servidores fuera de Colombia, '
        'que actúa como encargado del tratamiento. El panel de administración se aloja en Vercel. '
        'Al aceptar esta política autorizas esa transmisión internacional.',
    'El asistente del panel usa Google Gemini, pero solo le envía cifras y nombres de empresas, nunca datos de ciudadanos. '
        'Las direcciones de las empresas gestoras se ubican en el mapa con OpenStreetMap (Nominatim).',
    'Protegemos los datos con conexiones cifradas (HTTPS), contraseñas que nunca se guardan en texto plano y reglas en la '
        'base de datos que solo dejan ver a cada usuario lo que le corresponde.',
  ]),
  SeccionPolitica('Tus derechos', [
    'Según el artículo 8 de la Ley 1581 de 2012 puedes: conocer, actualizar y rectificar tus datos; pedir prueba de esta '
        'autorización; saber cómo se han usado tus datos; revocar la autorización o pedir que borremos tus datos cuando '
        'no exista un deber legal de conservarlos; acceder gratis a tus datos; y presentar quejas ante la '
        'Superintendencia de Industria y Comercio.',
  ]),
  SeccionPolitica('Cómo ejercerlos', [
    'Escribe a $correoDatosPersonales desde el correo de tu cuenta, indicando qué necesitas.',
    'Las consultas se responden en máximo 10 días hábiles (prorrogables 5 más) y los reclamos en máximo 15 días hábiles '
        '(prorrogables 8 más), como indican los artículos 14 y 15 de la Ley 1581 de 2012.',
  ]),
  SeccionPolitica('Cuánto tiempo los conservamos', [
    'Mientras tengas la cuenta activa. Si pides borrarla, eliminamos tus datos personales, salvo los registros de '
        'recolecciones y certificados que las normas ambientales exigen conservar como soporte de la gestión del residuo.',
  ]),
  SeccionPolitica('Cambios a esta política', [
    'Si la cambiamos, te avisaremos en la aplicación y te pediremos de nuevo la autorización. '
        'Versión vigente: $versionPoliticaDatos.',
  ]),
];
