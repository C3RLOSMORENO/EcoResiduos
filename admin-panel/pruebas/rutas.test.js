const test = require('node:test');
const assert = require('node:assert/strict');
const { instalarSupabaseFalso } = require('./apoyo/supabaseFalso');
const { responderConDatos, XSS } = require('./apoyo/datos');

const supabase = instalarSupabaseFalso();
const geocodificador = require('../src/services/geocodificador');
geocodificador.geocodificar = async () => null;

const request = require('supertest');
const app = require('../src/crearApp')();

const SESION = 'sb_access_token=token-admin';

// Rutas GET del inventario (sección 4) y las nuevas de la sección 6.
const RUTAS_GET = [
    '/dashboard',
    '/gestores',
    '/gestores?q=aceite&municipio=Gir%C3%B3n&estado=PENDIENTE&por_verificar=1&orden=-razon&pagina=2',
    '/gestores/nuevo',
    '/gestores/1',
    '/gestores/edit/1',
    '/gestores/editar/1',
    '/materiales',
    '/materiales?q=aceite&categoria=PELIGROSO&orden=-nombre',
    '/materiales/nuevo',
    '/materiales/edit/2',
    '/materiales/editar/2',
    '/autoridades',
    '/autoridades?q=cas',
    '/autoridades/nuevo',
    '/autoridades/edit/5',
    '/autoridades/editar/5',
    '/solicitudes',
    '/solicitudes?estado=PUBLICADO&municipio=Sabana%20de%20Torres&categoria=RAEE&desde=2026-09-01&hasta=2026-09-30&q=cel&problema=1&sin_certificado=1&generador=4&orden=fecha',
    '/solicitudes/7',
    '/ciudadanos',
    '/ciudadanos?q=laura&municipio=Bucaramanga',
    '/reportes',
    '/reportes?desde=2026-09-01&hasta=2026-09-30&categoria=PELIGROSO',
    '/componentes'
];

const RUTAS_POST = [
    '/gestores', '/gestores/guardar', '/gestores/edit/1', '/gestores/editar/1',
    '/gestores/delete/1', '/gestores/eliminar/1', '/gestores/estado/1', '/gestores/1/estado',
    '/gestores/1/permiso', '/gestores/1/materiales/2/verificar', '/gestores/1/materiales/2/quitar',
    '/gestores/1/materiales/verificar-todos',
    '/materiales', '/materiales/guardar', '/materiales/edit/2', '/materiales/editar/2',
    '/materiales/delete/2', '/materiales/eliminar/2',
    '/autoridades', '/autoridades/guardar', '/autoridades/edit/5', '/autoridades/editar/5',
    '/autoridades/delete/5', '/autoridades/eliminar/5',
    '/solicitudes/7/estado', '/solicitudes/7/cancelar', '/solicitudes/7/problema/no-recogido'
];

test.beforeEach(() => {
    supabase.limpiar();
    supabase.manejador = responderConDatos;
});

test('sin sesión, cada ruta GET protegida redirige a /login recordando la página', async () => {
    for (const ruta of [...RUTAS_GET, '/gestores/1/permiso', '/reportes/csv']) {
        const res = await request(app).get(ruta);
        assert.equal(res.status, 302, ruta);
        assert.match(res.headers.location, /^\/login\?/, ruta);
        assert.match(res.headers.location, /volver=/, ruta);
    }
});

test('sin sesión, cada ruta POST protegida redirige a /login', async () => {
    for (const ruta of RUTAS_POST) {
        const res = await request(app).post(ruta).type('form').send({});
        assert.equal(res.status, 302, ruta);
        assert.match(res.headers.location, /^\/login\?/, ruta);
    }
});

test('con sesión de administrador, cada pantalla responde 200 con un solo h1 y título propio', async () => {
    for (const ruta of RUTAS_GET) {
        const res = await request(app).get(ruta).set('Cookie', SESION);
        assert.equal(res.status, 200, `${ruta}: ${res.text.slice(0, 300)}`);
        assert.equal((res.text.match(/<h1[\s>]/g) || []).length, 1, `${ruta} debe tener un solo h1`);
        assert.match(res.text, /<html lang="es-CO">/, ruta);
        assert.match(res.text, /<title>[^<]+ · Panel EcoResiduos<\/title>/, ruta);
        assert.match(res.text, /class="saltar"/, ruta);
        assert.doesNotMatch(res.text, /cdn\.tailwindcss\.com/, ruta);
        assert.doesNotMatch(res.text, /padr[oó]n/i, ruta);
    }
});

test('la página actual queda marcada en la navegación con aria-current', async () => {
    const res = await request(app).get('/solicitudes').set('Cookie', SESION);
    assert.match(res.text, /href="\/solicitudes" class="nav-item" aria-current="page"/);
});

test('pantallas públicas: login, restablecer contraseña y 404', async () => {
    assert.equal((await request(app).get('/login')).status, 200);
    const restablecer = await request(app).get('/restablecer-password');
    assert.equal(restablecer.status, 200);
    assert.match(restablecer.text, /esm\.sh\/@supabase\/supabase-js@\d+\.\d+\.\d+/);
    const noExiste = await request(app).get('/no-existe');
    assert.equal(noExiste.status, 404);
    assert.match(noExiste.text, /Página no encontrada/);
});

test('cerrar sesión por GET y por POST limpia las cookies', async () => {
    for (const metodo of ['get', 'post']) {
        const res = await request(app)[metodo]('/logout').set('Cookie', SESION);
        assert.equal(res.status, 302);
        assert.match(res.headers.location, /^\/login/);
        assert.ok(res.headers['set-cookie'].some((c) => c.startsWith('sb_access_token=;')));
    }
});

