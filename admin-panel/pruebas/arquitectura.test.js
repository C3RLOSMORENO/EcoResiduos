const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const filtros = require('../src/utils/filtros');
const { revisarEntorno } = require('../src/config/entorno');

const RAIZ = path.join(__dirname, '..');
const leer = (relativa) => fs.readFileSync(path.join(RAIZ, relativa), 'utf8');

test('los filtros de la URL se validan: lo que no está en la lista se ignora', () => {
    const solicitudes = filtros.filtrosSolicitudes({ estado: 'publicado', municipio: 'giron', categoria: 'inventada', generador: '-3', orden: 'raro', problema: '1' });
    assert.equal(solicitudes.estado, 'PUBLICADO');
    assert.equal(solicitudes.municipio, 'Girón');
    assert.equal(solicitudes.categoria, '');
    assert.equal(solicitudes.generador, '');
    assert.equal(solicitudes.orden, '-fecha');
    assert.equal(solicitudes.problema, '1');

    assert.deepEqual(filtros.filtrosGestores({ estado: 'aprobado', orden: '-razon', por_verificar: '1', q: '  Eco  ' }),
        { q: 'Eco', municipio: '', estado: 'APROBADO', porVerificar: '1', orden: '-razon' });
    assert.equal(filtros.filtrosGestores({ estado: 'BORRADO' }).estado, '');
    assert.deepEqual(filtros.filtrosMateriales({ categoria: 'raee', orden: 'precio' }), { q: '', categoria: 'RAEE', orden: 'codigo' });
    assert.deepEqual(filtros.filtrosCiudadanos({ municipio: 'Medellín' }), { q: '', municipio: '' });
});

test('la descripción de los filtros de solicitudes queda vacía si no hay ninguno', () => {
    assert.equal(filtros.describirFiltrosSolicitudes(filtros.filtrosSolicitudes({})), '');
    assert.equal(filtros.describirFiltrosSolicitudes(filtros.filtrosSolicitudes({ orden: 'fecha' })), '', 'el orden no es un filtro');
    assert.equal(filtros.describirFiltrosSolicitudes(filtros.filtrosSolicitudes({ estado: 'RECOLECTADO', municipio: 'Girón', desde: '2026-09-01' })),
        'Recolectado · Girón · desde 1 sep 2026');
});

test('el enlace del Excel lleva los mismos filtros que el reporte en pantalla', () => {
    assert.equal(filtros.enlaceExcelReporte(filtros.filtrosReporte({})), '/reportes/excel');
    assert.equal(filtros.enlaceExcelReporte(filtros.filtrosReporte({ desde: '2026-01-01', categoria: 'rcd', otro: 'x' })),
        '/reportes/excel?desde=2026-01-01&categoria=RCD');
});

test('al arrancar se dice qué variable falta y qué conviene corregir en producción', () => {
    const completo = { SUPABASE_URL: 'https://p.supabase.co', SUPABASE_ANON_KEY: 'a', SUPABASE_SERVICE_ROLE_KEY: 's' };
    assert.deepEqual(revisarEntorno(completo), { faltan: [], avisos: [] });

    const { faltan } = revisarEntorno({ SUPABASE_URL: 'proyecto', SUPABASE_ANON_KEY: '  ' });
    assert.equal(faltan.length, 3);
    assert.match(faltan.join('\n'), /SUPABASE_ANON_KEY/);
    assert.match(faltan.join('\n'), /SUPABASE_SERVICE_ROLE_KEY/);
    assert.match(faltan.join('\n'), /no es una dirección web/);

    const { avisos } = revisarEntorno({ ...completo, NODE_ENV: 'production' });
    assert.equal(avisos.length, 2);
    assert.match(avisos[0], /SECRETO_PANEL/);
    assert.deepEqual(revisarEntorno({ ...completo, NODE_ENV: 'production', SECRETO_PANEL: 'x', TRUST_PROXY: '1' }).avisos, []);
});

test('capas: los controladores no hablan con Supabase y las vistas no calculan filtros', () => {
    const controladores = fs.readdirSync(path.join(RAIZ, 'src/controllers'));
    controladores.forEach((archivo) => {
        const codigo = leer(`src/controllers/${archivo}`);
        assert.ok(!/config\/supabase|\.from\(/.test(codigo), `${archivo} consulta Supabase directamente`);
    });
    ['solicitudes', 'reportes', 'gestor-detalle', 'gestor-edit'].forEach((vista) => {
        const codigo = leer(`src/views/${vista}.ejs`);
        assert.ok(!/URLSearchParams|normalize\('NFD'\)|7\.119349/.test(codigo), `${vista}.ejs calcula lo que le toca al controlador`);
    });
});

test('npm start arranca server.js y existe el script dev que cita la documentación', () => {
    const paquete = JSON.parse(leer('package.json'));
    assert.equal(paquete.scripts.start, 'node server.js');
    assert.ok(paquete.scripts.dev, 'falta npm run dev');
    assert.ok(paquete.scripts.lint, 'falta npm run lint');
    assert.ok(fs.existsSync(path.join(RAIZ, 'server.js')));
});
