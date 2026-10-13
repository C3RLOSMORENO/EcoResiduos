// Rutas de /ciudadanos: generadores registrados en la app (solo lectura).
const express = require('express');
const router = express.Router();
const GeneradorController = require('../controllers/GeneradorController');

router.get('/', GeneradorController.listarGeneradores);

module.exports = router;
