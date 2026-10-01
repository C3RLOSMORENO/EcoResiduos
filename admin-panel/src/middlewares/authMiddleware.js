const authService = require('../services/authService');
const { DURACION_SESION_MS, guardarSesion, limpiarSesion } = require('../utils/sesion');

function esPeticionFetch(req) {
    return req.get('X-Requested-With') === 'fetch';
}

// Redirige al inicio de sesión recordando la página para volver a ella.
function aLogin(req, res, mensaje) {
    if (esPeticionFetch(req)) {
        return res.status(401).json({ ok: false, mensaje });
    }
    const volver = req.method === 'GET' ? `&volver=${encodeURIComponent(req.originalUrl)}` : '';
    return res.redirect(`/login?msg=${encodeURIComponent(mensaje)}&type=error${volver}`);
}

const authMiddleware = {
    async requireAuth(req, res, next) {
        res.set({
            'Cache-Control': 'no-store, no-cache, must-revalidate, private',
            'Pragma': 'no-cache',
            'Expires': '0'
        });

        const token = req.cookies && req.cookies.sb_access_token;
        const refreshToken = req.cookies && req.cookies.sb_refresh_token;
        if (!token && !refreshToken) {
            return aLogin(req, res, 'Debes iniciar sesión para continuar');
        }

        try {
            let user = token ? await authService.getAdmin(token) : null;

            if (user) {
                guardarSesion(res, { accessToken: token, refreshToken });
            } else if (refreshToken) {
                // El token de Supabase dura una hora: con actividad se renueva
                // con el refresh token en lugar de sacar al administrador.
                const renovada = await authService.renovar(refreshToken);
                if (renovada) {
                    guardarSesion(res, {
                        accessToken: renovada.session.access_token,
                        refreshToken: renovada.session.refresh_token
                    });
                    user = renovada.user;
                }
            }

            if (!user) {
                limpiarSesion(res);
                return aLogin(req, res, 'Sesión inválida, expirada o sin permisos de administrador');
            }

            req.user = user;
            res.locals.user = user;
            res.locals.sesionMs = DURACION_SESION_MS;
            return next();
        } catch {
            limpiarSesion(res);
            return aLogin(req, res, 'Error de autenticación. Por favor inicia sesión');
        }
    }
};

module.exports = authMiddleware;
