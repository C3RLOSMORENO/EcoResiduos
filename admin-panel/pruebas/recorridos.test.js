const test = require('node:test');
const assert = require('node:assert/strict');
const { instalarSupabaseFalso } = require('./apoyo/supabaseFalso');
const { responderConDatos } = require('./apoyo/datos');
const { TOKEN_CSRF, COOKIE_CSRF } = require('./apoyo/csrf');

const supabase = instalarSupabaseFalso();
const request = require('supertest');
const app = require('../src/crearApp')();
const dashboardService = require('../src/services/DashboardService');
const { RECORRIDOS, LARGO_TITULO, LARGO_TEXTO, claveMetadatos } = require('../src/utils/recorridos');

const SESION = 'sb_access_token=token-admin';
const CON_CSRF = `${SESION}; ${COOKIE_CSRF}`;

test.beforeEach(() => {
    supabase.limpiar();
    supabase.manejador = responderConDatos;
});

function datosRecorrido(html) {
    const bloque = html.match(/<script type="application\/json" id="datosRecorrido">([\s\S]*?)<\/script>/);
    return bloque ? JSON.parse(bloque[1]) : null;
}

function guardar(cuerpo, pantalla = 'dashboard') {
    return request(app).post(`/recorridos/${pantalla}`).set('Cookie', CON_CSRF)
        .set('X-CSRF-Token', TOKEN_CSRF).set('X-Requested-With', 'fetch').send(cuerpo);
}

test('los textos del recorrido son cortos y cada paso entró en una versión que existe', () => {
    for (const [pantalla, recorrido] of Object.entries(RECORRIDOS)) {
        assert.ok(recorrido.pasos.length <= 4, `${pantalla}: más de 4 pasos`);
        recorrido.pasos.forEach((paso) => {
            assert.ok(paso.titulo.length <= LARGO_TITULO, `${pantalla}: título largo: ${paso.titulo}`);
            assert.ok(paso.texto.length <= LARGO_TEXTO, `${pantalla}: texto largo: ${paso.texto}`);
            assert.ok(Number.isInteger(paso.desde) && paso.desde >= 1 && paso.desde <= recorrido.version, `${pantalla}: «desde» fuera de rango`);
            assert.ok(!/haz clic|click/i.test(paso.texto), `${pantalla}: el texto describe el clic, no el beneficio`);
        });
    }
});

test('el inicio trae el recorrido, su botón de ayuda y cada elemento al que apunta', async () => {
    const html = (await request(app).get('/dashboard').set('Cookie', SESION)).text;
    const datos = datosRecorrido(html);
    assert.ok(datos, 'falta #datosRecorrido');
    assert.equal(datos.pantalla, 'dashboard');
    assert.equal(datos.vista, 0, 'un administrador nuevo no ha visto nada');
    assert.equal(datos.usuario, 'admin-1');

    // Oculto hasta que recorrido.js lo active: sin JavaScript no serviría.
    assert.match(html, /<button type="button" id="botonRecorrido" class="btn-icono" aria-label="Ver recorrido de esta pantalla"[^>]*hidden>/);
    datos.pasos.forEach((paso) => {
        const atributo = paso.elemento.match(/^\[data-recorrido="([a-z-]+)"\]$/);
        const id = paso.elemento.match(/^#([A-Za-z]+)$/);
        assert.ok(atributo || id, `selector no soportado: ${paso.elemento}`);
        const marca = atributo ? `data-recorrido="${atributo[1]}"` : `id="${id[1]}"`;
        assert.ok(html.includes(marca), `el paso «${paso.titulo}» apunta a ${paso.elemento}, que no está en la página`);
    });

    // Driver.js y el recorrido se piden con versión, después de los datos.
    assert.match(html, /id="datosRecorrido">[\s\S]*<script src="\/vendor\/driver\.js\?v=[0-9a-f]{12}" defer><\/script>\s*<script src="\/js\/recorrido\.js\?v=[0-9a-f]{12}" defer><\/script>/);
    const libreria = await request(app).get('/vendor/driver.js');
    assert.equal(libreria.status, 200);
    assert.match(libreria.headers['content-type'], /javascript/);
});

test('si el inicio no carga, no se ofrece el recorrido', async (t) => {
    const original = dashboardService.getDashboardKpis;
    const errorOriginal = console.error;
    t.after(() => { dashboardService.getDashboardKpis = original; console.error = errorOriginal; });
    dashboardService.getDashboardKpis = async () => { throw new Error('No pudimos cargar las cifras.'); };
    console.error = () => {};

    const html = (await request(app).get('/dashboard').set('Cookie', SESION)).text;
    assert.match(html, /No pudimos cargar el inicio/);
    assert.equal(datosRecorrido(html), null);
    assert.ok(!html.includes('botonRecorrido'));
    assert.ok(!html.includes('/vendor/driver.js'));
});

test('las demás pantallas no tienen botón de recorrido', async () => {
    const html = (await request(app).get('/solicitudes').set('Cookie', SESION)).text;
    assert.ok(!html.includes('botonRecorrido'));
    assert.ok(!html.includes('datosRecorrido'));
});

test('al terminar se guarda en la cuenta y la página siguiente ya lo sabe', async () => {
    const res = await guardar({ version: 1, estado: 'completado', paso: 4 });
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, { ok: true });

    const [op] = supabase.authOps;
    assert.equal(op.id, 'admin-1');
    const guardado = op.atributos.user_metadata[claveMetadatos('dashboard')];
    assert.equal(guardado.version, 1);
    assert.equal(guardado.estado, 'completado');
    assert.equal(guardado.paso, 4);
    assert.ok(!Number.isNaN(Date.parse(guardado.fecha)));

    const html = (await request(app).get('/dashboard').set('Cookie', SESION)).text;
    assert.equal(datosRecorrido(html).vista, 1);
});

