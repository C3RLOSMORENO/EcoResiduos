// Variables de entorno del panel. Se revisan al arrancar para que una que
// falte se note con un mensaje claro y no como un error raro en la primera
// petición.
const path = require('path');
const dotenv = require('dotenv');

const OBLIGATORIAS = {
    SUPABASE_URL: 'la dirección del proyecto de Supabase (https://….supabase.co)',
    SUPABASE_ANON_KEY: 'la llave pública (anon) del proyecto',
    SUPABASE_SERVICE_ROLE_KEY: 'la llave service_role del proyecto'
};

/**
 * El .env de admin-panel/ y, si se arranca desde otra carpeta, el de esa
 * carpeta. dotenv no pisa una variable que ya venga del sistema.
 */
function cargarEntorno() {
    dotenv.config({ path: path.resolve(__dirname, '../../.env') });
    dotenv.config();
    // En Vercel (producción y vistas previas) siempre hay HTTPS: sin NODE_ENV
    // las cookies saldrían sin Secure y sin el prefijo __Host-.
    if (!process.env.NODE_ENV && ['production', 'preview'].includes(process.env.VERCEL_ENV)) {
        process.env.NODE_ENV = 'production';
    }
}

/**
 * @param {NodeJS.ProcessEnv} [entorno] Por defecto, process.env.
 * @returns {{faltan: string[], avisos: string[]}} faltan: lo que impide
 *     arrancar. avisos: lo que conviene revisar pero no rompe el panel.
 */
function revisarEntorno(entorno = process.env) {
    const valor = (nombre) => String(entorno[nombre] || '').trim();
    const faltan = Object.keys(OBLIGATORIAS)
        .filter((nombre) => !valor(nombre))
        .map((nombre) => `${nombre}: ${OBLIGATORIAS[nombre]}`);

    if (valor('SUPABASE_URL') && !/^https?:\/\/[^\s/]+/.test(valor('SUPABASE_URL'))) {
        faltan.push(`SUPABASE_URL: «${valor('SUPABASE_URL')}» no es una dirección web`);
    }

    const avisos = [];
    if (valor('NODE_ENV') === 'production') {
        // Sin secreto fijo cada instancia (o cada reinicio) firma los avisos
        // con uno distinto, y «Gestor aprobado» y similares desaparecen al azar.
        if (!valor('SECRETO_PANEL')) {
            faltan.push('SECRETO_PANEL: una cadena larga y aleatoria para firmar los avisos (ver .env.example)');
        }
        // En Vercel el proxy se configura solo (crearApp.js).
        if (!valor('TRUST_PROXY') && !valor('VERCEL')) {
            avisos.push('TRUST_PROXY está vacía: si el panel está detrás de un proxy (Render, Railway, Nginx), el límite de intentos de inicio de sesión ve a todos con la misma IP.');
        }
    }
    if (!valor('GEMINI_API_KEY')) {
        avisos.push('GEMINI_API_KEY está vacía: el asistente aparece desactivado.');
    }
    return { faltan, avisos };
}

module.exports = { cargarEntorno, revisarEntorno };
