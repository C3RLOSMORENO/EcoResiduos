const test = require('node:test');
const assert = require('node:assert/strict');
const { instalarSupabaseFalso } = require('./apoyo/supabaseFalso');
const { responderConDatos } = require('./apoyo/datos');

process.env.SUPABASE_URL = 'https://proyecto.supabase.co';
const supabase = instalarSupabaseFalso();
const geocodificador = require('../src/services/geocodificador');
geocodificador.geocodificar = async () => null;

const request = require('supertest');
const app = require('../src/crearApp')();

const SESION = 'sb_access_token=token-admin';
const PANTALLAS = ['/login', '/restablecer-password', '/dashboard', '/solicitudes', '/solicitudes/7', '/gestores/1', '/reportes', '/componentes'];

test.beforeEach(() => {
    supabase.limpiar();
    supabase.manejador = responderConDatos;
});

test('cada respuesta lleva la CSP y las cabeceras de seguridad', async () => {
    const res = await request(app).get('/login');
    const csp = res.headers['content-security-policy'];
    assert.ok(csp, 'falta Content-Security-Policy');
    assert.match(csp, /default-src 'self'/);
    assert.match(csp, /script-src 'self' 'nonce-[A-Za-z0-9+/=]{20,}'(;|$)/);
    assert.ok(!csp.includes('unsafe-inline') && !csp.includes('unsafe-eval'), 'la CSP no puede permitir unsafe-inline ni unsafe-eval');
    assert.match(csp, /img-src 'self' data: https:\/\/proyecto\.supabase\.co/);
    assert.match(csp, /frame-ancestors 'none'/);
    assert.match(csp, /form-action 'self'/);
    assert.match(csp, /object-src 'none'/);
    assert.equal(res.headers['x-content-type-options'], 'nosniff');
    assert.equal(res.headers['x-frame-options'], 'DENY');
    assert.match(res.headers['permissions-policy'], /camera=\(\)/);
    assert.equal(res.headers['cross-origin-opener-policy'], 'same-origin');
    assert.equal(res.headers['strict-transport-security'], undefined, 'HSTS solo en producción');
});

test('el nonce cambia en cada respuesta y es el mismo de la CSP', async () => {
    const a = await request(app).get('/login');
    const b = await request(app).get('/login');
    const nonceA = a.headers['content-security-policy'].match(/'nonce-([^']+)'/)[1];
    const nonceB = b.headers['content-security-policy'].match(/'nonce-([^']+)'/)[1];
    assert.notEqual(nonceA, nonceB);
    assert.ok(a.text.includes(`<script nonce="${nonceA}">`), 'el script de tema no lleva el nonce de la CSP');
});

test('en producción se envía HSTS', async () => {
    const anterior = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    try {
        const res = await request(app).get('/login');
        assert.match(res.headers['strict-transport-security'], /max-age=31536000/);
        assert.match(res.headers['content-security-policy'], /upgrade-insecure-requests/);
    } finally {
        process.env.NODE_ENV = anterior;
    }
});

