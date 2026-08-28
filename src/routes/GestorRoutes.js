const express = require('express');
const router = express.Router();
const gestorController = require('../controllers/GestorController');

router.get('/', gestorController.renderGestoresPage);
router.post('/', gestorController.handleCreateGestor);
router.post('/delete/:id', gestorController.handleDeleteGestor);

module.exports = router;