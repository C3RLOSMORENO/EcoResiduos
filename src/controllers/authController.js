const supabase = require('../config/supabase');
const authService = require('../services/authService');

const authController = {
    async renderLogin(req, res) {
        const token = req.cookies && req.cookies.sb_access_token;

        // Si ya hay token válido, redirigimos directamente a gestores
        if (token) {
            try {
                const { data, error } = await supabase.auth.getUser(token);
                if (!error && data && data.user) {
                    return res.redirect('/gestores');
                }
                res.clearCookie('sb_access_token');
            } catch {
                res.clearCookie('sb_access_token');
            }
        }

        const feedback = req.query.msg
            ? { type: req.query.type || 'error', message: req.query.msg }
            : null;

        res.render('login', {
            feedback
        });
    },

    async handleLogin(req, res) {
        const { email, password } = req.body;

        try {
            if (!email || !password) {
                return res.redirect('/login?msg=Por+favor+ingrese+correo+y+contrase%C3%B1a&type=error');
            }

            const { session } = await authService.login(email, password);

            if (session && session.access_token) {
                // httpOnly impide leer la cookie con JS (XSS) y maxAge expira la sesión a los 15 min
                res.cookie('sb_access_token', session.access_token, {
                    httpOnly: true,
                    secure: process.env.NODE_ENV === 'production',
                    sameSite: 'lax',
                    path: '/',
                    maxAge: 15 * 60 * 1000
                });
            }

            res.redirect('/gestores?msg=Inicio+de+sesi%C3%B3n+exitoso&type=success');
        } catch (err) {
            res.redirect(`/login?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    },

    async handleLogout(req, res) {
        try {
            res.clearCookie('sb_access_token');
            await authService.logout();
            res.redirect('/login?msg=Sesi%C3%B3n+cerrada+correctamente&type=success');
        } catch (err) {
            res.clearCookie('sb_access_token');
            res.redirect(`/login?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    }
};

module.exports = authController;


