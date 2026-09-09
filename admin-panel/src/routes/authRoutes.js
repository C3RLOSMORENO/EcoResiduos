const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

router.get('/login', authController.renderLogin);
router.post('/login', authController.handleLogin);
router.post('/auth/login', authController.handleLogin);
router.get('/logout', authController.handleLogout);
router.post('/logout', authController.handleLogout);

router.get('/restablecer-password', (req, res) => {
    res.render('restablecer-password', {
        supabaseUrl: process.env.SUPABASE_URL,
        supabaseAnonKey: process.env.SUPABASE_ANON_KEY
    });
});

module.exports = router;
