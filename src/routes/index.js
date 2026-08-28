const express = require('express');
const router = express.Router();

const gestorRoutes = require('./GestorRoutes');
const materialRoutes = require('./MaterialRoutes');
const autoridadRoutes = require('./AutoridadRoutes');

router.get('/', (req, res) => res.redirect('/gestores'));
router.use('/gestores', gestorRoutes);
router.use('/materiales', materialRoutes);
router.use('/autoridades', autoridadRoutes);

module.exports = router;