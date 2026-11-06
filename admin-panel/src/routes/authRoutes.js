// Inicio y cierre de sesión, restablecimiento de contraseña, la página de
// correo verificado de la app y la renovación de la sesión. Son las únicas rutas que no exigen sesión, salvo /sesion/renovar.
const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { requireAuth } = require('../middlewares/authMiddleware');

router.get('/login', authController.renderLogin);
router.post('/login', authController.handleLogin);
router.post('/auth/login', authController.handleLogin);
router.get('/logout', authController.redirigirLogout);
router.post('/logout', authController.handleLogout);
router.get('/restablecer-password', authController.renderRestablecer);
router.get('/correo-verificado', authController.renderCorreoVerificado);
router.post('/sesion/renovar', requireAuth, authController.renovarSesion);

module.exports = router;
