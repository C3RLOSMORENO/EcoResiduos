const crypto = require('crypto');

const TAM_PAGINA = 25;

// Parámetros de la URL que son avisos y no filtros: no se copian al paginar
// ni al volver a la página después de una acción.
const PARAMETROS_AVISO = ['msg', 'type', 'firma', 'aviso'];

// Los avisos viajan en la URL (?msg=…) y van firmados con este secreto: así
// nadie puede armar un enlace al panel que muestre un mensaje falso («tu
// cuenta fue bloqueada, llama a…»). Sin SECRETO_PANEL se usa uno al azar que
// dura lo que dure el proceso, suficiente porque el aviso se lee enseguida.
const SECRETO_AVISOS = process.env.SECRETO_PANEL || crypto.randomBytes(32).toString('hex');

/**
 * @param {string} mensaje
 * @param {string} tipo 'success' o 'error'.
 * @returns {string} HMAC-SHA256 del tipo y el mensaje, recortado a 32 caracteres.
 */
function firmaAviso(mensaje, tipo) {
    return crypto.createHmac('sha256', SECRETO_AVISOS).update(`${tipo}
${mensaje}`).digest('base64url').slice(0, 32);
}

/**
 * Compara en tiempo constante la firma recibida con la esperada.
 *
 * @param {string} mensaje
 * @param {string} tipo
 * @param {?string} firma
 * @returns {boolean}
 */
function avisoAutentico(mensaje, tipo, firma) {
    const esperada = Buffer.from(firmaAviso(String(mensaje), String(tipo)));
    const recibida = Buffer.from(String(firma || ''));
    return esperada.length === recibida.length && crypto.timingSafeEqual(esperada, recibida);
}

/**
 * JSON para un <script type="application/json">: escapar «<» impide que un
 * valor como «</script><script>…» cierre la etiqueta y ejecute código.
 *
 * @param {*} valor
 * @returns {string}
 */
function jsonParaScript(valor) {
    return JSON.stringify(valor === undefined ? null : valor)
        .replace(/</g, '\\u003c')
        .replace(/>/g, '\\u003e')
        .replace(/&/g, '\\u0026')
        .replace(/\u2028/g, '\\u2028')
        .replace(/\u2029/g, '\\u2029');
}

/**
 * @param {object} query req.query.
 * @returns {number} El número de página pedido, o 1 si no es un entero positivo.
 */
function leerPagina(query) {
    const pagina = parseInt(query && query.pagina, 10);
    return Number.isInteger(pagina) && pagina > 0 ? pagina : 1;
}

/**
 * Filas que corresponden a una página, para .range() de Supabase.
 *
 * @param {number} pagina Desde 1.
 * @param {number} [tam] Filas por página.
 * @returns {{desde: number, hasta: number}} Índices desde 0, ambos incluidos.
 */
function rango(pagina, tam = TAM_PAGINA) {
    const desde = (pagina - 1) * tam;
    return { desde, hasta: desde + tam - 1 };
}

/**
 * Datos para el parcial de paginación; conserva los filtros de la URL.
 *
 * @param {object} opciones
 * @param {number} opciones.total Filas que cumplen los filtros.
 * @param {number} opciones.pagina Página pedida; se ajusta al rango válido.
 * @param {string} opciones.ruta Ruta de la lista, sin parámetros.
 * @param {object} opciones.query req.query.
 * @param {number} [opciones.tam] Filas por página.
 * @returns {object} Totales, página actual y enlaces anterior y siguiente.
 */
function paginacion({ total, pagina, ruta, query, tam = TAM_PAGINA }) {
    const totalPaginas = Math.max(1, Math.ceil((total || 0) / tam));
    const actual = Math.min(Math.max(1, pagina), totalPaginas);
    const enlace = (n) => {
        const params = new URLSearchParams();
        Object.entries(query || {}).forEach(([k, v]) => {
            if (k !== 'pagina' && v !== undefined && v !== null && String(v) !== '' && !PARAMETROS_AVISO.includes(k)) {
                params.set(k, String(v));
            }
        });
        if (n > 1) params.set('pagina', String(n));
        const texto = params.toString();
        return texto ? `${ruta}?${texto}` : ruta;
    };
    return {
        total: total || 0,
        pagina: actual,
        totalPaginas,
        desde: total ? (actual - 1) * tam + 1 : 0,
        hasta: Math.min(actual * tam, total || 0),
        anterior: actual > 1 ? enlace(actual - 1) : null,
        siguiente: actual < totalPaginas ? enlace(actual + 1) : null,
        enlace
    };
}

/**
 * Texto de búsqueda seguro para los filtros or() de PostgREST: las comas,
 * paréntesis y comodines cambiarían el sentido del filtro.
 *
 * @param {*} valor
 * @returns {string} Como máximo 80 caracteres.
 */
function textoBusqueda(valor) {
    return String(valor || '')
        .replace(/[,()*%\\:"']/g, ' ')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 80);
}

/**
 * Solo rutas internas: evita usar el panel para redirigir a otro sitio.
 *
 * @param {*} valor Ruta recibida en la URL o en el formulario.
 * @param {string} porDefecto Ruta a usar si `valor` no es interna.
 * @returns {string}
 */
function rutaInterna(valor, porDefecto) {
    const texto = String(valor || '');
    if (texto.startsWith('/') && !texto.startsWith('//') && !texto.startsWith('/\\')) return texto;
    return porDefecto;
}

/**
 * Errores de PostgREST cuando la columna o la función aún no existen porque
 * falta correr una migración.
 *
 * @param {?object} error Error devuelto por Supabase.
 * @returns {boolean}
 */
function faltaEnEsquema(error) {
    if (!error) return false;
    const codigo = String(error.code || '');
    const mensaje = String(error.message || '');
    return codigo === '42703' || codigo === 'PGRST204' || codigo === 'PGRST202' || codigo === '42883'
        || /column .* does not exist|Could not find the .* (column|function)/i.test(mensaje);
}

/**
 * Agrega a la ruta un aviso firmado para mostrar en la página de destino.
 *
 * @param {string} ruta
 * @param {string} mensaje
 * @param {string} [tipo] 'success' o 'error'.
 * @returns {string}
 */
function conAviso(ruta, mensaje, tipo = 'success') {
    const separador = ruta.includes('?') ? '&' : '?';
    return `${ruta}${separador}msg=${encodeURIComponent(mensaje)}&type=${tipo}&firma=${firmaAviso(mensaje, tipo)}`;
}

module.exports = {
    PARAMETROS_AVISO,
    jsonParaScript,
    leerPagina,
    rango,
    paginacion,
    textoBusqueda,
    rutaInterna,
    faltaEnEsquema,
    conAviso,
    avisoAutentico
};
