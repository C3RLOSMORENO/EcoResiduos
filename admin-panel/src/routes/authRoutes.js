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
router.post('/sesion/renovar', requireAuth, authController.renovarSesion);

module.exports = router;
