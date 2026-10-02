const reporteService = require('../services/ReporteService');
const { generarCsv } = require('../utils/csv');
const { conAviso } = require('../utils/web');
const { formatoNumero, fechaIsoBogota, fechaHora } = require('../utils/formato');
const { renderLista } = require('../utils/errores');
const { filtrosReporte, describirFiltrosReporte, enlaceCsvReporte } = require('../utils/filtros');

// Cifras con coma decimal, como las lee Excel en español de Colombia.
const cifra = (valor) => formatoNumero(valor, 2).replace(/\./g, '');

exports.verReporte = (req, res) => {
    const filtros = filtrosReporte(req.query);
    return renderLista(res, 'reportes', {
        comunes: {
            titulo: 'Reportes',
            activeTab: 'reportes',
            filtros,
            descripcion: describirFiltrosReporte(filtros),
            enlaceCsv: enlaceCsvReporte(filtros),
            generado: fechaHora(new Date())
        },
        cargar: async () => ({ reporte: await reporteService.reciclajePorMunicipio(filtros) }),
        vacio: { reporte: null }
    });
};

// Solo cifras agregadas: el CSV no lleva datos personales.
exports.descargarCsv = async (req, res) => {
    const filtros = filtrosReporte(req.query);
    try {
        const reporte = await reporteService.reciclajePorMunicipio(filtros);
        const filas = [
            ['Reciclaje por municipio · EcoResiduos'],
            [describirFiltrosReporte(filtros)],
            [`Generado: ${fechaHora(new Date())} (hora de Colombia)`],
            [],
            ['Recolecciones confirmadas por municipio y categoría'],
            ['Municipio', ...reporte.categorias.map((c) => c.etiqueta), 'Total confirmadas', 'Recolectadas sin confirmar']
        ];
        [...reporte.filas, reporte.total].forEach((fila) => {
            filas.push([
                fila.municipio,
                ...reporte.categorias.map((c) => fila.porCategoria[c.clave]),
                fila.confirmadas,
                fila.sinConfirmar
            ]);
        });
        filas.push(
            [],
            ['Cantidades declaradas por unidad'],
            ['Cantidades estimadas por los generadores, en la unidad que cada uno declaró. No se convierten ni se suman entre unidades.']
        );
        if (reporte.unidades.length > 0) {
            filas.push(['Municipio', ...reporte.unidades.map((u) => u.etiqueta)]);
            [...reporte.filas, reporte.total].forEach((fila) => {
                filas.push([fila.municipio, ...reporte.unidades.map((u) => cifra(fila.porUnidad[u.clave]))]);
            });
        } else {
            filas.push(['Sin recolecciones confirmadas con estos filtros.']);
        }

        const nombre = `reciclaje-por-municipio-${fechaIsoBogota()}.csv`;
        res.set({
            'Content-Type': 'text/csv; charset=utf-8',
            'Content-Disposition': `attachment; filename="${nombre}"`,
            'Cache-Control': 'no-store'
        });
        res.send(generarCsv(filas));
    } catch (err) {
        console.error('Reporte CSV:', err.message);
        res.redirect(conAviso('/reportes', 'No pudimos generar el CSV. Intenta de nuevo en unos minutos.', 'error'));
    }
};
