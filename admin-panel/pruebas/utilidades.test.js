const test = require('node:test');
const assert = require('node:assert/strict');
const { instalarSupabaseFalso } = require('./apoyo/supabaseFalso');

instalarSupabaseFalso();
const { celdaCsv, generarCsv } = require('../src/utils/csv');
const { jsonParaScript, rutaInterna, textoBusqueda, paginacion } = require('../src/utils/web');
const { rangoBogota } = require('../src/utils/fechas');
const { municipioAdmitido, MUNICIPIOS } = require('../src/utils/municipios');
const f = require('../src/utils/formato');
const reporteService = require('../src/services/ReporteService');

test('CSV protegido contra inyección de fórmulas', () => {
    assert.equal(celdaCsv('=SUMA(A1:A9)'), "'=SUMA(A1:A9)");
    assert.equal(celdaCsv('+57 300'), "'+57 300");
    assert.equal(celdaCsv('-1'), "'-1");
    assert.equal(celdaCsv('@cmd'), "'@cmd");
    assert.equal(celdaCsv('\tx'), "'\tx");
    assert.equal(celdaCsv('Girón; Santander'), '"Girón; Santander"');
    const csv = generarCsv([['Municipio', 'Total'], ['Girón', '12,5']]);
    assert.equal(csv.charCodeAt(0), 0xfeff, 'UTF-8 con BOM para Excel');
    assert.ok(csv.includes('Municipio;Total\r\nGirón;12,5'));
});

test('JSON seguro dentro de <script>', () => {
    const texto = jsonParaScript({ m: '</script><script>alert(1)</script>' });
    assert.ok(!texto.includes('<') && !texto.includes('>'));
    assert.deepEqual(JSON.parse(texto), { m: '</script><script>alert(1)</script>' });
});

test('solo se redirige a rutas internas', () => {
    assert.equal(rutaInterna('/gestores/1', '/x'), '/gestores/1');
    assert.equal(rutaInterna('//malo.test', '/x'), '/x');
    assert.equal(rutaInterna('https://malo.test', '/x'), '/x');
    assert.equal(rutaInterna('/\\malo.test', '/x'), '/x');
});

test('la búsqueda no puede alterar el filtro de PostgREST', () => {
    assert.equal(textoBusqueda('a,b).or(id.gt.0'), 'a b .or id.gt.0');
});

test('paginación de 25 conserva los filtros', () => {
    const p = paginacion({ total: 60, pagina: 2, ruta: '/gestores', query: { q: 'x', pagina: '2', msg: 'hola' } });
    assert.equal(p.totalPaginas, 3);
    assert.equal(p.desde, 26);
    assert.equal(p.hasta, 50);
    assert.equal(p.anterior, '/gestores?q=x');
    assert.equal(p.siguiente, '/gestores?q=x&pagina=3');
});

test('fechas en hora de Colombia: el 31 a las 8 p. m. sigue siendo del 31', () => {
    const r = rangoBogota('2026-08-01', '2026-08-31');
    assert.equal(r.gte, '2026-08-01T00:00:00-05:00');
    assert.equal(r.lt, '2026-09-01T00:00:00-05:00');
    assert.equal(f.fechaCorta('2026-09-01T01:00:00Z'), '31 ago 2026');
    assert.equal(rangoBogota('2026-02-30', 'hola').gte, null);
});

test('municipios normalizados contra la lista de la app', () => {
    assert.equal(MUNICIPIOS.length, 6);
    assert.equal(municipioAdmitido('GIRON'), 'Girón');
    assert.equal(municipioAdmitido('  sabana   de TORRES '), 'Sabana de Torres');
    assert.equal(municipioAdmitido('Lebrija'), null);
});

test('formatos iguales a los de la app', () => {
    assert.equal(f.formatoPesos(1250000), '$ 1.250.000');
    assert.equal(f.formatoCantidad(120, 'KG'), '120 kg');
    assert.equal(f.etiquetaEstado('EN_NEGOCIACION'), 'En negociación');
    assert.equal(f.etiquetaEstado('NO_SELECCIONADA'), 'Asignada a otro gestor');
    assert.equal(f.etiquetaCategoria('PELIGROSO'), 'Peligroso (RESPEL)');
    assert.equal(f.claseCategoria('RIESGO_BIOLOGICO'), 'riesgo-biologico');
    assert.equal(f.urlSegura('javascript:alert(1)'), null);
});

test('el reporte cuenta recolecciones por categoría y suma cantidades sin convertir unidades', () => {
    const fila = (municipio, cantidad, unidad, categoria) => ({ municipio, cantidad_estimada: cantidad, unidad_medida: unidad, materiales_residuos: { categoria } });
    const reporte = reporteService.agregar([
        fila('BUCARAMANGA', 100, 'KG', 'APROVECHABLE'),
        fila('Bucaramanga', 2, 'TON', 'PELIGROSO'),
        fila('Bucaramanga', 30, 'KG', 'PELIGROSO'),
        fila('GIRON', 5, 'UNIDADES', 'RAEE'),
        fila('GIRÓN', 10, 'LITROS', 'PELIGROSO'),
        fila('Lebrija', 50, 'KG', 'RCD'),
        fila(null, 1, 'M3', 'RIESGO_BIOLOGICO')
    ], [{ municipio: 'Piedecuesta' }, { municipio: 'piedecuesta' }]);

    const buc = reporte.filas.find((r) => r.municipio === 'Bucaramanga');
    assert.equal(buc.confirmadas, 3);
    assert.equal(buc.porCategoria.APROVECHABLE, 1);
    assert.equal(buc.porCategoria.PELIGROSO, 2);
    assert.equal(buc.porUnidad.KG, 130);
    assert.equal(buc.porUnidad.TON, 2, 'las toneladas quedan en toneladas');

    const giron = reporte.filas.find((r) => r.municipio === 'Girón');
    assert.equal(giron.porUnidad.LITROS, 10);
    assert.equal(giron.porUnidad.UNIDADES, 5);
    assert.equal(giron.porUnidad.KG, 0);

    assert.deepEqual(reporte.unidades.map((u) => u.etiqueta), ['kg', 't', 'unidades', 'L', 'm³'], 'solo las unidades que aparecen, con su etiqueta corta');
    assert.ok(reporte.filas.every((r) => !('totalKg' in r) && !('kg' in r)), 'ninguna cifra en kilogramos calculada');

    const otro = reporte.filas.find((r) => r.municipio === reporteService.OTRO);
    assert.equal(otro.confirmadas, 2);
    assert.equal(reporte.filas.find((r) => r.municipio === 'Piedecuesta').sinConfirmar, 2);
    assert.equal(reporte.total.confirmadas, 7);
    assert.equal(reporte.total.porCategoria.PELIGROSO, 3);
    assert.equal(reporte.total.porUnidad.KG, 180);
    assert.equal(reporte.total.sinConfirmar, 2);
    assert.equal(reporte.filas.length, 7, 'los 6 municipios más «Otro / sin dato»');
});
