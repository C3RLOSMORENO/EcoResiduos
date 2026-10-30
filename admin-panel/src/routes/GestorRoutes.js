// Rutas de /gestores: empresas gestoras, su verificación, sus materiales y su
// permiso ambiental. /edit y /editar, /delete y /eliminar, y /estado/:id y
// /:id/estado llevan al mismo manejador.
const express = require('express');
const { validarIds } = require('../middlewares/validarId');

const router = express.Router();
validarIds(router, 'id', 'materialId');
const gestorController = require('../controllers/GestorController');

// El PDF del permiso llega como cuerpo binario de máximo 4 MB, el límite de
// las funciones serverless (utils/archivos.js).
const cuerpoPdf = express.raw({ type: 'application/pdf', limit: '4mb' });
function errorCuerpoPdf(err, req, res, next) {
    if (err && err.type === 'entity.too.large') {
        req.errorPdf = 'El PDF supera los 4 MB. Comprímelo antes de subirlo.';
        return next();
    }
    return next(err);
}

router.get('/', gestorController.renderGestoresPage);
router.post('/', gestorController.handleCreateGestor);
router.post('/guardar', gestorController.handleCreateGestor);
router.get('/nuevo', gestorController.renderNuevoGestor);
router.get('/edit/:id', gestorController.renderEditGestor);
router.get('/editar/:id', gestorController.renderEditGestor);
router.post('/edit/:id', gestorController.handleUpdateGestor);
router.post('/editar/:id', gestorController.handleUpdateGestor);
router.post('/delete/:id', gestorController.handleDeleteGestor);
router.post('/eliminar/:id', gestorController.handleDeleteGestor);
router.get('/:id/permiso', gestorController.handleVerPermiso);
router.post('/:id(\\d+)/permiso', cuerpoPdf, errorCuerpoPdf, gestorController.handleSubirPermiso);
router.post('/estado/:id', gestorController.handleUpdateEstado);
router.post('/:id/estado', gestorController.handleUpdateEstado);
router.post('/:id(\\d+)/materiales/verificar-todos', gestorController.handleVerificarTodos);
router.post('/:id(\\d+)/materiales/:materialId(\\d+)/verificar', gestorController.handleVerificarMaterial);
router.post('/:id(\\d+)/materiales/:materialId(\\d+)/quitar', gestorController.handleQuitarMaterial);
router.post('/:id(\\d+)/imagenes/quitar', gestorController.handleQuitarImagen);
router.get('/:id(\\d+)', gestorController.renderDetalleGestor);

module.exports = router;
