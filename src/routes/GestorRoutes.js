const express = require('express');
const router = express.Router();
const gestorController = require('../controllers/GestorController');

/**
 * Rutas para la administración de Gestores Ambientales.
 */
router.get('/', gestorController.renderGestoresPage);
router.post('/', gestorController.handleCreateGestor);
router.get('/edit/:id', gestorController.renderEditGestor);
router.post('/edit/:id', gestorController.handleUpdateGestor);
router.post('/delete/:id', gestorController.handleDeleteGestor);

module.exports = router;