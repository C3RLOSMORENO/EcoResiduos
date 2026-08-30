const supabase = require('../config/supabase');

const authMiddleware = {
    async requireAuth(req, res, next) {
        // Evitamos que el navegador guarde la página en caché para que no se vea tras cerrar sesión
        res.set({
            'Cache-Control': 'no-store, no-cache, must-revalidate, private',
            'Pragma': 'no-cache',
            'Expires': '0'
        });

        const token = req.cookies && req.cookies.sb_access_token;

        if (!token) {
            return res.redirect('/login?msg=Debes+iniciar+sesi%C3%B3n+para+continuar&type=error');
        }

        try {
            const { data, error } = await supabase.auth.getUser(token);

            if (error || !data || !data.user) {
                res.clearCookie('sb_access_token');
                return res.redirect('/login?msg=Sesi%C3%B3n+inv%C3%A1lida+o+expirada.+Por+favor+inicia+sesi%C3%B3n&type=error');
            }

            // Renovar cookie para mantener los 15 minutos de inactividad mientras el usuario interactúa
            res.cookie('sb_access_token', token, {
                httpOnly: true,
                secure: process.env.NODE_ENV === 'production',
                sameSite: 'lax',
                path: '/',
                maxAge: 15 * 60 * 1000
            });

            req.user = data.user;
            res.locals.user = data.user;
            next();
        } catch {
            res.clearCookie('sb_access_token');
            return res.redirect('/login?msg=Error+de+autenticaci%C3%B3n.+Por+favor+inicia+sesi%C3%B3n&type=error');
        }
    }
};

module.exports = authMiddleware;


