const test = require('node:test');
const assert = require('node:assert/strict');
const { instalarSupabaseFalso } = require('./apoyo/supabaseFalso');

instalarSupabaseFalso();
const ExcelJS = require('exceljs');
const { generarExcelReporte } = require('../src/utils/excel');
const { jsonParaScript, rutaInterna, textoBusqueda, paginacion } = require('../src/utils/web');
const { rangoBogota } = require('../src/utils/fechas');
const { municipioAdmitido, MUNICIPIOS } = require('../src/utils/municipios');
const f = require('../src/utils/formato');
const reporteService = require('../src/services/ReporteService');

test('el Excel escribe los textos como texto y nunca como fórmula', async () => {
    const fila = (municipio) => ({ municipio, porCategoria: { X: 1 }, confirmadas: 1, sinConfirmar: 0, porUnidad: { kg: 2.5 } });
    const reporte = {
        categorias: [{ clave: 'X', etiqueta: '+57 300' }],
        unidades: [{ clave: 'kg', etiqueta: '@cmd' }],
        filas: [fila('=SUMA(A1:A9)'), fila('-1')],
        total: fila('Total'),
        hayOtro: false
    };
    const libro = new ExcelJS.Workbook();
    await libro.xlsx.load(await generarExcelReporte(reporte, '=HYPERLINK("x")'));
    let celdas = 0;
    libro.eachSheet((hoja) => hoja.eachRow((r) => r.eachCell((celda) => {
        celdas += 1;
        assert.notEqual(celda.type, ExcelJS.ValueType.Formula, `${hoja.name}!${celda.address}`);
    })));
    assert.ok(celdas > 20);
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

test('dígito de verificación del NIT con NIT reales (algoritmo módulo 11 de la DIAN)', () => {
    const { digitoVerificacion, normalizarNit } = require('../src/utils/validacion');
    for (const [nit, dv] of [['890903938', 8], ['899999068', 1], ['800197268', 4], ['860034313', 7]]) {
        assert.equal(digitoVerificacion(nit), dv, nit);
    }
    assert.equal(normalizarNit('890.903.938-8'), '890903938');
    assert.equal(normalizarNit('890903938'), '890903938', 'sin dígito de verificación también vale');
    assert.throws(() => normalizarNit('890903938-7'), /no corresponde/);
    assert.throws(() => normalizarNit('1234567'), /entre 8 y 15/);
});

test('teléfonos colombianos: celular, fijo de 10 o de 7 dígitos, 01 8000 y extensión', () => {
    const { normalizarTelefono } = require('../src/utils/validacion');
    const validos = [
        ['300 123 4567', '3001234567'],
        ['+57 300-123-4567', '3001234567'],
        ['573001234567', '3001234567'],
        ['(607) 634 5678', '6076345678'],
        ['601 765 4321', '6017654321'],
        ['634 5678', '6076345678'],
        ['01 8000 123456', '018000123456'],
        ['607 6970000 ext 123', '6076970000 ext. 123'],
        ['6017654321 Extensión 45', '6017654321 ext. 45']
    ];
    for (const [entrada, guardado] of validos) assert.equal(normalizarTelefono(entrada), guardado, entrada);
    for (const malo of ['', 'abc', '12345', '2001234567', '30012345678', 'Sin registrar']) {
        assert.throws(() => normalizarTelefono(malo), /celular/, malo);
    }
});

test('el sitio web solo acepta http o https y completa el protocolo', () => {
    const { normalizarSitioWeb } = require('../src/utils/validacion');
    assert.equal(normalizarSitioWeb('www.cdmb.gov.co'), 'https://www.cdmb.gov.co');
    assert.equal(normalizarSitioWeb('http://cas.gov.co'), 'http://cas.gov.co');
    for (const malo of ['javascript:alert(1)', 'ftp://x.co', 'localhost', '', `https://${'a'.repeat(260)}.co`]) {
        assert.throws(() => normalizarSitioWeb(malo), /sitio web/, malo);
    }
});
