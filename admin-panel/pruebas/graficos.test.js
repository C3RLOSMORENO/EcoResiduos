// Reglas de los gráficos: el color sigue a la entidad, las barras van de
// mayor a menor con «Otro / sin dato» al final, y cada gráfico trae una frase
// con sus cifras.
const test = require('node:test');
const assert = require('node:assert/strict');
const { instalarSupabaseFalso } = require('./apoyo/supabaseFalso');

instalarSupabaseFalso();
const reporteService = require('../src/services/ReporteService');
const { formatoPorcentaje } = require('../src/utils/formato');
const g = require('../src/utils/graficos');

const solicitud = (municipio, categoria) => ({ municipio, cantidad_estimada: 1, unidad_medida: 'KG', materiales_residuos: { categoria } });

test('el porcentaje lleva coma decimal y espacio antes del signo', () => {
    assert.equal(formatoPorcentaje(1, 3), '33,3 %');
    assert.equal(formatoPorcentaje(5, 5), '100 %');
    assert.equal(formatoPorcentaje(3, 0), '0 %');
});

test('cada categoría conserva su color aunque un filtro deje solo esa', () => {
    const todas = reporteService.agregar([solicitud('Girón', 'APROVECHABLE'), solicitud('Girón', 'RCD')], []);
    const soloRcd = reporteService.agregar([solicitud('Girón', 'RCD')], []);
    const colorRcd = (r) => g.graficoReporte(r).datos.series.find((s) => s.nombre === 'Escombros (RCD)').color;
    assert.equal(colorRcd(todas), '--eco-graf-4');
    assert.equal(colorRcd(soloRcd), '--eco-graf-4');
    assert.equal(g.graficoReporte(soloRcd).datos.tipo, 'barras', 'una sola serie no se apila');
    assert.equal(g.graficoReporte(todas).datos.tipo, 'apiladas');
});

test('«Sin categoría» va en gris y las categorías fuera del catálogo no repiten color', () => {
    const ranuras = g.ranurasCategorias([
        { clave: 'APROVECHABLE' }, { clave: 'ORGANICO' }, { clave: 'SIN_CATEGORIA' }, { clave: 'ORDINARIO' }
    ]);
    assert.deepEqual(ranuras, { APROVECHABLE: '1', ORGANICO: '6', SIN_CATEGORIA: 'neutro', ORDINARIO: '7' });
});

test('el reporte ordena los municipios de mayor a menor con «Otro» al final y lo resume con cifras', () => {
    const reporte = reporteService.agregar([
        solicitud('Girón', 'RCD'), solicitud('Girón', 'RCD'), solicitud('Bucaramanga', 'RAEE'),
        solicitud('Lebrija', 'RAEE'), solicitud('Lebrija', 'RAEE'), solicitud('Lebrija', 'RAEE')
    ], []);
    const grafico = g.graficoReporte(reporte);
    assert.equal(grafico.datos.etiquetas[0], 'Girón');
    assert.equal(grafico.datos.etiquetas.at(-1), 'Otro / sin dato');
    assert.match(grafico.resumen, /^Girón encabeza con 2 recolecciones \(33,3 % de 6\); 2 municipios registran/);
    const cifras = g.cifrasReporte(reporte);
    assert.equal(cifras.lider.nombre, 'Girón');
    assert.deepEqual(cifras.categoria, { nombre: 'RAEE', valor: 4, proporcion: '66,7 %' });
});

test('el estado de las solicitudes es una barra de proporción con su porcentaje', () => {
    const grafico = g.graficoEstados({ solicitudesPublicadas: 6, solicitudesEnProceso: 2, solicitudesRecolectadas: 2, solicitudesCanceladas: 0 });
    assert.equal(grafico.datos.tipo, 'proporcion');
    assert.equal(grafico.total, 10);
    assert.equal(grafico.series[0].proporcion, '60 %');
    assert.equal(grafico.resumen, '10 solicitudes en total; 60 % están publicadas.');
    assert.equal(g.graficoEstados({}).total, 0);
});

test('las solicitudes por municipio van en el color de la marca, de mayor a menor', () => {
    const grafico = g.graficoMunicipios({ municipiosLabels: ['Bucaramanga', 'Girón', 'Otro / sin dato'], municipiosData: [1, 4, 9] });
    assert.deepEqual(grafico.datos.etiquetas, ['Girón', 'Bucaramanga', 'Otro / sin dato']);
    assert.equal(grafico.datos.series[0].color, '--eco-graf-unica');
    assert.equal(grafico.resumen, 'Girón concentra 4 de las 14 solicitudes (28,6 %).');
});

test('«Otro / sin dato» nunca se presenta como el municipio líder', () => {
    const reporte = reporteService.agregar([solicitud('Lebrija', 'RAEE')], []);
    assert.equal(g.cifrasReporte(reporte).lider, null);
    assert.equal(g.graficoReporte(reporte).resumen, '1 recolección confirmada, de un municipio fuera de la zona de operación.');
});
