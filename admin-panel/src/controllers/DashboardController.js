const dashboardService = require('../services/DashboardService');
const reporteService = require('../services/ReporteService');

const dashboardController = {
    async renderDashboard(req, res) {
        try {
            const [data, resumen] = await Promise.all([
                dashboardService.getDashboardKpis(),
                reporteService.reciclajePorMunicipio({}).catch(() => null)
            ]);
            res.render('dashboard', {
                activeTab: 'dashboard',
                titulo: 'Inicio',
                kpis: data.kpis,
                pendientesAccion: data.pendientesAccion,
                chartData: data.chartData,
                gestoresPendientes: data.gestoresPendientes,
                ultimasSolicitudes: data.ultimasSolicitudes,
                erroresCarga: data.errores,
                resumenReciclaje: resumen,
                errorCarga: null
            });
        } catch (err) {
            console.error('Error al renderizar dashboard:', err);
            res.status(500).render('dashboard', {
                activeTab: 'dashboard',
                titulo: 'Inicio',
                kpis: null,
                pendientesAccion: null,
                chartData: null,
                gestoresPendientes: [],
                ultimasSolicitudes: [],
                erroresCarga: [],
                resumenReciclaje: null,
                errorCarga: err.message
            });
        }
    }
};

module.exports = dashboardController;
