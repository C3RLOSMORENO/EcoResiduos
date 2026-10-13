const crypto = require('crypto');

// Protección contra envíos falsificados desde otro sitio (CSRF), con dos
// barreras independientes:
//   1. El navegador dice de dónde viene la petición (Origin y
//      Sec-Fetch-Site); si viene de otro sitio, se rechaza.
//   2. Cada formulario lleva un token que debe coincidir con la cookie
//      csrf. Otro sitio no puede leer esa cookie, así que no puede adivinar
//      el token (patrón «double submit cookie» de OWASP).
const METODOS_SEGUROS = new Set(['GET', 'HEAD', 'OPTIONS']);
const CAMPO = '_csrf';
const CABECERA = 'X-CSRF-Token';

/**
 * En producción, el prefijo __Host- obliga a que la cookie sea Secure, sin
 * Domain y con Path=/: un subdominio no puede sobrescribirla.
 *
 * @returns {string}
 */
function nombreCookie() {
    return process.env.NODE_ENV === 'production' ? '__Host-csrf' : 'csrf';
}

/**
 * Compara dos tokens en tiempo constante.
 *
 * @param {*} a
 * @param {*} b
 * @returns {boolean} false también si alguno está vacío.
 */
function iguales(a, b) {
    const x = Buffer.from(String(a || ''));
    const y = Buffer.from(String(b || ''));
    return x.length > 0 && x.length === y.length && crypto.timingSafeEqual(x, y);
}

/**
 * @param {import('express').Request} req
 * @returns {boolean} true si Sec-Fetch-Site u Origin indican otro sitio.
 */
function vieneDeOtroSitio(req) {
    const sitio = req.get('Sec-Fetch-Site');
    if (sitio && sitio !== 'same-origin' && sitio !== 'none') return true;
    const origen = req.get('Origin');
    if (!origen) return false;
    try {
        return new URL(origen).host !== req.get('host');
    } catch {
        return true;
    }
}

/**
 * Responde 403 con JSON o con la página de error, según quién pidió.
 *
 * @param {import('express').Request} req
 * @param {import('express').Response} res
 */
function rechazar(req, res) {
    const mensaje = 'Por seguridad no guardamos este envío. Recarga la página y vuelve a intentarlo.';
    if (req.get('X-Requested-With') === 'fetch') {
        return res.status(403).json({ ok: false, mensaje });
    }
    return res.status(403).render('404', {
        titulo: 'No pudimos confirmar el envío',
        mensaje,
        icono: 'gpp_maybe'
    });
}

/**
 * Entrega el token en res.locals.csrfToken y, en los métodos que modifican
 * datos, exige que el token enviado coincida con la cookie.
 *
 * @param {import('express').Request} req
 * @param {import('express').Response} res
 * @param {import('express').NextFunction} next
 */
function csrfMiddleware(req, res, next) {
    const nombre = nombreCookie();
    let token = req.cookies && req.cookies[nombre];
    if (!token) {
        token = crypto.randomBytes(32).toString('base64url');
        res.cookie(nombre, token, {
            httpOnly: true,
            secure: process.env.NODE_ENV === 'production',
            sameSite: 'strict',
            path: '/'
        });
    }
    res.locals.csrfToken = token;

    if (METODOS_SEGUROS.has(req.method)) return next();

    const enviado = (req.body && typeof req.body === 'object' && !Buffer.isBuffer(req.body) && req.body[CAMPO]) || req.get(CABECERA);
    const cookie = req.cookies && req.cookies[nombre];
    if (vieneDeOtroSitio(req) || !iguales(enviado, cookie)) return rechazar(req, res);

    if (req.body && typeof req.body === 'object' && !Buffer.isBuffer(req.body)) delete req.body[CAMPO];
    return next();
}

module.exports = csrfMiddleware;
module.exports.CAMPO = CAMPO;
module.exports.CABECERA = CABECERA;
