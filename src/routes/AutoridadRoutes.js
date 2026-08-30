const express = require('express');
const router = express.Router();
const autoridadController = require('../controllers/AutoridadController');

/**
 * Rutas para la administración del Directorio de Autoridades Ambientales.
 */
router.get('/', autoridadController.renderAutoridadesPage);
router.post('/', autoridadController.handleCreateAutoridad);
router.get('/edit/:id', autoridadController.renderEditAutoridad);
router.post('/edit/:id', autoridadController.handleUpdateAutoridad);
router.post('/delete/:id', autoridadController.handleDeleteAutoridad);

module.exports = router;