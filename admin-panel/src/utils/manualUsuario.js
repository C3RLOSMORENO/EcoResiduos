// Contenido del manual de uso del panel (sección E.4 del Apéndice E del libro).
// Lo que va entre ** es el nombre de un botón o pantalla y se muestra en negrita.
// Se mantiene aquí, y no en la vista, para poder probar que cada texto está bien formado.
// Sigue los elementos de información para usuarios de ISO/IEC/IEEE 26514: identificación
// del sistema y de la versión, público, convenciones, avisos, procedimientos con su
// ilustración, solución de problemas y contacto de soporte.

const { version } = require('../../package.json');
const { CORREO } = require('./politicaDatos');

// Fecha de la última revisión del manual. Cámbiala cuando cambie el contenido.
const ACTUALIZADO = '11 de noviembre de 2026';

const informacion = {
    version,
    actualizado: ACTUALIZADO,
    soporte: CORREO,
    publico: 'Administradores de EcoResiduos y funcionarios de las autoridades ambientales (CDMB, AMB y CAS) que verifican gestores, supervisan solicitudes y generan reportes.',
    requisitos: 'Un navegador web actualizado y una cuenta con rol de administrador.',
    convenciones: 'Los nombres en **negrita** son botones, secciones o filtros tal como aparecen en pantalla. Los pasos numerados se siguen en orden.',
    avisos: [
        'El panel muestra datos personales de ciudadanos y empresas. Úsalos solo para la fiscalización de residuos, según la Ley 1581 de 2012 y la política de tratamiento de datos.',
        'Aprobar, rechazar, suspender y cancelar notifican a la persona afectada. Revisa el caso antes de confirmar.'
    ]
};

