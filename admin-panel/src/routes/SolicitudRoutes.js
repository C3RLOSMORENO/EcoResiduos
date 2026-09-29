const express = require('express');
const router = express.Router();
const SolicitudController = require('../controllers/SolicitudController');

router.get('/', SolicitudController.listarSolicitudes);
router.post('/:id/estado', SolicitudController.cambiarEstado);

module.exports = router;
