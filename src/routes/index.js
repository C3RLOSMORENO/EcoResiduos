const express = require('express');
const router = express.Router();

const authRoutes = require('./authRoutes');
const gestorRoutes = require('./GestorRoutes');
const materialRoutes = require('./MaterialRoutes');
const autoridadRoutes = require('./AutoridadRoutes');
const { requireAuth } = require('../middlewares/authMiddleware');

/**
 * 1. Rutas Públicas:
 *    Autenticación (login, validación de credenciales y cierre de sesión).
 */
router.use('/', authRoutes);

/**
 * 2. Ruta Raíz ('/'):
 *    Si el usuario cuenta con token en cookie navega a '/gestores'; de lo contrario a '/login'.
 */
router.get('/', (req, res) => {
    const token = req.cookies ? req.cookies.sb_access_token : null;
    if (!token) {
        return res.redirect('/login');
    }
    return res.redirect('/gestores');
});

/**
 * 3. Rutas Privadas del Panel:
 *    Protegidas mediante 'requireAuth' (valida JWT y bloquea caché del navegador).
 */
router.use('/gestores', requireAuth, gestorRoutes);
router.use('/materiales', requireAuth, materialRoutes);
router.use('/autoridades', requireAuth, autoridadRoutes);

/**
 * 4. Fallback de rutas no reconocidas dentro del enrutador:
 *    Redirecciona de forma segura a '/login'.
 */
router.use((req, res) => {
    res.redirect('/login');
});

module.exports = router;