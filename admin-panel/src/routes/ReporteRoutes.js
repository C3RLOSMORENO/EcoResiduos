// Rutas de /reportes: reciclaje por municipio en pantalla y en Excel.
const express = require('express');
const router = express.Router();
const ReporteController = require('../controllers/ReporteController');

router.get('/', ReporteController.verReporte);
router.get('/excel', ReporteController.descargarExcel);

module.exports = router;
