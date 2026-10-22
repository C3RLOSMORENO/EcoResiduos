// Recorridos guiados del panel: qué pasos tiene cada pantalla y en qué
// versión entró cada uno. El navegador recibe esta definición en la página
// (public/js/recorrido.js la lee) y el servidor la usa para validar lo que
// guarda; así el texto y la versión viven en un solo lugar.
//
// Para agregar pasos en una actualización: sube `version` y marca los pasos
// nuevos con `desde` igual a la versión nueva. Quien ya vio la versión
// anterior verá solo esos pasos; quien nunca la vio, el recorrido completo.
//
// `elemento` apunta a un atributo data-recorrido de la vista: si la sección
// no se pintó (por ejemplo, no hay datos), el paso se salta.

const LARGO_TITULO = 40;
const LARGO_TEXTO = 110;

const RECORRIDOS = {
    dashboard: {
        version: 1,
        pasos: [
            {
                desde: 1,
                elemento: '[data-recorrido="pendientes"]',
                titulo: 'Bandeja de pendientes',
                texto: 'Alertas que requieren decisión: gestores por auditar, incidencias y certificados demorados.',
                lado: 'bottom'
            },
            {
                desde: 1,
                elemento: '[data-recorrido="gestores"]',
                titulo: 'Auditoría de gestores',
                texto: 'Valida la documentación ambiental y cobertura antes de autorizar a una empresa en la app.',
                lado: 'top'
            },
            {
                desde: 1,
                elemento: '[data-recorrido="graficos"]',
                titulo: 'Métricas y trazabilidad',
                texto: 'Monitorea el flujo de solicitudes y la distribución territorial de residuos en Santander.',
                lado: 'top'
            },
            {
                desde: 1,
                elemento: '#botonRecorrido',
                titulo: 'Ayuda bajo demanda',
                texto: 'Reactiva este recorrido en cualquier momento sin interrumpir tus tareas en el panel.',
                lado: 'bottom',
                alineacion: 'end'
            }
        ]
    },

    solicitudes: {
        version: 1,
        pasos: [
            {
                desde: 1,
                elemento: '[data-recorrido="solicitudes-alertas"]',
                titulo: 'Alertas de seguimiento',
                texto: 'Filtra solicitudes con problema reportado o sin certificado hace 7+ días: son las que necesitan acción.',
                lado: 'bottom'
            },
            {
                desde: 1,
                elemento: '[data-recorrido="solicitudes-tabla"]',
                titulo: 'Historial de cada residuo',
                texto: 'Cada fila lleva al detalle: postulaciones, gestor asignado, valor acordado y certificado de aprovechamiento.',
                lado: 'top'
            }
        ]
    },

    gestores: {
        version: 1,
        pasos: [
            {
                desde: 1,
                elemento: '[data-recorrido="gestores-nuevo"]',
                titulo: 'Registrar una empresa nueva',
                texto: 'Agrega empresas que no se registraron desde la app. Las que sí lo hicieron llegan aquí en Pendiente.',
                lado: 'bottom',
                alineacion: 'end'
            },
            {
                desde: 1,
                elemento: '[data-recorrido="gestores-tabla"]',
                titulo: 'Auditoría de permisos',
                texto: 'Revisa el permiso antes de aprobar. Solo empresas aprobadas con materiales verificados son visibles en la app.',
                lado: 'top'
            }
        ]
    },

    reportes: {
        version: 1,
        pasos: [
            {
                desde: 1,
                elemento: '[data-recorrido="reportes-filtros"]',
                titulo: 'Informes por período y municipio',
                texto: 'Ajusta el rango de fechas y filtra por municipio o categoría para obtener los datos que necesitas.',
                lado: 'bottom'
            },
            {
                desde: 1,
                elemento: '[data-recorrido="reportes-descarga"]',
                titulo: 'Exportar a Excel',
                texto: 'Descarga los datos del período filtrado en formato Excel, listo para entregar a la autoridad ambiental.',
                lado: 'bottom',
                alineacion: 'end'
            }
        ]
    },

    generadores: {
        version: 1,
        pasos: [
            {
                desde: 1,
                elemento: '[data-recorrido="ciudadanos"]',
                titulo: 'Solo lectura y protegido',
                texto: 'Consulta generadores y su actividad. Sus datos personales los gestiona cada usuario en la app.',
                lado: 'bottom'
            }
        ]
    },

    materiales: {
        version: 1,
        pasos: [
            {
                desde: 1,
                elemento: '[data-recorrido="materiales-nuevo"]',
                titulo: 'Ampliar el catálogo',
                texto: 'Agrega residuos. Este catálogo lo usa el reconocedor IA y la lista que declaran los gestores al registrarse.',
                lado: 'bottom',
                alineacion: 'end'
            },
            {
                desde: 1,
                elemento: '[data-recorrido="materiales-tabla"]',
                titulo: 'Código y categoría',
                texto: 'El código aparece en la ficha de cada residuo en la app. La categoría define qué gestores lo reciben.',
                lado: 'top'
            }
        ]
    },

    autoridades: {
        version: 1,
        pasos: [
            {
                desde: 1,
                elemento: '[data-recorrido="autoridades-nuevo"]',
                titulo: 'Mantener el directorio al día',
                texto: 'Agrega o edita entidades de control. La app las muestra a todos los usuarios para que sepan a quién reportar.',
                lado: 'bottom',
                alineacion: 'end'
            }
        ]
    }
};

