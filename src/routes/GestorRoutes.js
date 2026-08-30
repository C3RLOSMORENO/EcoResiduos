const express = require('express');
const router = express.Router();
const gestorController = require('../controllers/GestorController');

router.get('/', gestorController.renderGestoresPage);
router.post('/', gestorController.handleCreateGestor);
router.post('/guardar', gestorController.handleCreateGestor);
router.get('/edit/:id', gestorController.renderEditGestor);
router.get('/editar/:id', gestorController.renderEditGestor);
router.post('/edit/:id', gestorController.handleUpdateGestor);
router.post('/editar/:id', gestorController.handleUpdateGestor);
router.post('/delete/:id', gestorController.handleDeleteGestor);
router.post('/eliminar/:id', gestorController.handleDeleteGestor);

module.exports = router;