const dashboardService = require('../services/DashboardService');
const reporteService = require('../services/ReporteService');
const { renderLista } = require('../utils/errores');
const { datosRecorrido } = require('../utils/recorridos');
const { graficoEstados, graficoMunicipios } = require('../utils/graficos');

const dashboardController = {
    /** GET /dashboard: cifras, pendientes y gráficos del inicio. */
    renderDashboard(req, res) {
        return renderLista(res, 'dashboard', {
            comunes: { activeTab: 'dashboard', titulo: 'Inicio', recorrido: datosRecorrido('dashboard', req.user) },
            cargar: async () => {
                // Si el resumen de reciclaje falla, el resto del inicio se muestra igual.
                const [data, resumen] = await Promise.all([
                    dashboardService.getDashboardKpis(),
                    reporteService.reciclajePorMunicipio({}).catch(() => null)
                ]);
                return {
                    kpis: data.kpis,
                    pendientesAccion: data.pendientesAccion,
                    graficoEstados: graficoEstados(data.kpis),
                    graficoMunicipios: graficoMunicipios(data.chartData),
                    gestoresPendientes: data.gestoresPendientes,
                    ultimasSolicitudes: data.ultimasSolicitudes,
                    erroresCarga: data.errores,
                    resumenReciclaje: resumen
                };
            },
            vacio: {
                kpis: null,
                pendientesAccion: null,
                graficoEstados: null,
                graficoMunicipios: null,
                gestoresPendientes: [],
                ultimasSolicitudes: [],
                erroresCarga: [],
                resumenReciclaje: null
            }
        });
    }
};

module.exports = dashboardController;