test('iniciar sesión guarda el token y el refresh token y vuelve a la página pedida', async () => {
    for (const ruta of ['/login', '/auth/login']) {
        const res = await request(app).post(ruta).type('form')
            .send({ email: 'admin@ecoresiduos.test', password: 'clave-correcta', volver: '/gestores/1' });
        assert.equal(res.status, 302);
        assert.match(res.headers.location, /^\/gestores\/1\?msg=/);
        const cookies = res.headers['set-cookie'].join(';');
        assert.match(cookies, /sb_access_token=token-admin/);
        assert.match(cookies, /sb_refresh_token=refresco-1/);
    }
    const externo = await request(app).post('/login').type('form')
        .send({ email: 'admin@ecoresiduos.test', password: 'clave-correcta', volver: '//sitio-malo.test' });
    assert.match(externo.headers.location, /^\/dashboard/);
    const mala = await request(app).post('/login').type('form').send({ email: 'admin@ecoresiduos.test', password: 'mala' });
    assert.match(mala.headers.location, /^\/login\?msg=/);
});

test('con el token vencido, la sesión se renueva con el refresh token', async () => {
    const res = await request(app).get('/gestores').set('Cookie', 'sb_access_token=token-vencido; sb_refresh_token=refresco-valido');
    assert.equal(res.status, 200);
    const cookies = res.headers['set-cookie'].join(';');
    assert.match(cookies, /sb_access_token=token-admin/);
    assert.match(cookies, /sb_refresh_token=refresco-2/);
});

test('renovar la sesión desde el aviso responde JSON, y 401 si ya venció', async () => {
    const ok = await request(app).post('/sesion/renovar').set('Cookie', SESION).set('X-Requested-With', 'fetch');
    assert.equal(ok.status, 200);
    assert.equal(ok.body.ok, true);
    const vencida = await request(app).post('/sesion/renovar').set('X-Requested-With', 'fetch');
    assert.equal(vencida.status, 401);
});

test('ver permiso redirige al enlace firmado de 10 minutos', async () => {
    const res = await request(app).get('/gestores/1/permiso').set('Cookie', SESION);
    assert.equal(res.status, 302);
    assert.match(res.headers.location, /^https:\/\/almacenamiento\.test\/permisos\/registro\/abc\.pdf/);
    assert.deepEqual(supabase.storageOps.find((o) => o.op === 'firmar').segundos, 600);
});

test('los datos de la base no se imprimen sin escapar (XSS)', async () => {
    for (const ruta of ['/dashboard', '/solicitudes', '/solicitudes/7', '/reportes']) {
        const res = await request(app).get(ruta).set('Cookie', SESION);
        assert.ok(!res.text.includes(XSS), `${ruta} imprime el municipio sin escapar`);
        assert.ok(!res.text.includes('src="javascript:'), `${ruta} usa una URL javascript:`);
    }
    const dashboard = await request(app).get('/dashboard').set('Cookie', SESION);
    const json = dashboard.text.match(/<script type="application\/json" id="datosMunicipios">([\s\S]*?)<\/script>/);
    assert.ok(json, 'el dashboard pasa los datos del gráfico en un script JSON');
    assert.ok(!json[1].includes('<'), 'el JSON escapa «<»');
    assert.doesNotThrow(() => JSON.parse(json[1]));
});

test('las listas se paginan en el servidor con 25 filas y conteo exacto', async () => {
    await request(app).get('/gestores?pagina=3').set('Cookie', SESION);
    const consulta = supabase.consultas.find((c) => c.tabla === 'perfiles_gestor' && c.opciones.count === 'exact');
    assert.deepEqual(consulta.filtros.find((f) => f[0] === 'range').slice(1), [50, 74]);
});

test('el CSV del reporte tiene BOM, separador «;» y solo cifras agregadas', async () => {
    const res = await request(app).get('/reportes/csv?categoria=PELIGROSO').set('Cookie', SESION).buffer(true).parse((r, cb) => {
        let datos = '';
        r.setEncoding('utf8');
        r.on('data', (t) => { datos += t; });
        r.on('end', () => cb(null, datos));
    });
    assert.equal(res.status, 200);
    assert.match(res.headers['content-type'], /text\/csv/);
    assert.equal(res.body.charCodeAt(0), 0xfeff);
    assert.match(res.body, /Recolecciones confirmadas por municipio y categoría/);
    assert.match(res.body, /Municipio;Aprovechable;Peligroso \(RESPEL\);RAEE;Escombros \(RCD\);Riesgo biológico;Total confirmadas;Recolectadas sin confirmar/);
    assert.match(res.body, /Cantidades declaradas por unidad/);
    assert.match(res.body, /Municipio;kg\r\n/);
    assert.doesNotMatch(res.body, /\(kg\)|kilogramo|1\.000 kg/i);
    assert.doesNotMatch(res.body, /laura@correo\.test|1098000000/);
});

test('los avisos de ?msg, ?success y ?error se anuncian en regiones status o alert', async () => {
    const exito = await request(app).get('/gestores?msg=Gestor%20aprobado&type=success').set('Cookie', SESION);
    assert.match(exito.text, /role="status"[^>]*>\s*<div class="aviso" data-aviso>[\s\S]*?Gestor aprobado/);
    const success = await request(app).get('/solicitudes?success=Listo').set('Cookie', SESION);
    assert.match(success.text, /data-aviso>[\s\S]*?Listo/);
    const error = await request(app).get('/materiales?error=%3Cb%3EFall%C3%B3%3C%2Fb%3E').set('Cookie', SESION);
    assert.match(error.text, /role="alert"[\s\S]*?data-aviso-error[\s\S]*?&lt;b&gt;Falló&lt;\/b&gt;/);
});
