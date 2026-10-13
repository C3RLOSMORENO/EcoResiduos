const reporteService = require('../services/ReporteService');
const { generarExcelReporte } = require('../utils/excel');
const { graficoReporte, cifrasReporte } = require('../utils/graficos');
const { conAviso } = require('../utils/web');
const { fechaIsoBogota, fechaHora } = require('../utils/formato');
const { renderLista } = require('../utils/errores');
const { filtrosReporte, describirFiltrosReporte, enlaceExcelReporte } = require('../utils/filtros');

/** GET /reportes: reciclaje por municipio con sus filtros. */
exports.verReporte = (req, res) => {
    const filtros = filtrosReporte(req.query);
    return renderLista(res, 'reportes', {
        comunes: {
            titulo: 'Reportes',
            activeTab: 'reportes',
            filtros,
            descripcion: describirFiltrosReporte(filtros),
            enlaceExcel: enlaceExcelReporte(filtros),
            generado: fechaHora(new Date())
        },
        cargar: async () => {
            const reporte = await reporteService.reciclajePorMunicipio(filtros);
            return { reporte, grafico: graficoReporte(reporte), cifras: cifrasReporte(reporte) };
        },
        vacio: { reporte: null, grafico: null, cifras: null }
    });
};

/** GET /reportes/excel: el mismo reporte en un archivo .xlsx. */
exports.descargarExcel = async (req, res) => {
    const filtros = filtrosReporte(req.query);
    try {
        const reporte = await reporteService.reciclajePorMunicipio(filtros);
        const archivo = await generarExcelReporte(reporte, describirFiltrosReporte(filtros));
        res.set({
            'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'Content-Disposition': `attachment; filename="reciclaje-por-municipio-${fechaIsoBogota()}.xlsx"`,
            'Cache-Control': 'no-store'
        });
        res.send(archivo);
    } catch (err) {
        console.error('Reporte Excel:', err.message);
        res.redirect(conAviso('/reportes', 'No pudimos generar el Excel. Intenta de nuevo en unos minutos.', 'error'));
    }
};
