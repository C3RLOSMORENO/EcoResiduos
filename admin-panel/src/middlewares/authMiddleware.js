const authService = require('../services/authService');

const authMiddleware = {
    async requireAuth(req, res, next) {
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
            const user = await authService.getAdmin(token);

            if (!user) {
                res.clearCookie('sb_access_token');
                return res.redirect('/login?msg=Sesi%C3%B3n+inv%C3%A1lida,+expirada+o+sin+permisos+de+administrador&type=error');
            }

            res.cookie('sb_access_token', token, {
                httpOnly: true,
                secure: process.env.NODE_ENV === 'production',
                sameSite: 'lax',
                path: '/',
                maxAge: 15 * 60 * 1000
            });

            req.user = user;
            res.locals.user = user;
            next();
        } catch {
            res.clearCookie('sb_access_token');
            return res.redirect('/login?msg=Error+de+autenticaci%C3%B3n.+Por+favor+inicia+sesi%C3%B3n&type=error');
        }
    }
};

module.exports = authMiddleware;
