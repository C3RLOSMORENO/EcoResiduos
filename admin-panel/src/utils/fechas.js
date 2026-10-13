// Colombia no tiene horario de verano: siempre UTC-05:00.
const DESFASE_BOGOTA = '-05:00';
const FECHA_ISO = /^\d{4}-\d{2}-\d{2}$/;

/**
 * Devuelve el texto si es un día real en formato AAAA-MM-DD.
 *
 * @param {string} texto Fecha recibida en la URL.
 * @returns {?string} El mismo texto, o null si no es una fecha válida (por ejemplo, 2026-02-30).
 */
function fechaValida(texto) {
    if (!FECHA_ISO.test(String(texto || ''))) return null;
    const d = new Date(`${texto}T00:00:00Z`);
    return Number.isNaN(d.getTime()) || d.toISOString().slice(0, 10) !== texto ? null : texto;
}

/**
 * @param {string} fechaIso Día en formato AAAA-MM-DD.
 * @returns {string} El día siguiente, en el mismo formato.
 */
function diaSiguiente(fechaIso) {
    const d = new Date(`${fechaIso}T00:00:00Z`);
    d.setUTCDate(d.getUTCDate() + 1);
    return d.toISOString().slice(0, 10);
}

/**
 * Límites en UTC de un rango de días en hora de Colombia. «hasta» incluye el
 * día completo: una recolección del 31 a las 8 p. m. no pasa al mes siguiente.
 *
 * @param {string} [desde] Primer día del rango (AAAA-MM-DD).
 * @param {string} [hasta] Último día del rango (AAAA-MM-DD).
 * @returns {{desde: ?string, hasta: ?string, gte: ?string, lt: ?string}} Los días
 *     válidos y los instantes para los filtros gte y lt; null en los que no aplican.
 */
function rangoBogota(desde, hasta) {
    const inicio = fechaValida(desde);
    const fin = fechaValida(hasta);
    return {
        desde: inicio,
        hasta: fin,
        gte: inicio ? `${inicio}T00:00:00${DESFASE_BOGOTA}` : null,
        lt: fin ? `${diaSiguiente(fin)}T00:00:00${DESFASE_BOGOTA}` : null
    };
}

/**
 * @param {number} dias Días hacia atrás.
 * @param {Date} [ahora] Fecha de referencia; por defecto, el momento actual.
 * @returns {string} El instante de hace `dias` días, en ISO 8601.
 */
function haceDias(dias, ahora = new Date()) {
    return new Date(ahora.getTime() - dias * 24 * 60 * 60 * 1000).toISOString();
}

module.exports = { rangoBogota, haceDias };
