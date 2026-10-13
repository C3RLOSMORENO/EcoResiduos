// Tiempo máximo de espera para cada petición a Supabase. Sin él, si Supabase
// se quedaba sin responder, la página quedaba cargando indefinidamente; con
// él la consulta falla y la pantalla muestra el error con «Reintentar».
const TIEMPO_CONSULTA_MS = 10 * 1000;
// Subir un PDF de 10 MB con una conexión lenta tarda más que una consulta.
const TIEMPO_ARCHIVO_MS = 60 * 1000;

/**
 * @param {string} url
 * @param {string} [metodo] Método HTTP; por defecto, GET.
 * @returns {boolean} true si la petición sube un archivo a Supabase Storage.
 */
function esSubidaDeArchivo(url, metodo) {
    return /\/storage\/v1\/object\//.test(url) && !['GET', 'HEAD'].includes(String(metodo || 'GET').toUpperCase());
}

/**
 * Envuelve fetch para que cada petición se cancele al pasar el tiempo; si
 * quien llama ya traía su propia señal de cancelación, se respetan las dos.
 *
 * @param {typeof fetch} [fetchBase] El fetch que se envuelve.
 * @param {{consultaMs?: number, archivoMs?: number}} [tiempos] Límites en
 *     milisegundos para consultas y para subidas de archivos.
 * @returns {typeof fetch}
 */
function fetchConLimite(fetchBase = globalThis.fetch, { consultaMs = TIEMPO_CONSULTA_MS, archivoMs = TIEMPO_ARCHIVO_MS } = {}) {
    return (recurso, opciones = {}) => {
        const url = typeof recurso === 'string' ? recurso : String(recurso && recurso.url ? recurso.url : recurso);
        const ms = esSubidaDeArchivo(url, opciones.method) ? archivoMs : consultaMs;
        const limite = AbortSignal.timeout(ms);
        const signal = opciones.signal ? AbortSignal.any([opciones.signal, limite]) : limite;
        return fetchBase(recurso, { ...opciones, signal }).catch((error) => {
            // postgrest-js reintenta tres veces (con pausas de 1, 2 y 4 s) todo
            // error que no sea AbortError, y el tiempo agotado llega como
            // TimeoutError: una consulta colgada hacía esperar unos 47 s. Se
            // entrega como AbortError para que el error se muestre de una vez.
            if (limite.aborted && error && error.name === 'TimeoutError') {
                const corte = new Error(`Supabase no respondió en ${ms / 1000} s.`);
                corte.name = 'AbortError';
                corte.cause = error;
                throw corte;
            }
            throw error;
        });
    };
}

module.exports = { fetchConLimite, TIEMPO_CONSULTA_MS, TIEMPO_ARCHIVO_MS };
