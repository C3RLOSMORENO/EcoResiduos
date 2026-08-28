const express = require('express');
const router = express.Router();
const autoridadController = require('../controllers/AutoridadController');

router.get('/', autoridadController.renderAutoridadesPage);
router.post('/', autoridadController.handleCreateAutoridad);
router.post('/delete/:id', autoridadController.handleDeleteAutoridad);

module.exports = router;