const dashboardService = require('../services/DashboardService');
const reporteService = require('../services/ReporteService');
const { renderLista } = require('../utils/errores');

const dashboardController = {
    renderDashboard(req, res) {
        return renderLista(res, 'dashboard', {
            comunes: { activeTab: 'dashboard', titulo: 'Inicio' },
            cargar: async () => {
                // Si el resumen de reciclaje falla, el resto del inicio se muestra igual.
                const [data, resumen] = await Promise.all([
                    dashboardService.getDashboardKpis(),
                    reporteService.reciclajePorMunicipio({}).catch(() => null)
                ]);
                return {
                    kpis: data.kpis,
                    pendientesAccion: data.pendientesAccion,
                    chartData: data.chartData,
                    gestoresPendientes: data.gestoresPendientes,
                    ultimasSolicitudes: data.ultimasSolicitudes,
                    erroresCarga: data.errores,
                    resumenReciclaje: resumen
                };
            },
            vacio: {
                kpis: null,
                pendientesAccion: null,
                chartData: null,
                gestoresPendientes: [],
                ultimasSolicitudes: [],
                erroresCarga: [],
                resumenReciclaje: null
            }
        });
    }
};

module.exports = dashboardController;