test('ninguna pantalla tiene JavaScript ni estilos escritos dentro del HTML', async () => {
    for (const ruta of PANTALLAS) {
        const publica = ['/login', '/restablecer-password'].includes(ruta);
        const res = await request(app).get(ruta).set('Cookie', publica ? '' : SESION);
        assert.equal(res.status, 200, ruta);
        const html = res.text;
        assert.ok(!/\son[a-z]+\s*=\s*["']/i.test(html), `${ruta} tiene un manejador on*="" en línea`);
        assert.ok(!/\sstyle\s*=\s*["']/i.test(html), `${ruta} tiene un atributo style="" en línea`);
        const scripts = html.match(/<script\b[^>]*>/g) || [];
        scripts.forEach((etiqueta) => {
            const permitido = /\bsrc="\/(js|vendor)\//.test(etiqueta) || /type="application\/json"/.test(etiqueta) || /\bnonce="/.test(etiqueta);
            assert.ok(permitido, `${ruta}: script no permitido por la CSP: ${etiqueta}`);
        });
        assert.ok(!/<script[^>]+src="https?:/.test(html), `${ruta} carga un script de otro dominio`);
    }
});

test('las librerías de terceros se sirven desde el panel', async () => {
    for (const ruta of ['/vendor/chart.umd.js', '/vendor/supabase.js']) {
        const res = await request(app).get(ruta);
        assert.equal(res.status, 200, ruta);
        assert.match(res.headers['content-type'], /javascript/, ruta);
    }
});

// ---------- CSRF ----------
const { TOKEN_CSRF, COOKIE_CSRF } = require('./apoyo/csrf');
const { conAviso } = require('../src/utils/web');
const CON_CSRF = `${SESION}; ${COOKIE_CSRF}`;

test('un POST sin token, con token distinto o desde otro sitio se rechaza con 403', async () => {
    const casos = [
        ['sin token', (r) => r.set('Cookie', CON_CSRF)],
        ['token distinto', (r) => r.set('Cookie', CON_CSRF).set('X-CSRF-Token', 'otro-token')],
        ['sin cookie csrf', (r) => r.set('Cookie', SESION).set('X-CSRF-Token', TOKEN_CSRF)],
        ['Origin de otro sitio', (r) => r.set('Cookie', CON_CSRF).set('X-CSRF-Token', TOKEN_CSRF).set('Origin', 'https://atacante.example')],
        ['Sec-Fetch-Site cross-site', (r) => r.set('Cookie', CON_CSRF).set('X-CSRF-Token', TOKEN_CSRF).set('Sec-Fetch-Site', 'cross-site')]
    ];
    for (const [nombre, preparar] of casos) {
        const res = await preparar(request(app).post('/autoridades/delete/5')).type('form').send({});
        assert.equal(res.status, 403, nombre);
        assert.match(res.text, /No pudimos confirmar el envío/, nombre);
    }
    assert.ok(!supabase.consultas.some((c) => c.accion === 'delete'), 'ningún intento rechazado debe llegar a la base');
});

test('un POST del propio panel con el token pasa, por campo de formulario o por cabecera', async () => {
    const porCampo = await request(app).post('/autoridades/delete/5').set('Cookie', CON_CSRF)
        .set('Host', 'panel.test').set('Origin', 'https://panel.test').type('form').send({ _csrf: TOKEN_CSRF });
    assert.equal(porCampo.status, 302);
    const porCabecera = await request(app).post('/sesion/renovar').set('Cookie', CON_CSRF)
        .set('X-CSRF-Token', TOKEN_CSRF).set('Sec-Fetch-Site', 'same-origin').set('X-Requested-With', 'fetch');
    assert.equal(porCabecera.status, 200);
    const fetchRechazado = await request(app).post('/sesion/renovar').set('Cookie', CON_CSRF).set('X-Requested-With', 'fetch');
    assert.equal(fetchRechazado.status, 403);
    assert.equal(fetchRechazado.body.ok, false);
});

test('la cookie csrf es httpOnly y SameSite=Strict, y todo formulario POST lleva el token', async () => {
    const nueva = await request(app).get('/login');
    const cookie = nueva.headers['set-cookie'].find((c) => c.startsWith('csrf='));
    assert.match(cookie, /HttpOnly/);
    assert.match(cookie, /SameSite=Strict/);
    const token = cookie.split(';')[0].slice('csrf='.length);
    assert.ok(nueva.text.includes(`name="_csrf" value="${token}"`), 'el login no lleva el token');

    for (const ruta of ['/dashboard', '/solicitudes?problema=1', '/solicitudes/7', '/gestores/1', '/gestores/edit/1', '/materiales/edit/2', '/autoridades/edit/5']) {
        const res = await request(app).get(ruta).set('Cookie', CON_CSRF);
        const formularios = res.text.match(/<form\b[\s\S]*?<\/form>/g) || [];
        const post = formularios.filter((f) => /\bmethod="POST"/i.test(f));
        assert.ok(post.length > 0, `${ruta} no tiene formularios POST`);
        post.forEach((f) => assert.ok(f.includes(`name="_csrf" value="${TOKEN_CSRF}"`), `${ruta}: formulario sin token: ${f.slice(0, 120)}`));
        assert.ok(res.text.includes(`<meta name="csrf-token" content="${TOKEN_CSRF}">`), `${ruta}: falta la meta del token`);
    }
});

// ---------- Cierre de sesión e inicio de sesión ----------
test('GET /logout no cierra la sesión', async () => {
    const res = await request(app).get('/logout').set('Cookie', CON_CSRF);
    assert.equal(res.headers.location, '/');
    assert.ok(!(res.headers['set-cookie'] || []).some((c) => /^sb_(access|refresh)_token=;/.test(c)));
});

test('el login se bloquea tras 5 intentos fallidos con el mismo correo', async () => {
    const intentar = (password) => request(app).post('/login').set('Cookie', COOKIE_CSRF).set('X-CSRF-Token', TOKEN_CSRF)
        .type('form').send({ email: 'Bloqueo@EcoResiduos.test', password });
    for (let i = 1; i <= 5; i++) {
        const res = await intentar(`mala-${i}`);
        assert.match(decodeURIComponent(res.headers.location), /Correo o contraseña incorrectos/, `intento ${i}`);
    }
    const sexto = await intentar('mala-6');
    assert.match(decodeURIComponent(sexto.headers.location), /demasiados intentos seguidos\. Espera 15 minutos/);
    // Sigue bloqueado aunque ahora la contraseña sea la correcta.
    const correcta = await intentar('clave-correcta');
    assert.match(decodeURIComponent(correcta.headers.location), /demasiados intentos/);
    assert.ok(!(correcta.headers['set-cookie'] || []).some((c) => c.startsWith('sb_access_token=token')));
});

test('una cuenta de la app con la contraseña correcta recibe el mismo mensaje que una contraseña errada', async () => {
    supabase.manejador = (consulta) => (consulta.tabla === 'usuarios' ? { data: { rol: 'GENERADOR' } } : responderConDatos(consulta));
    const res = await request(app).post('/login').set('Cookie', COOKIE_CSRF).set('X-CSRF-Token', TOKEN_CSRF)
        .type('form').send({ email: 'admin@ecoresiduos.test', password: 'clave-correcta' });
    assert.match(decodeURIComponent(res.headers.location), /Correo o contraseña incorrectos\./);
    assert.ok(!decodeURIComponent(res.headers.location).includes('permisos'));
});

// ---------- Avisos en la URL ----------
test('un aviso escrito a mano en la URL no se muestra; uno firmado por el servidor sí', async () => {
    const falso = await request(app).get('/login?msg=Tu%20cuenta%20fue%20bloqueada.%20Llama%20al%20300%20000%200000&type=error');
    assert.ok(!falso.text.includes('Tu cuenta fue bloqueada'));
    const firmaAjena = await request(app).get('/login?msg=Hola&type=error&firma=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
    assert.ok(!firmaAjena.text.includes('>Hola<'));
    const cambiado = conAviso('/login', 'Cerraste sesión.').replace('type=success', 'type=error');
    assert.ok(!(await request(app).get(cambiado)).text.includes('Cerraste sesión.'), 'cambiar el tipo invalida la firma');
    const valido = await request(app).get(conAviso('/login', 'Cerraste sesión.'));
    assert.ok(valido.text.includes('Cerraste sesión.'));
    for (const viejo of ['/login?success=Listo', '/login?error=Fallo%20inventado']) {
        const res = await request(app).get(viejo);
        assert.ok(!/Listo|Fallo inventado/.test(res.text), `${viejo} ya no debe mostrarse`);
    }
});

// ---------- Entradas y errores ----------
test('un identificador que no es un entero positivo responde 404 sin consultar la base', async () => {
    const rutas = [
        ['get', '/materiales/edit/abc'], ['get', '/autoridades/edit/-1'], ['get', '/gestores/edit/1e5'],
        ['get', '/gestores/x/permiso'], ['get', '/materiales/editar/0'], ['get', '/autoridades/edit/9999999999999999999'],
        ['post', '/autoridades/delete/abc'], ['post', '/materiales/edit/1;drop'], ['post', '/solicitudes/abc/estado']
    ];
    for (const [metodo, ruta] of rutas) {
        supabase.consultas.length = 0;
        let peticion = request(app)[metodo](ruta).set('Cookie', CON_CSRF);
        if (metodo === 'post') peticion = peticion.set('X-CSRF-Token', TOKEN_CSRF).type('form').send({});
        const res = await peticion;
        assert.equal(res.status, 404, ruta);
        assert.ok(!supabase.consultas.some((c) => c.tabla !== 'usuarios'), `${ruta} llegó a la base`);
    }
});

test('un error de la base no muestra el texto de PostgreSQL; un mensaje propio de una función sí', async () => {
    supabase.manejador = (consulta) => (consulta.tabla === 'autoridades_ambientales' && consulta.modo === 'lista'
        ? { data: null, error: { code: '42P01', message: 'relation "public.autoridades_ambientales" does not exist' } }
        : responderConDatos(consulta));
    const original = console.error;
    const registro = [];
    console.error = (...args) => registro.push(args.join(' '));
    try {
        const res = await request(app).get('/autoridades').set('Cookie', CON_CSRF);
        assert.ok(!res.text.includes('relation'), 'la pantalla muestra el error de PostgreSQL');
        assert.ok(!res.text.includes('42P01'));
        assert.match(res.text, /No pudimos cargar las autoridades\. Intenta de nuevo en unos minutos\./);
        assert.ok(registro.some((l) => l.includes('42P01')), 'el detalle debe quedar en el registro del servidor');
    } finally {
        console.error = original;
    }

    const { errorDeBase } = require('../src/utils/errores');
    console.error = () => {};
    try {
        assert.equal(errorDeBase('No pudimos cancelar la solicitud.', { code: 'P0001', message: 'La solicitud ya fue confirmada previamente.' }).message,
            'La solicitud ya fue confirmada previamente.');
        assert.equal(errorDeBase('No pudimos guardar el material.', { code: '23505', message: 'duplicate key value violates unique constraint "materiales_codigo_key"' }).message,
            'No pudimos guardar el material. Ya existe un registro con esos datos (por ejemplo, el mismo código o NIT).');
    } finally {
        console.error = original;
    }
});

test('los avisos que arma el navegador usan códigos con texto fijo', async () => {
    const vencida = await request(app).get('/login?aviso=sesion-vencida');
    assert.match(vencida.text, /Tu sesión venció por inactividad/);
    const clave = await request(app).get('/login?aviso=clave-actualizada');
    assert.match(clave.text, /Contraseña actualizada/);
    const inventado = await request(app).get('/login?aviso=lo-que-sea');
    assert.ok(!inventado.text.includes('lo-que-sea'));
});
