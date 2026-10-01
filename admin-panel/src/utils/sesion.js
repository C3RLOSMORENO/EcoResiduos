// La sesión del panel vence tras 15 minutos sin actividad. Cada petición
// autenticada vuelve a contar los 15 minutos.
const DURACION_SESION_MS = 15 * 60 * 1000;

function opcionesCookie() {
    return {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        path: '/',
        maxAge: DURACION_SESION_MS
    };
}

function guardarSesion(res, { accessToken, refreshToken }) {
    if (accessToken) res.cookie('sb_access_token', accessToken, opcionesCookie());
    if (refreshToken) res.cookie('sb_refresh_token', refreshToken, opcionesCookie());
}

function limpiarSesion(res) {
    res.clearCookie('sb_access_token', { path: '/' });
    res.clearCookie('sb_refresh_token', { path: '/' });
}

module.exports = { DURACION_SESION_MS, guardarSesion, limpiarSesion };
