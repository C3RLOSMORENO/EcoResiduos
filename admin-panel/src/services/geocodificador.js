// Geocodificación con Nominatim respetando su política de uso
// (https://operations.osmfoundation.org/policies/nominatim/): como máximo una
// petición por segundo y un User-Agent que identifique la aplicación.

// Centro de Bucaramanga: coordenadas por defecto cuando no se puede geocodificar.
const LATITUD_DEFECTO = 7.119349;
const LONGITUD_DEFECTO = -73.122741;
const INTERVALO_MS = 1100;
const USER_AGENT = 'EcoResiduos-PanelAdmin/1.0 (+https://github.com/C3RLOSMORENO/EcoResiduos)';

let cola = Promise.resolve();
let ultimaPeticion = 0;

/**
 * Encola la petición para que entre dos haya al menos INTERVALO_MS.
 *
 * @returns {Promise<void>}
 */
function esperarTurno() {
    const turno = cola.then(async () => {
        const espera = ultimaPeticion + INTERVALO_MS - Date.now();
        if (espera > 0) await new Promise((r) => setTimeout(r, espera));
        ultimaPeticion = Date.now();
    });
    cola = turno.catch(() => {});
    return turno;
}

/**
 * @param {string} direccion
 * @param {string} municipio
 * @returns {Promise<?{latitud: number, longitud: number}>} null si Nominatim no
 *     encuentra la dirección o no responde.
 */
async function geocodificar(direccion, municipio) {
    try {
        await esperarTurno();
        const consulta = encodeURIComponent(`${direccion}, ${municipio}, Santander, Colombia`);
        const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&countrycodes=co&limit=1&q=${consulta}`, {
            headers: { 'User-Agent': USER_AGENT, 'Accept-Language': 'es-CO' },
            signal: AbortSignal.timeout(8000)
        });
        if (!res.ok) return null;
        const data = await res.json();
        if (Array.isArray(data) && data.length > 0) {
            const latitud = parseFloat(data[0].lat);
            const longitud = parseFloat(data[0].lon);
            if (Number.isFinite(latitud) && Number.isFinite(longitud)) return { latitud, longitud };
        }
    } catch {
        // Sin conexión o tiempo agotado: quien llama decide qué coordenadas usar.
    }
    return null;
}

/**
 * @param {number|string} latitud
 * @param {number|string} longitud
 * @returns {boolean} true si son las coordenadas por defecto, es decir, que la
 *     dirección no se pudo ubicar.
 */
function sinUbicar(latitud, longitud) {
    return Number(latitud) === LATITUD_DEFECTO && Number(longitud) === LONGITUD_DEFECTO;
}

module.exports = { geocodificar, sinUbicar, LATITUD_DEFECTO, LONGITUD_DEFECTO };
