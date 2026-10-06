const express = require('express');
const router = express.Router();
const recorridoController = require('../controllers/RecorridoController');

router.post('/:pantalla', recorridoController.guardar);

module.exports = router;
