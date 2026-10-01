const express = require('express');
const router = express.Router();

const authRoutes = require('./authRoutes');
const dashboardRoutes = require('./dashboardRoutes');
const gestorRoutes = require('./GestorRoutes');
const materialRoutes = require('./MaterialRoutes');
const autoridadRoutes = require('./AutoridadRoutes');
const solicitudRoutes = require('./SolicitudRoutes');
const generadorRoutes = require('./GeneradorRoutes');
const reporteRoutes = require('./ReporteRoutes');
const { requireAuth } = require('../middlewares/authMiddleware');

router.use('/', authRoutes);

router.get('/', (req, res) => {
    const conSesion = req.cookies && (req.cookies.sb_access_token || req.cookies.sb_refresh_token);
    return conSesion ? res.redirect('/dashboard') : res.redirect('/login');
});

router.use('/dashboard', requireAuth, dashboardRoutes);
router.use('/gestores', requireAuth, gestorRoutes);
router.use('/materiales', requireAuth, materialRoutes);
router.use('/autoridades', requireAuth, autoridadRoutes);
router.use('/solicitudes', requireAuth, solicitudRoutes);
router.use('/ciudadanos', requireAuth, generadorRoutes);
router.use('/reportes', requireAuth, reporteRoutes);
router.get('/componentes', requireAuth, (req, res) => {
    res.render('componentes', { titulo: 'Componentes', activeTab: '' });
});

module.exports = router;
