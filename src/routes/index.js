const express = require('express');
const router = express.Router();

const authRoutes = require('./authRoutes');
const gestorRoutes = require('./GestorRoutes');
const materialRoutes = require('./MaterialRoutes');
const autoridadRoutes = require('./AutoridadRoutes');
const { requireAuth } = require('../middlewares/authMiddleware');

router.use('/', authRoutes);

router.get('/', (req, res) => {
    const token = req.cookies ? req.cookies.sb_access_token : null;
    return token ? res.redirect('/gestores') : res.redirect('/login');
});

router.use('/gestores', requireAuth, gestorRoutes);
router.use('/materiales', requireAuth, materialRoutes);
router.use('/autoridades', requireAuth, autoridadRoutes);

router.use((req, res) => {
    res.redirect('/login');
});

module.exports = router;