const crypto = require('crypto');

// Origen de Supabase (https://<proyecto>.supabase.co): de ahí vienen las
// fotos de las solicitudes y ahí habla la página de restablecer contraseña.
function origenSupabase() {
    try {
        return new URL(process.env.SUPABASE_URL).origin;
    } catch {
        return '';
    }
}

// Content-Security-Policy: solo corre JavaScript del propio panel o el
// script en línea que lleve el nonce de esta respuesta. Así, aunque un dato
// se colara sin escapar, el navegador no lo ejecutaría.
function politicaContenido(nonce, produccion) {
    const supabase = origenSupabase();
    const directivas = [
        "default-src 'self'",
        `script-src 'self' 'nonce-${nonce}'`,
        "style-src 'self' https://fonts.googleapis.com",
        'font-src https://fonts.gstatic.com',
        `img-src 'self' data: ${supabase}`.trim(),
        `connect-src 'self' ${supabase}`.trim(),
        "object-src 'none'",
        "base-uri 'self'",
        "form-action 'self'",
        "frame-ancestors 'none'"
    ];
    if (produccion) directivas.push('upgrade-insecure-requests');
    return directivas.join('; ');
}

function seguridadMiddleware(req, res, next) {
    const produccion = process.env.NODE_ENV === 'production';
    const nonce = crypto.randomBytes(16).toString('base64');
    res.locals.nonce = nonce;

    res.set({
        'Content-Security-Policy': politicaContenido(nonce, produccion),
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
        'Referrer-Policy': 'same-origin',
        'Permissions-Policy': 'camera=(), microphone=(), geolocation=(), payment=(), usb=()',
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Resource-Policy': 'same-origin'
    });
    // HSTS solo en producción: en local el panel corre en http://localhost.
    if (produccion) res.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
    next();
}

module.exports = seguridadMiddleware;
module.exports.politicaContenido = politicaContenido;
