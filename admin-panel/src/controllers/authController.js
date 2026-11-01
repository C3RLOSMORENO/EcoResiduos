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

/**
 * @param {number} ms Milisegundos que faltan para poder intentar de nuevo.
 * @returns {string}
 */
function mensajeEspera(ms) {
    const minutos = Math.max(1, Math.ceil(ms / MINUTO));
    return `Hiciste demasiados intentos seguidos. Espera ${minutos} ${minutos === 1 ? 'minuto' : 'minutos'} y vuelve a intentarlo, o restablece tu contraseña.`;
}

/**
 * Vuelve a mostrar el login con el error del intento. Se responde con la
 * página, sin redirigir, para conservar el correo escrito: así solo hay que
 * corregir lo que falló.
 *
 * @param {import('express').Response} res
 * @param {number} estado Código HTTP: 400 si falta un dato, 422 si no coinciden (401 exigiría
 *   la cabecera WWW-Authenticate, que no aplica a un formulario), 429 o 503.
 * @param {{ correo: string, volver: string, mensaje: string, campos?: boolean }} datos
 *   campos: true si el error es del correo o la contraseña (se marcan los dos).
 */
function renderError(res, estado, { correo, volver, mensaje, campos = false }) {
    return res.status(estado).render('login', {
        titulo: 'Iniciar sesión',
        volver,
        correo,
        errorLogin: { mensaje, campos }
    });
}

const authController = {
    /** GET /login. Con una sesión válida va directo al panel. */
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

        res.render('login', { titulo: 'Iniciar sesión', volver, correo: '', errorLogin: null });
    },

    /** POST /login: valida las credenciales con límite de intentos por correo y por IP. */
    async handleLogin(req, res) {
        const email = String(req.body.email || '').trim().toLowerCase();
        const password = String(req.body.password || '');
        const volver = rutaInterna(req.body.volver, '');
        const datos = { correo: email, volver };

        if (!email || !password) {
            const falta = !email && !password ? 'tu correo y tu contraseña' : (!email ? 'tu correo' : 'tu contraseña');
            return renderError(res, 400, { ...datos, mensaje: `Escribe ${falta} para entrar.`, campos: true });
        }

        const claveCorreo = `correo:${email}`;
        const claveIp = `ip:${req.ip}`;
        const espera = Math.max(limitePorCorreo.espera(claveCorreo), limitePorIp.espera(claveIp));
        if (espera > 0) {
            res.set('Retry-After', String(Math.ceil(espera / 1000)));
            return renderError(res, 429, { ...datos, mensaje: mensajeEspera(espera) });
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
                return renderError(res, 422, {
                    ...datos,
                    mensaje: 'El correo o la contraseña no coinciden. Revisa que estén bien escritos o restablece la contraseña.',
                    campos: true
                });
            }
            console.error('Inicio de sesión: falló Supabase Auth:', err.message);
            return renderError(res, 503, {
                ...datos,
                mensaje: 'No pudimos iniciar sesión porque el servicio no respondió. Inténtalo de nuevo en unos minutos.'
            });
        }
    },

    /**
     * GET /logout. Cerrar sesión solo por POST (con token CSRF): por GET bastaría
     * un enlace o una imagen en otro sitio para sacar al administrador del panel.
     */
    redirigirLogout(req, res) {
        res.redirect('/');
    },

    /** POST /logout: borra las cookies y revoca la sesión en Supabase. */
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

    /**
     * GET /restablecer-password: la página habla directo con Supabase Auth, así
     * que recibe la URL y la llave pública (anon) del proyecto.
     */
    renderRestablecer(req, res) {
        res.render('restablecer-password', {
            titulo: 'Restablecer contraseña',
            configuracionSupabase: jsonParaScript({
                url: process.env.SUPABASE_URL || '',
                anonKey: process.env.SUPABASE_ANON_KEY || ''
            })
        });
    },

    /** POST /sesion/renovar. La renovación real la hace requireAuth; aquí solo se confirma. */
    renovarSesion(req, res) {
        res.status(200).json({ ok: true });
    }
};

module.exports = authController;
