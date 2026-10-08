process.env.SUPABASE_URL = 'https://proyecto.supabase.co';

const test = require('node:test');
const assert = require('node:assert/strict');
const { instalarSupabaseFalso } = require('./apoyo/supabaseFalso');
const datos = require('./apoyo/datos');
const { TOKEN_CSRF, COOKIE_CSRF } = require('./apoyo/csrf');

const supabase = instalarSupabaseFalso();
require('../src/services/geocodificador').geocodificar = async () => null;
const request = require('supertest');
const app = require('../src/crearApp')();
const { urlFotoPerfil } = require('../src/utils/fotosPerfil');
const { iniciales } = require('../src/utils/formato');

const SESION = 'sb_access_token=token-admin';
const CUENTA = '7d5c2a3e-1f4b-4c8d-9e6a-2b3c4d5e6f70';
const LOGO = `${CUENTA}/perfil/1.png`;
const PORTADA = `${CUENTA}/portada/2.jpg`;
const URL_LOGO = `https://proyecto.supabase.co/storage/v1/object/public/fotos_perfil/${LOGO}`;
const COLUMNA_NO_EXISTE = { code: '42703', message: 'column perfiles_gestor.foto_perfil_path does not exist' };

const conFotos = { ...datos.gestor, usuario_id: CUENTA, foto_perfil_path: LOGO, portada_path: PORTADA };

function manejadorConFotos(c) {
    if (c.tabla === 'perfiles_gestor' && c.accion === 'select') {
        return c.modo === 'lista' ? { data: [conFotos], count: 1 } : { data: conFotos };
    }
    return datos.responderConDatos(c);
}

test.beforeEach(() => {
    supabase.limpiar();
    supabase.manejador = manejadorConFotos;
});

test('solo una ruta con la forma del bucket se convierte en URL', () => {
    assert.equal(urlFotoPerfil(LOGO), URL_LOGO);
    assert.equal(urlFotoPerfil(PORTADA), `https://proyecto.supabase.co/storage/v1/object/public/fotos_perfil/${PORTADA}`);
    for (const mala of [null, '', 'registro/abc.pdf', `${CUENTA}/perfil/1.svg`, `${CUENTA}/../permisos/1.png`,
        `"><script>alert(1)</script>`, `https://otro.sitio/${LOGO}`, `${CUENTA}/perfil/1.png?x=1`]) {
        assert.equal(urlFotoPerfil(mala), null, String(mala));
    }
});

test('las iniciales del panel son las mismas que muestra la app', () => {
    assert.equal(iniciales('RECICLAJES DEL ORIENTE S.A.S.'), 'RO');
    assert.equal(iniciales('Ecológica de Santander'), 'ES');
    assert.equal(iniciales('Recimetal'), 'R');
    assert.equal(iniciales(''), 'E');
});

test('la lista, la ficha y el inicio muestran el logo con las iniciales debajo, sin anunciarlo', async () => {
    for (const ruta of ['/gestores', '/gestores/1', '/dashboard']) {
        const html = (await request(app).get(ruta).set('Cookie', SESION)).text;
        const avatar = html.match(/<span class="avatar avatar-(sm|md|lg)" aria-hidden="true">\s*<span>RO<\/span>\s*<img src="([^"]+)" alt=""[^>]*data-avatar>/);
        assert.ok(avatar, `${ruta}: falta el avatar con logo`);
        assert.equal(avatar[2], URL_LOGO, ruta);
    }
});

test('sin logo ni portada se ven las iniciales y la ficha no ofrece quitar nada', async () => {
    supabase.manejador = datos.responderConDatos;
    const html = (await request(app).get('/gestores/1').set('Cookie', SESION)).text;
    assert.match(html, /<span class="avatar avatar-lg" aria-hidden="true">\s*<span>RO<\/span>\s*<\/span>/);
    assert.ok(!html.includes('data-avatar'));
    assert.ok(!html.includes('Logo y portada'));
});

test('la ficha ofrece quitar el logo y la portada, con confirmación', async () => {
    const html = (await request(app).get('/gestores/1').set('Cookie', SESION)).text;
    for (const [valor, texto] of [['perfil', 'Quitar logo'], ['portada', 'Quitar portada']]) {
        const formulario = html.match(new RegExp(`<form action="/gestores/1/imagenes/quitar" method="POST"[^>]*data-confirmar-titulo="${texto}"[^>]*data-confirmar-peligro>[\\s\\S]*?name="imagen" value="${valor}"`));
        assert.ok(formulario, `falta el formulario «${texto}»`);
    }
});

test('quitar el logo lo borra del perfil, del bucket y de la cuenta del gestor', async () => {
    const res = await request(app).post('/gestores/1/imagenes/quitar').set('Cookie', `${SESION}; ${COOKIE_CSRF}`)
        .set('X-CSRF-Token', TOKEN_CSRF).type('form').send({ imagen: 'perfil' });
    assert.equal(res.status, 302);
    assert.match(decodeURIComponent(res.headers.location), /Logo quitado/);

    const actualizacion = supabase.consultas.find((c) => c.tabla === 'perfiles_gestor' && c.accion === 'update');
    assert.deepEqual(actualizacion.payload, { foto_perfil_path: null });
    assert.deepEqual(supabase.storageOps.find((o) => o.op === 'borrar'), { bucket: 'fotos_perfil', op: 'borrar', rutas: [LOGO] });
    assert.deepEqual(supabase.authOps[0], { op: 'actualizar', id: CUENTA, atributos: { user_metadata: { foto_perfil_path: null } } });
});

test('una imagen que no existe o que el gestor no tiene se rechaza sin tocar nada', async () => {
    const enviar = (cuerpo) => request(app).post('/gestores/1/imagenes/quitar').set('Cookie', `${SESION}; ${COOKIE_CSRF}`)
        .set('X-CSRF-Token', TOKEN_CSRF).type('form').send(cuerpo);
    for (const imagen of ['otra', 'usuario_id', '', 'constructor', '__proto__', 'toString']) {
        const res = await enviar({ imagen });
        assert.match(decodeURIComponent(res.headers.location), /type=error/, imagen);
    }
    supabase.manejador = datos.responderConDatos;
    const sinLogo = await enviar({ imagen: 'perfil' });
    assert.match(decodeURIComponent(sinLogo.headers.location), /El gestor no tiene logo/);
    assert.ok(!supabase.consultas.some((c) => c.accion === 'update'));
    assert.equal(supabase.storageOps.length, 0);
});

test('si la migración aún no corre, el inicio y la solicitud funcionan con iniciales', async (t) => {
    const errorOriginal = console.error;
    t.after(() => { console.error = errorOriginal; });
    console.error = () => {};
    supabase.manejador = (c) => (/foto_perfil_path/.test(c.columnas || '') ? { data: null, error: COLUMNA_NO_EXISTE } : datos.responderConDatos(c));

    for (const ruta of ['/dashboard', '/solicitudes/7']) {
        const res = await request(app).get(ruta).set('Cookie', SESION);
        assert.equal(res.status, 200, ruta);
        assert.ok(!res.text.includes('data-avatar'), ruta);
    }
    const reintentos = supabase.consultas.filter((c) => c.tabla === 'perfiles_gestor' && !/foto_perfil_path/.test(c.columnas || ''));
    assert.ok(reintentos.length > 0, 'debe repetir la consulta sin la columna');
});
