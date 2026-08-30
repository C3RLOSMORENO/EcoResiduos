const express = require('express');
const router = express.Router();
const materialController = require('../controllers/MaterialController');

router.get('/', materialController.renderMaterialesPage);
router.post('/', materialController.handleCreateMaterial);
router.post('/guardar', materialController.handleCreateMaterial);
router.get('/edit/:id', materialController.renderEditMaterial);
router.get('/editar/:id', materialController.renderEditMaterial);
router.post('/edit/:id', materialController.handleUpdateMaterial);
router.post('/editar/:id', materialController.handleUpdateMaterial);
router.post('/delete/:id', materialController.handleDeleteMaterial);
router.post('/eliminar/:id', materialController.handleDeleteMaterial);

module.exports = router;