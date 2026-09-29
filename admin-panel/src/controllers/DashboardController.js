const dashboardService = require('../services/DashboardService');

const dashboardController = {
    async renderDashboard(req, res) {
        try {
            const data = await dashboardService.getDashboardKpis();
            res.render('dashboard', {
                activeTab: 'dashboard',
                kpis: data.kpis,
                chartData: data.chartData,
                gestoresPendientes: data.gestoresPendientes,
                ultimasSolicitudes: data.ultimasSolicitudes,
                feedback: req.query.msg ? { type: req.query.type || 'success', message: req.query.msg } : null
            });
        } catch (err) {
            console.error('Error al renderizar dashboard:', err);
            res.render('dashboard', {
                activeTab: 'dashboard',
                chartData: { municipiosLabels: [], municipiosData: [] },
                kpis: {
                    totalSolicitudes: 0,
                    solicitudesRecolectadas: 0,
                    solicitudesPublicadas: 0,
                    solicitudesEnProceso: 0,
                    solicitudesCanceladas: 0,
                    totalGestores: 0,
                    gestoresPendientesCount: 0,
                    gestoresAprobados: 0,
                    gestoresRechazados: 0,
                    totalMateriales: 0,
                    totalAutoridades: 0,
                    totalPostulaciones: 0
                },
                gestoresPendientes: [],
                ultimasSolicitudes: [],
                feedback: { type: 'error', message: 'No se pudieron cargar todas las estadÃ­sticas del panel: ' + err.message }
            });
        }
    }
};

module.exports = dashboardController;

