const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const http = require('http');
const path = require('path');
const { instalarSupabaseFalso } = require('./apoyo/supabaseFalso');
const { responderConDatos } = require('./apoyo/datos');

const supabase = instalarSupabaseFalso();
const request = require('supertest');
const app = require('../src/crearApp')();
const { ICONOS } = require('../src/utils/iconos');
const { fetchConLimite } = require('../src/utils/tiempoLimite');

const SESION = 'sb_access_token=token-admin';
const RAIZ = path.join(__dirname, '..', 'src');

test.beforeEach(() => {
    supabase.limpiar();
    supabase.manejador = responderConDatos;
});

test('los estáticos con versión se guardan un año; sin versión se revalidan', async () => {
    const html = (await request(app).get('/dashboard').set('Cookie', SESION)).text;
    const css = html.match(/href="(\/css\/style\.css\?v=[0-9a-f]{12})"/);
    const js = html.match(/src="(\/js\/main\.js\?v=[0-9a-f]{12})"/);
    const chart = html.match(/src="(\/vendor\/chart\.umd\.js\?v=[0-9a-f]{12})"/);
    assert.ok(css && js && chart, 'el inicio debe pedir los archivos con ?v=');

    for (const url of [css[1], js[1], chart[1]]) {
        const res = await request(app).get(url);
        assert.equal(res.status, 200, url);
        assert.equal(res.headers['cache-control'], 'public, max-age=31536000, s-maxage=31536000, immutable', url);
    }
    const sinVersion = await request(app).get('/css/style.css');
    assert.equal(sinVersion.headers['cache-control'], 'public, max-age=0, must-revalidate');
    assert.ok(sinVersion.headers.etag, 'sin versión se revalida con ETag');
});

test('HTML, CSS y JS viajan comprimidos', async () => {
    const html = await request(app).get('/dashboard').set('Cookie', SESION).set('Accept-Encoding', 'br, gzip');
    assert.equal(html.headers['content-encoding'], 'br');
    const css = await request(app).get('/css/style.css').set('Accept-Encoding', 'gzip');
    assert.equal(css.headers['content-encoding'], 'gzip');
});

// Nombres de ícono escritos en el código: el contenido de cada
// <span class="material-symbols-outlined"> (también dentro de <%= … %>), las
// propiedades icono: '…', las asignaciones icono.textContent y el mapa de
// íconos de formato.js.
function iconosEnElCodigo() {
    const archivos = [];
    (function recorrer(d) {
        for (const e of fs.readdirSync(d, { withFileTypes: true })) {
            const p = path.join(d, e.name);
            if (e.isDirectory()) { if (e.name !== 'css') recorrer(p); } else if (/\.(js|ejs)$/.test(e.name)) archivos.push(p);
        }
    })(RAIZ);
    const nombres = new Set();
    // 'undefined' sale de los typeof de EJS, no es un ícono.
    const comillas = (texto) => [...texto.matchAll(/'([a-z][a-z0-9_]*)'/g)].map((m) => m[1]).filter((n) => n !== 'undefined');
    for (const archivo of archivos) {
        const codigo = fs.readFileSync(archivo, 'utf8');
        // [^>\n]: la etiqueta cierra en la misma línea; en main.js la clase
        // también aparece en código (className = '…') y no es una etiqueta.
        for (const m of codigo.matchAll(/material-symbols-outlined[^>\n]*>((?:<%[\s\S]*?%>|[^<])*)</g)) {
            const contenido = m[1].trim();
            if (/^[a-z][a-z0-9_]*$/.test(contenido)) nombres.add(contenido);
            else comillas(contenido).forEach((n) => nombres.add(n));
        }
        for (const m of codigo.matchAll(/icono[A-Za-z]*:\s*'([a-z][a-z0-9_]*)'/g)) nombres.add(m[1]);
        for (const m of codigo.matchAll(/icono\.textContent\s*=\s*([^;]+);/g)) comillas(m[1]).forEach((n) => nombres.add(n));
        if (archivo.endsWith('formato.js')) {
            comillas(codigo.slice(codigo.indexOf('const ICONOS_ESTADO'), codigo.indexOf('function unidadCorta'))).forEach((n) => nombres.add(n));
        }
    }
    return nombres;
}

