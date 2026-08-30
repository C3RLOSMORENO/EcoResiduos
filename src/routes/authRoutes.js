const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

/**
 * Rutas públicas de autenticación del sistema.
 */
router.get('/login', authController.renderLogin);
router.post('/login', authController.handleLogin);
router.post('/auth/login', authController.handleLogin);
router.get('/logout', authController.handleLogout);
router.post('/logout', authController.handleLogout);

module.exports = router;

