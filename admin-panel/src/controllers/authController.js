const authService = require('../services/authService');
const { guardarSesion, limpiarSesion } = require('../utils/sesion');
const { rutaInterna, jsonParaScript } = require('../utils/web');

const INICIO = '/dashboard';

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
        const { email, password } = req.body;
        const volver = rutaInterna(req.body.volver, '');
        const conVolver = volver ? `&volver=${encodeURIComponent(volver)}` : '';

        try {
            if (!email || !password) {
                return res.redirect(`/login?msg=${encodeURIComponent('Escribe tu correo y tu contraseña')}&type=error${conVolver}`);
            }

            const { session } = await authService.login(email, password);

            if (session && session.access_token) {
                guardarSesion(res, { accessToken: session.access_token, refreshToken: session.refresh_token });
            }

            const destino = volver || INICIO;
            const separador = destino.includes('?') ? '&' : '?';
            res.redirect(`${destino}${separador}msg=${encodeURIComponent('Iniciaste sesión')}&type=success`);
        } catch (err) {
            res.redirect(`/login?msg=${encodeURIComponent(err.message)}&type=error${conVolver}`);
        }
    },

    async handleLogout(req, res) {
        const token = req.cookies && req.cookies.sb_access_token;
        limpiarSesion(res);
        try {
            await authService.logout(token);
            res.redirect('/login?msg=Sesi%C3%B3n+cerrada+correctamente&type=success');
        } catch (err) {
            res.redirect(`/login?msg=${encodeURIComponent(err.message)}&type=error`);
        }
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
