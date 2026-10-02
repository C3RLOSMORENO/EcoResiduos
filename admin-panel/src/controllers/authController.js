const authService = require('../services/authService');
const { guardarSesion, limpiarSesion } = require('../utils/sesion');
const { rutaInterna, jsonParaScript, conAviso } = require('../utils/web');
const { crearLimite } = require('../utils/limiteIntentos');

const INICIO = '/dashboard';
const MINUTO = 60 * 1000;

// 5 intentos fallidos por correo y 20 por IP cada 15 minutos. El de la IP es
// más alto porque en una oficina varias personas salen por la misma.
const limitePorCorreo = crearLimite({ maximo: 5, ventanaMs: 15 * MINUTO });
const limitePorIp = crearLimite({ maximo: 20, ventanaMs: 15 * MINUTO });

function mensajeEspera(ms) {
    const minutos = Math.max(1, Math.ceil(ms / MINUTO));
    return `Hiciste demasiados intentos seguidos. Espera ${minutos} ${minutos === 1 ? 'minuto' : 'minutos'} y vuelve a intentarlo, o restablece tu contraseña.`;
}

const authController = {
    async renderLogin(req, res) {
        const token = req.cookies && req.cookies.sb_access_token;
        const volver = rutaInterna(req.query.volver, '');

        if (token) {
            try {
                if (await authService.getAdmin(token)) {
                    return res.redirect(volver || INICIO);
                }
                limpiarSesion(res);
            } catch {
                limpiarSesion(res);
            }
        }

        res.render('login', { titulo: 'Iniciar sesión', volver });
    },

    async handleLogin(req, res) {
        const email = String(req.body.email || '').trim().toLowerCase();
        const password = String(req.body.password || '');
        const volver = rutaInterna(req.body.volver, '');
        const conVolver = volver ? `&volver=${encodeURIComponent(volver)}` : '';
        const devolver = (mensaje) => res.redirect(conAviso('/login', mensaje, 'error') + conVolver);

        if (!email || !password) {
            return devolver('Escribe tu correo y tu contraseña.');
        }

        const claveCorreo = `correo:${email}`;
        const claveIp = `ip:${req.ip}`;
        const espera = Math.max(limitePorCorreo.espera(claveCorreo), limitePorIp.espera(claveIp));
        if (espera > 0) {
            return devolver(mensajeEspera(espera));
        }

        try {
            const { session } = await authService.login(email, password);
            limitePorCorreo.limpiar(claveCorreo);
            if (session && session.access_token) {
                guardarSesion(res, { accessToken: session.access_token, refreshToken: session.refresh_token });
            }
            return res.redirect(conAviso(volver || INICIO, 'Iniciaste sesión.'));
        } catch (err) {
            if (err.codigo === 'CREDENCIALES') {
                limitePorCorreo.fallo(claveCorreo);
                limitePorIp.fallo(claveIp);
                return devolver('Correo o contraseña incorrectos.');
            }
            console.error('Inicio de sesión: falló Supabase Auth:', err.message);
            return devolver('No pudimos iniciar sesión por un problema del servicio. Intenta de nuevo en unos minutos.');
        }
    },

    // Cerrar sesión solo por POST (con token CSRF): por GET bastaría un enlace
    // o una imagen en otro sitio para sacar al administrador del panel.
    redirigirLogout(req, res) {
        res.redirect('/');
    },

    async handleLogout(req, res) {
        const token = req.cookies && req.cookies.sb_access_token;
        limpiarSesion(res);
        try {
            await authService.logout(token);
        } catch (err) {
            // La sesión local ya se cerró; si Supabase no revocó el token,
            // vence solo en menos de una hora.
            console.error('Cerrar sesión: Supabase no revocó el token:', err.message);
        }
        res.redirect(conAviso('/login', 'Cerraste sesión.'));
    },

    renderRestablecer(req, res) {
        res.render('restablecer-password', {
            titulo: 'Restablecer contraseña',
            configuracionSupabase: jsonParaScript({
                url: process.env.SUPABASE_URL || '',
                anonKey: process.env.SUPABASE_ANON_KEY || ''
            })
        });
    },

    // La renovación real la hace requireAuth; aquí solo se confirma.
    renovarSesion(req, res) {
        res.status(200).json({ ok: true });
    }
};

module.exports = authController;
