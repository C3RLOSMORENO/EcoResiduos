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

function firmaAviso(mensaje, tipo) {
    return crypto.createHmac('sha256', SECRETO_AVISOS).update(`${tipo}
${mensaje}`).digest('base64url').slice(0, 32);
}

function avisoAutentico(mensaje, tipo, firma) {
    const esperada = Buffer.from(firmaAviso(String(mensaje), String(tipo)));
    const recibida = Buffer.from(String(firma || ''));
    return esperada.length === recibida.length && crypto.timingSafeEqual(esperada, recibida);
}

// JSON para un <script type="application/json">: escapar «<» impide que un
// valor como «</script><script>…» cierre la etiqueta y ejecute código.
function jsonParaScript(valor) {
    return JSON.stringify(valor === undefined ? null : valor)
        .replace(/</g, '\\u003c')
        .replace(/>/g, '\\u003e')
        .replace(/&/g, '\\u0026')
        .replace(/\u2028/g, '\\u2028')
        .replace(/\u2029/g, '\\u2029');
}

function leerPagina(query) {
    const pagina = parseInt(query && query.pagina, 10);
    return Number.isInteger(pagina) && pagina > 0 ? pagina : 1;
}

function rango(pagina, tam = TAM_PAGINA) {
    const desde = (pagina - 1) * tam;
    return { desde, hasta: desde + tam - 1 };
}

// Datos para el parcial de paginación; conserva los filtros de la URL.
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

// Texto de búsqueda seguro para los filtros or() de PostgREST: las comas,
// paréntesis y comodines cambiarían el sentido del filtro.
function textoBusqueda(valor) {
    return String(valor || '')
        .replace(/[,()*%\\:"']/g, ' ')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 80);
}

// Solo rutas internas: evita usar el panel para redirigir a otro sitio.
function rutaInterna(valor, porDefecto) {
    const texto = String(valor || '');
    if (texto.startsWith('/') && !texto.startsWith('//') && !texto.startsWith('/\\')) return texto;
    return porDefecto;
}

// Errores de PostgREST cuando la columna o la función aún no existen porque
// falta correr una migración.
function faltaEnEsquema(error) {
    if (!error) return false;
    const codigo = String(error.code || '');
    const mensaje = String(error.message || '');
    return codigo === '42703' || codigo === 'PGRST204' || codigo === 'PGRST202' || codigo === '42883'
        || /column .* does not exist|Could not find the .* (column|function)/i.test(mensaje);
}

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
