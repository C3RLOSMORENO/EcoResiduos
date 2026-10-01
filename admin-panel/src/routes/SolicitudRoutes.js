const express = require('express');
const router = express.Router();
const SolicitudController = require('../controllers/SolicitudController');

router.get('/', SolicitudController.listarSolicitudes);
router.get('/:id(\\d+)', SolicitudController.verSolicitud);
router.post('/:id(\\d+)/cancelar', SolicitudController.cancelar);
router.post('/:id(\\d+)/problema/no-recogido', SolicitudController.resolverNoRecogido);
router.post('/:id/estado', SolicitudController.cambiarEstado);

module.exports = router;
