// Ruta de /asistente: la pregunta que manda el asistente flotante por fetch.
const express = require('express');
const router = express.Router();
const asistenteController = require('../controllers/AsistenteController');

router.post('/preguntar', asistenteController.preguntar);

module.exports = router;
