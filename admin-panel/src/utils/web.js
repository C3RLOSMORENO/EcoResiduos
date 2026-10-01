const TAM_PAGINA = 25;

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
            if (k !== 'pagina' && v !== undefined && v !== null && String(v) !== '' && !['msg', 'type', 'success', 'error'].includes(k)) {
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
    return `${ruta}${separador}msg=${encodeURIComponent(mensaje)}&type=${tipo}`;
}

module.exports = {
    TAM_PAGINA,
    jsonParaScript,
    leerPagina,
    rango,
    paginacion,
    textoBusqueda,
    rutaInterna,
    faltaEnEsquema,
    conAviso
};
