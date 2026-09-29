const express = require('express');
const router = express.Router();

const authRoutes = require('./authRoutes');
const dashboardRoutes = require('./dashboardRoutes');
const gestorRoutes = require('./GestorRoutes');
const materialRoutes = require('./MaterialRoutes');
const autoridadRoutes = require('./AutoridadRoutes');
const solicitudRoutes = require('./SolicitudRoutes');
const { requireAuth } = require('../middlewares/authMiddleware');

router.use('/', authRoutes);

router.get('/', (req, res) => {
    const token = req.cookies ? req.cookies.sb_access_token : null;
    return token ? res.redirect('/dashboard') : res.redirect('/login');
});

router.use('/dashboard', requireAuth, dashboardRoutes);
router.use('/gestores', requireAuth, gestorRoutes);
router.use('/materiales', requireAuth, materialRoutes);
router.use('/autoridades', requireAuth, autoridadRoutes);
router.use('/solicitudes', requireAuth, solicitudRoutes);

router.use((req, res) => {
    res.redirect('/login');
});

module.exports = router;