test('la fuente de íconos se pide solo con los íconos que usa el panel, y no falta ninguno', async () => {
    assert.deepEqual(ICONOS, [...ICONOS].sort(), 'Google Fonts exige la lista en orden alfabético');
    const faltan = [...iconosEnElCodigo()].filter((n) => !ICONOS.includes(n));
    assert.deepEqual(faltan, [], `agrega a src/utils/iconos.js: ${faltan.join(', ')}`);

    const html = (await request(app).get('/dashboard').set('Cookie', SESION)).text;
    assert.match(html, /family=Material\+Symbols\+Outlined[^"]*&amp;icon_names=accessibility_new,account_balance,add,[a-z_,]+&amp;display=block/);
    // Solo los pesos que se usan (medidos en todas las pantallas) y display=swap.
    assert.match(html, /family=Barlow\+Condensed:wght@600;700&family=Public\+Sans:wght@400;600;700&display=swap/);
});

test('si Supabase no responde, la consulta se corta a tiempo en lugar de dejar la página cargando', async () => {
    const colgado = http.createServer(() => { /* nunca responde */ });
    await new Promise((listo) => colgado.listen(0, listo));
    const { createClient } = require('@supabase/supabase-js');
    const cliente = createClient(`http://127.0.0.1:${colgado.address().port}`, 'llave', {
        auth: { persistSession: false, autoRefreshToken: false },
        global: { fetch: fetchConLimite(globalThis.fetch, { consultaMs: 300, archivoMs: 5000 }) }
    });
    const inicio = Date.now();
    const { data, error } = await cliente.from('solicitudes_recoleccion').select('id');
    const tardo = Date.now() - inicio;
    colgado.closeAllConnections();
    colgado.close();
    assert.equal(data, null);
    assert.ok(error, 'debe volver con un error');
    assert.ok(tardo < 3000, `tardó ${tardo} ms`);
});

test('una subida de archivo tiene más tiempo que una consulta', async () => {
    const senales = [];
    const fetchFalso = async (url, opciones) => { senales.push([url, opciones.signal]); return new Response('{}'); };
    const conLimite = fetchConLimite(fetchFalso, { consultaMs: 50, archivoMs: 5000 });
    await conLimite('https://p.supabase.co/rest/v1/materiales_residuos', {});
    await conLimite('https://p.supabase.co/storage/v1/object/permisos/1.pdf', { method: 'POST' });
    await new Promise((listo) => setTimeout(listo, 120));
    assert.equal(senales[0][1].aborted, true, 'la consulta ya venció');
    assert.equal(senales[1][1].aborted, false, 'la subida sigue a tiempo');
});

test('si Supabase Auth está caído, la sesión no se cierra y se ofrece reintentar', async (t) => {
    const original = supabase.auth.getUser;
    t.after(() => { supabase.auth.getUser = original; });
    supabase.auth.getUser = async () => ({ data: { user: null }, error: { name: 'AuthRetryableFetchError', status: 0, message: 'fetch failed' } });
    const errorOriginal = console.error;
    console.error = () => {};
    t.after(() => { console.error = errorOriginal; });

    const pagina = await request(app).get('/solicitudes?estado=PUBLICADO').set('Cookie', SESION);
    assert.equal(pagina.status, 503);
    assert.match(pagina.text, /<a href="\/solicitudes\?estado=PUBLICADO" class="btn-filled">Reintentar<\/a>/);
    const cookies = (pagina.headers['set-cookie'] || []).join(';');
    assert.ok(!/sb_access_token=;/.test(cookies), 'no debe borrar la sesión');

    const fetchRes = await request(app).get('/solicitudes').set('Cookie', SESION).set('X-Requested-With', 'fetch');
    assert.equal(fetchRes.status, 503);
    assert.equal(fetchRes.body.ok, false);
});

test('un token vencido sí lleva al inicio de sesión', async () => {
    const res = await request(app).get('/solicitudes').set('Cookie', 'sb_access_token=token-vencido');
    assert.equal(res.status, 302);
    assert.match(res.headers.location, /^\/login\?/);
});
