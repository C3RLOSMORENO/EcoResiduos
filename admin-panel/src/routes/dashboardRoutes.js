// Ruta de /dashboard, la pantalla de inicio del panel.
const express = require('express');
const router = express.Router();
const dashboardController = require('../controllers/DashboardController');

router.get('/', dashboardController.renderDashboard);

module.exports = router;