const ESTADOS = ['visto', 'completado', 'omitido'];

/**
 * Lo que se guardó de cada recorrido vive en los metadatos del usuario de
 * Supabase Auth, con una clave por pantalla: Supabase mezcla las claves de
 * primer nivel al actualizar, así guardar una pantalla no borra las demás.
 *
 * @param {string} pantalla Clave de RECORRIDOS.
 * @returns {string}
 */
function claveMetadatos(pantalla) {
    return `recorrido_panel_${pantalla}`;
}

/**
 * Última versión del recorrido que el usuario ya vio.
 *
 * @param {?object} usuario Usuario de Supabase Auth.
 * @param {string} pantalla
 * @returns {number} 0 si nunca lo vio.
 */
function versionVista(usuario, pantalla) {
    const guardado = usuario && usuario.user_metadata && usuario.user_metadata[claveMetadatos(pantalla)];
    const version = Number(guardado && guardado.version);
    return Number.isInteger(version) && version > 0 ? version : 0;
}

/**
 * Datos que necesita el navegador para mostrar el recorrido de una pantalla.
 *
 * @param {string} pantalla
 * @param {?object} usuario Usuario de Supabase Auth.
 * @returns {?object} null si la pantalla no tiene recorrido.
 */
function datosRecorrido(pantalla, usuario) {
    const recorrido = RECORRIDOS[pantalla];
    if (!recorrido) return null;
    return {
        pantalla,
        version: recorrido.version,
        vista: versionVista(usuario, pantalla),
        usuario: (usuario && usuario.id) || '',
        pasos: recorrido.pasos
    };
}

/**
 * Valida lo que manda el navegador al terminar o saltar un recorrido.
 *
 * @param {string} pantalla
 * @param {*} cuerpo req.body con version, estado y paso.
 * @returns {?{version: number, estado: string, paso: number}} El registro a
 *     guardar, o null si algo no cuadra.
 */
function registroValido(pantalla, cuerpo) {
    const recorrido = RECORRIDOS[pantalla];
    if (!recorrido || !cuerpo || typeof cuerpo !== 'object') return null;
    const version = Number(cuerpo.version);
    const paso = Number(cuerpo.paso);
    if (!Number.isInteger(version) || version < 1 || version > recorrido.version) return null;
    if (!ESTADOS.includes(cuerpo.estado)) return null;
    if (!Number.isInteger(paso) || paso < 0 || paso > recorrido.pasos.length) return null;
    return { version, estado: cuerpo.estado, paso };
}

module.exports = { RECORRIDOS, ESTADOS, LARGO_TITULO, LARGO_TEXTO, claveMetadatos, versionVista, datosRecorrido, registroValido };
