const reporteService = require('../services/ReporteService');
const { generarCsv } = require('../utils/csv');
const { etiquetaCategoria, formatoNumero, fechaIsoBogota, fechaHora } = require('../utils/formato');

function descripcionFiltros(filtros) {
    return [
        filtros.desde ? `Confirmadas desde ${filtros.desde}` : 'Desde el inicio',
        filtros.hasta ? `hasta ${filtros.hasta}` : 'hasta hoy',
        filtros.categoria ? `Categoría: ${etiquetaCategoria(filtros.categoria)}` : 'Todas las categorías'
    ].join(' · ');
}

// Cifras con coma decimal, como las lee Excel en español de Colombia.
const cifra = (valor) => formatoNumero(valor, 2).replace(/\./g, '');

exports.verReporte = async (req, res) => {
    const filtros = reporteService.leerFiltros(req.query);
    try {
        const reporte = await reporteService.reciclajePorMunicipio(filtros);
        res.render('reportes', {
            titulo: 'Reportes',
            activeTab: 'reportes',
            filtros,
            reporte,
            descripcion: descripcionFiltros(filtros),
            generado: fechaHora(new Date()),
            errorCarga: null
        });
    } catch (err) {
        res.status(500).render('reportes', {
            titulo: 'Reportes',
            activeTab: 'reportes',
            filtros,
            reporte: null,
            descripcion: descripcionFiltros(filtros),
            generado: fechaHora(new Date()),
            errorCarga: err.message
        });
    }
};

// Solo cifras agregadas: el CSV no lleva datos personales.
exports.descargarCsv = async (req, res) => {
    const filtros = reporteService.leerFiltros(req.query);
    try {
        const reporte = await reporteService.reciclajePorMunicipio(filtros);
        const filas = [
            ['Reciclaje por municipio · EcoResiduos'],
            [descripcionFiltros(filtros)],
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
        res.redirect(`/reportes?msg=${encodeURIComponent(`No pudimos generar el CSV: ${err.message}`)}&type=error`);
    }
};
