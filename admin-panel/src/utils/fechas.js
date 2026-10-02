// Colombia no tiene horario de verano: siempre UTC-05:00.
const DESFASE_BOGOTA = '-05:00';
const FECHA_ISO = /^\d{4}-\d{2}-\d{2}$/;

function fechaValida(texto) {
    if (!FECHA_ISO.test(String(texto || ''))) return null;
    const d = new Date(`${texto}T00:00:00Z`);
    return Number.isNaN(d.getTime()) || d.toISOString().slice(0, 10) !== texto ? null : texto;
}

function diaSiguiente(fechaIso) {
    const d = new Date(`${fechaIso}T00:00:00Z`);
    d.setUTCDate(d.getUTCDate() + 1);
    return d.toISOString().slice(0, 10);
}

// Límites en UTC de un rango de días en hora de Colombia: «hasta» incluye el
// día completo, así una recolección del 31 a las 8 p. m. no pasa al mes siguiente.
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

function haceDias(dias, ahora = new Date()) {
    return new Date(ahora.getTime() - dias * 24 * 60 * 60 * 1000).toISOString();
}

module.exports = { rangoBogota, haceDias };
