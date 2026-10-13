// Rutas de /solicitudes. Desde el panel solo se cancela una solicitud o se
// resuelve un problema reportado; los demás estados los cambian el generador y
// el gestor en la app.
const express = require('express');
const { validarIds } = require('../middlewares/validarId');

const router = express.Router();
validarIds(router, 'id');
const SolicitudController = require('../controllers/SolicitudController');

router.get('/', SolicitudController.listarSolicitudes);
router.get('/:id(\\d+)/certificado', SolicitudController.verCertificado);
router.get('/:id(\\d+)', SolicitudController.verSolicitud);
router.post('/:id(\\d+)/cancelar', SolicitudController.cancelar);
router.post('/:id(\\d+)/problema/no-recogido', SolicitudController.resolverNoRecogido);
router.post('/:id/estado', SolicitudController.cambiarEstado);

module.exports = router;