test('guardar una pantalla no borra lo guardado de otra', async () => {
    supabase.metadatos['admin-1'] = { recorrido_panel_otra: { version: 3 }, nombre: 'Ana' };
    await guardar({ version: 1, estado: 'omitido', paso: 1 });
    assert.deepEqual(Object.keys(supabase.metadatos['admin-1']).sort(), ['nombre', 'recorrido_panel_dashboard', 'recorrido_panel_otra']);
});

test('lo que no cuadra con la definición del recorrido se rechaza sin tocar la cuenta', async () => {
    const version = RECORRIDOS.dashboard.version;
    const pasos = RECORRIDOS.dashboard.pasos.length;
    const invalidos = [
        { version: version + 1, estado: 'completado', paso: 1 },
        { version: 0, estado: 'completado', paso: 1 },
        { version: '1; drop', estado: 'completado', paso: 1 },
        { version: 1, estado: 'borrado', paso: 1 },
        { version: 1, estado: 'completado', paso: pasos + 1 },
        { version: 1, estado: 'completado', paso: -1 },
        { version: 1, estado: 'completado' }
    ];
    for (const cuerpo of invalidos) {
        const res = await guardar(cuerpo);
        assert.equal(res.status, 400, JSON.stringify(cuerpo));
    }
    for (const pantalla of ['inventada', '__proto__', 'constructor']) {
        assert.equal((await guardar({ version: 1, estado: 'visto', paso: 0 }, pantalla)).status, 404, pantalla);
    }
    assert.equal(supabase.authOps.length, 0);
});

test('guardar el recorrido exige sesión y token CSRF', async () => {
    const sinSesion = await request(app).post('/recorridos/dashboard').set('Cookie', COOKIE_CSRF).set('X-CSRF-Token', TOKEN_CSRF)
        .set('X-Requested-With', 'fetch').send({ version: 1, estado: 'visto', paso: 0 });
    assert.equal(sinSesion.status, 401);
    const sinToken = await request(app).post('/recorridos/dashboard').set('Cookie', CON_CSRF).set('X-Requested-With', 'fetch')
        .send({ version: 1, estado: 'visto', paso: 0 });
    assert.equal(sinToken.status, 403);
    assert.equal(supabase.authOps.length, 0);
});

test('si Supabase no guarda, responde 503 sin detalles técnicos', async (t) => {
    const original = supabase.auth.admin.updateUserById;
    const errorOriginal = console.error;
    t.after(() => { supabase.auth.admin.updateUserById = original; console.error = errorOriginal; });
    supabase.auth.admin.updateUserById = async () => ({ data: null, error: { message: 'User not found (gotrue 404)' } });
    console.error = () => {};

    const res = await guardar({ version: 1, estado: 'visto', paso: 0 });
    assert.equal(res.status, 503);
    assert.equal(res.body.ok, false);
    assert.ok(!JSON.stringify(res.body).includes('gotrue'));
});
