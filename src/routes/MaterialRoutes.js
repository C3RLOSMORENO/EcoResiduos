const express = require('express');
const router = express.Router();
const materialController = require('../controllers/MaterialController');

/**
 * Rutas para la administración del Catálogo Maestro de Residuos (RESPEL).
 */
router.get('/', materialController.renderMaterialesPage);
router.post('/', materialController.handleCreateMaterial);
router.get('/edit/:id', materialController.renderEditMaterial);
router.post('/edit/:id', materialController.handleUpdateMaterial);
router.post('/delete/:id', materialController.handleDeleteMaterial);

module.exports = router;