const secciones = [
    {
        id: 'ingreso',
        imagen: { ruta: '/images/manual/login.webp', alt: 'Pantalla de inicio de sesión del panel, con los campos Correo y Contraseña y el botón Ingresar.' },
        titulo: 'Ingresar y moverse por el panel',
        icono: 'login',
        pasos: [
            'Escribe tu **Correo** y **Contraseña** y toca **Ingresar**. Solo entran las cuentas con rol de administrador. Si la sesión vence por inactividad, el panel te pide ingresar de nuevo.',
            'Usa el menú lateral para ir a **Inicio**, **Solicitudes**, **Gestores**, **Reportes**, **Ciudadanos**, **Materiales** o **Autoridades**. En el celular, el menú se abre con el botón de tres líneas de la barra superior.',
            'En las pantallas que tienen recorrido guiado, el botón de ayuda de la barra superior lo muestra de nuevo.',
            'Para salir, toca **Cerrar sesión**.'
        ]
    },
    {
        id: 'inicio',
        imagen: { ruta: '/images/manual/inicio.webp', alt: 'Pantalla Inicio del panel: tarjetas de pendientes de acción, tabla de gestores por revisar y cifras generales.' },
        titulo: 'Revisar lo pendiente en Inicio',
        icono: 'home',
        intro: 'En **Inicio** aparece primero lo que necesita atención: gestores por revisar, solicitudes con problema reportado y recolecciones sin confirmar. Debajo están las cifras generales y los gráficos de solicitudes por estado y por municipio; cada gráfico tiene la opción **Ver como tabla**.'
    },
    {
        id: 'gestores',
        imagen: { ruta: '/images/manual/gestor_detalle.webp', alt: 'Detalle de una empresa gestora por revisar, con los botones Aprobar y Rechazar, sus datos y el enlace a la licencia en PDF.' },
        titulo: 'Verificar una empresa gestora',
        icono: 'domain',
        pasos: [
            'En **Gestores**, abre una empresa con estado **Por revisar** usando **Ver detalle**. El filtro **Solo con materiales por verificar** ayuda a encontrarlas.',
            'Revisa los **Datos de la empresa** y abre la **Licencia o permiso ambiental**. El PDF se abre en una pestaña nueva con un enlace temporal; si el enlace vence, vuelve a abrirlo desde el detalle.',
            'En **Materiales que recibe**, toca **Quitar** en los materiales que la licencia no autorice.',
            'Toca **Aprobar** para habilitar a la empresa. Los materiales que quedan se verifican y la empresa recibe un aviso. Si la licencia no es válida, toca **Rechazar** y escribe el motivo: la empresa lo recibe en su notificación. Una empresa aprobada se puede **Suspender** más adelante.',
            'Si una empresa ya aprobada agrega un material nuevo, revísalo en su detalle y toca **Verificar** o **Quitar**.',
            'Cada decisión queda guardada en el **Historial de decisiones** de la empresa.'
        ]
    },
    {
        id: 'solicitudes',
        imagen: { ruta: '/images/manual/solicitudes.webp', alt: 'Pantalla Solicitudes con los filtros por estado, categoría, municipio y fechas, y la lista de residuos publicados.' },
        titulo: 'Supervisar solicitudes y resolver problemas',
        icono: 'local_shipping',
        pasos: [
            'En **Solicitudes**, filtra por estado, categoría, municipio o fechas. Marca **Sin certificado (+7 días)** o **Solo con problema reportado** para ver los casos que requieren seguimiento.',
            'Abre una solicitud con **Ver detalle**: verás el generador, el gestor asignado, las postulaciones, el certificado y la **Línea de tiempo** con cada cambio de estado.',
            'Si el generador reportó que no pasaron a recoger su residuo, revisa el caso y toca **Resuelto: no se recogió**. La solicitud vuelve a quedar en negociación con el mismo gestor para que la recoja, y el generador y el gestor reciben un aviso.',
            'Si es necesario, usa **Cancelar solicitud**.'
        ]
    },
    {
        id: 'reportes',
        imagen: { ruta: '/images/manual/reportes.webp', alt: 'Pantalla Reportes con los filtros de fechas, categoría y municipio, las cifras principales y el botón Descargar Excel.' },
        titulo: 'Generar reportes',
        icono: 'monitoring',
        pasos: [
            'Entra a **Reportes**.',
            'Elige las fechas (**Confirmadas desde** y **Confirmadas hasta**), la categoría y el municipio, y toca **Aplicar filtros**.',
            'Revisa las cifras, la gráfica por municipio y la tabla de cantidades. Las cantidades se suman por la unidad que declaró cada generador; no se convierten ni se mezclan unidades.',
            'Toca **Descargar Excel** para guardar el reporte.'
        ]
    },
    {
        id: 'catalogos',
        titulo: 'Ciudadanos, materiales y autoridades',
        icono: 'category',
        intro: 'En **Ciudadanos** consultas los generadores registrados y sus publicaciones. En **Materiales** agregas residuos al catálogo con **Nuevo material** o los cambias con **Editar**. En **Autoridades** mantienes el directorio de entidades ambientales que la app muestra a los usuarios, con **Nueva autoridad** y **Editar**.'
    },
    {
        id: 'asistente',
        titulo: 'Preguntar al asistente',
        icono: 'smart_toy',
        intro: 'El **Asistente** responde en lenguaje natural preguntas sobre gestores, solicitudes, recolecciones, certificados o materiales, con las cifras del panel. Solo atiende temas de la fiscalización de residuos. Para usarlo, el servidor debe tener configurada la clave de Gemini; si no la tiene, el asistente lo indica.'
    }
];

const preguntas = [
    {
        pregunta: 'Un gestor dice que no ve solicitudes.',
        respuesta: 'Revisa en su detalle que la empresa esté aprobada y que sus materiales estén verificados: el gestor solo ve solicitudes de los materiales verificados.'
    },
    {
        pregunta: 'Una recolección lleva días sin confirmar.',
        respuesta: 'Si el generador no responde en 72 horas, el sistema la confirma automáticamente. Si hay un problema reportado, aparece en **Inicio** y en el filtro **Solo con problema reportado**.'
    },
    {
        pregunta: 'Una recolección no tiene certificado.',
        respuesta: 'En **Solicitudes**, el filtro **Sin certificado (+7 días)** muestra las solicitudes recolectadas hace más de 7 días que todavía no tienen certificado o acta.'
    }
];

module.exports = { informacion, secciones, preguntas };
