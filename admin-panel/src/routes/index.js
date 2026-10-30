// Une las rutas del panel. Todo lo que no es inicio de sesión pasa por
// requireAuth, que exige una sesión de administrador.
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
const recorridoRoutes = require('./RecorridoRoutes');
const asistenteRoutes = require('./AsistenteRoutes');
const { requireAuth } = require('../middlewares/authMiddleware');
const politicaDatos = require('../utils/politicaDatos');

router.use('/', authRoutes);
// Pública: debe poder leerse sin iniciar sesión.
router.get('/accesibilidad', (req, res) => res.render('accesibilidad'));
router.get('/privacidad', (req, res) => res.render('privacidad', { politica: politicaDatos }));

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
router.use('/recorridos', requireAuth, recorridoRoutes);
router.use('/asistente', requireAuth, asistenteRoutes);
router.get('/componentes', requireAuth, (req, res) => {
    res.render('componentes', { titulo: 'Componentes', activeTab: '' });
});

module.exports = router;
