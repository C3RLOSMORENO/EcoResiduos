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
    }
};

const ESTADOS = ['visto', 'completado', 'omitido'];

// Lo que se guardó de cada recorrido vive en los metadatos del usuario de
// Supabase Auth, con una clave por pantalla: Supabase mezcla las claves de
// primer nivel al actualizar, así guardar una pantalla no borra las demás.
function claveMetadatos(pantalla) {
    return `recorrido_panel_${pantalla}`;
}

// Última versión del recorrido que el usuario ya vio (0 si nunca).
function versionVista(usuario, pantalla) {
    const guardado = usuario && usuario.user_metadata && usuario.user_metadata[claveMetadatos(pantalla)];
    const version = Number(guardado && guardado.version);
    return Number.isInteger(version) && version > 0 ? version : 0;
}

// Datos que necesita el navegador para mostrar el recorrido de una pantalla.
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

// Valida lo que manda el navegador al terminar o saltar un recorrido.
// Devuelve el registro a guardar o null si algo no cuadra.
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
