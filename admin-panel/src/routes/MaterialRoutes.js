// Rutas de /materiales: catálogo de residuos. /edit y /editar, y /delete y
// /eliminar, llevan al mismo manejador.
const express = require('express');
const { validarIds } = require('../middlewares/validarId');

const router = express.Router();
validarIds(router, 'id');
const materialController = require('../controllers/MaterialController');

router.get('/', materialController.renderMaterialesPage);
router.post('/', materialController.handleCreateMaterial);
router.post('/guardar', materialController.handleCreateMaterial);
router.get('/nuevo', materialController.renderNuevoMaterial);
router.get('/edit/:id', materialController.renderEditMaterial);
router.get('/editar/:id', materialController.renderEditMaterial);
router.post('/edit/:id', materialController.handleUpdateMaterial);
router.post('/editar/:id', materialController.handleUpdateMaterial);
router.post('/delete/:id', materialController.handleDeleteMaterial);
router.post('/eliminar/:id', materialController.handleDeleteMaterial);

module.exports = router;
