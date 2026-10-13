// Rutas de /autoridades: autoridades ambientales que la app muestra a los
// ciudadanos. /edit y /editar, y /delete y /eliminar, llevan al mismo manejador.
const express = require('express');
const { validarIds } = require('../middlewares/validarId');

const router = express.Router();
validarIds(router, 'id');
const autoridadController = require('../controllers/AutoridadController');

router.get('/', autoridadController.renderAutoridadesPage);
router.post('/', autoridadController.handleCreateAutoridad);
router.post('/guardar', autoridadController.handleCreateAutoridad);
router.get('/nuevo', autoridadController.renderNuevaAutoridad);
router.get('/edit/:id', autoridadController.renderEditAutoridad);
router.get('/editar/:id', autoridadController.renderEditAutoridad);
router.post('/edit/:id', autoridadController.handleUpdateAutoridad);
router.post('/editar/:id', autoridadController.handleUpdateAutoridad);
router.post('/delete/:id', autoridadController.handleDeleteAutoridad);
router.post('/eliminar/:id', autoridadController.handleDeleteAutoridad);

module.exports = router;
