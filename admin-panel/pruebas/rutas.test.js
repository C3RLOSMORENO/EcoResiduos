const test = require('node:test');
const assert = require('node:assert/strict');
const { instalarSupabaseFalso } = require('./apoyo/supabaseFalso');
const { responderConDatos, XSS, solicitud } = require('./apoyo/datos');

const supabase = instalarSupabaseFalso();
const geocodificador = require('../src/services/geocodificador');
geocodificador.geocodificar = async () => null;

const request = require('supertest');
const ExcelJS = require('exceljs');
const app = require('../src/crearApp')();

const { TOKEN_CSRF, COOKIE_CSRF } = require('./apoyo/csrf');
const { conAviso } = require('../src/utils/web');

const SESION = `sb_access_token=token-admin; ${COOKIE_CSRF}`;

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
    for (const ruta of [...RUTAS_GET, '/gestores/1/permiso', '/solicitudes/7/certificado', '/reportes/excel']) {
        const res = await request(app).get(ruta);
        assert.equal(res.status, 302, ruta);
        assert.match(res.headers.location, /^\/login\?/, ruta);
        assert.match(res.headers.location, /volver=/, ruta);
    }
});

test('sin sesión, cada ruta POST protegida redirige a /login', async () => {
    for (const ruta of RUTAS_POST) {
        const res = await request(app).post(ruta).set('X-CSRF-Token', TOKEN_CSRF).set('Cookie', COOKIE_CSRF).type('form').send({});
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
    assert.match(restablecer.text, /<script src="\/vendor\/supabase\.js" defer><\/script>/);
    assert.ok(!restablecer.text.includes('esm.sh'), 'supabase-js no debe venir de un CDN');
    const noExiste = await request(app).get('/no-existe');
    assert.equal(noExiste.status, 404);
    assert.match(noExiste.text, /Página no encontrada/);
});

test('cerrar sesión: por POST limpia las cookies; por GET no hace nada', async () => {
    const post = await request(app).post('/logout').set('Cookie', SESION).set('X-CSRF-Token', TOKEN_CSRF);
    assert.equal(post.status, 302);
    assert.match(post.headers.location, /^\/login\?msg=Cerraste%20sesi%C3%B3n\./);
    assert.ok(post.headers['set-cookie'].some((c) => c.startsWith('sb_access_token=;')));

    // Por GET bastaría un enlace o una imagen en otro sitio para cerrar la sesión.
    const get = await request(app).get('/logout').set('Cookie', SESION);
    assert.equal(get.status, 302);
    assert.equal(get.headers.location, '/');
    assert.ok(!(get.headers['set-cookie'] || []).some((c) => c.startsWith('sb_access_token=;')));
});

test('iniciar sesión guarda el token y el refresh token y vuelve a la página pedida', async () => {
    for (const ruta of ['/login', '/auth/login']) {
        const res = await request(app).post(ruta).set('X-CSRF-Token', TOKEN_CSRF).set('Cookie', COOKIE_CSRF).type('form')
            .send({ email: 'admin@ecoresiduos.test', password: 'clave-correcta', volver: '/gestores/1' });
        assert.equal(res.status, 302);
        assert.match(res.headers.location, /^\/gestores\/1\?msg=/);
        const cookies = res.headers['set-cookie'].join(';');
        assert.match(cookies, /sb_access_token=token-admin/);
        assert.match(cookies, /sb_refresh_token=refresco-1/);
    }
    const externo = await request(app).post('/login').set('X-CSRF-Token', TOKEN_CSRF).set('Cookie', COOKIE_CSRF).type('form')
        .send({ email: 'admin@ecoresiduos.test', password: 'clave-correcta', volver: '//sitio-malo.test' });
    assert.match(externo.headers.location, /^\/dashboard/);
    const mala = await request(app).post('/login').set('X-CSRF-Token', TOKEN_CSRF).set('Cookie', COOKIE_CSRF).type('form').send({ email: 'admin@ecoresiduos.test', password: 'mala' });
    assert.match(mala.headers.location, /^\/login\?msg=Correo%20o%20contrase%C3%B1a%20incorrectos\.&type=error&firma=/);
});

test('con el token vencido, la sesión se renueva con el refresh token', async () => {
    const res = await request(app).get('/gestores').set('Cookie', 'sb_access_token=token-vencido; sb_refresh_token=refresco-valido');
    assert.equal(res.status, 200);
    const cookies = res.headers['set-cookie'].join(';');
    assert.match(cookies, /sb_access_token=token-admin/);
    assert.match(cookies, /sb_refresh_token=refresco-2/);
});

test('renovar la sesión desde el aviso responde JSON, y 401 si ya venció', async () => {
    const ok = await request(app).post('/sesion/renovar').set('X-CSRF-Token', TOKEN_CSRF).set('Cookie', SESION).set('X-Requested-With', 'fetch');
    assert.equal(ok.status, 200);
    assert.equal(ok.body.ok, true);
    const vencida = await request(app).post('/sesion/renovar').set('X-CSRF-Token', TOKEN_CSRF).set('Cookie', COOKIE_CSRF).set('X-Requested-With', 'fetch');
    assert.equal(vencida.status, 401);
});

test('ver permiso sirve el PDF directamente sin filtrar la URL de almacenamiento', async () => {
    const res = await request(app).get('/gestores/1/permiso').set('Cookie', SESION);
    assert.equal(res.status, 200);
    assert.equal(res.headers['content-type'], 'application/pdf');
    assert.match(res.headers['content-disposition'], /inline;\s*filename="permiso-1\.pdf"/);
    assert.ok(!res.headers.location, 'no debe redirigir ni exponer el almacenamiento');
});

test('ver certificado sirve el PDF directamente sin filtrar la URL de almacenamiento', async () => {
    const res = await request(app).get('/solicitudes/7/certificado').set('Cookie', SESION);
    assert.equal(res.status, 200);
    assert.equal(res.headers['content-type'], 'application/pdf');
    assert.match(res.headers['content-disposition'], /inline;\s*filename="certificado-7\.pdf"/);
    assert.ok(!res.headers.location, 'no debe redirigir ni exponer el almacenamiento');
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

test('las fotos de las solicitudes abren el visor y una URL insegura no se enlaza', async () => {
    const FOTO = 'https://proyecto.supabase.co/storage/v1/object/public/escaneos_ia/u1/solicitudes/1.jpg';
    supabase.manejador = (consulta) => {
        if (consulta.tabla === 'solicitudes_recoleccion') {
            const fila = { ...solicitud, municipio: 'GIRÓN', foto_url: FOTO };
            return consulta.modo === 'lista' ? { data: [fila], count: 1 } : { data: fila };
        }
        return responderConDatos(consulta);
    };
    for (const ruta of ['/solicitudes', '/solicitudes/7']) {
        const res = await request(app).get(ruta).set('Cookie', SESION);
        assert.match(res.text, new RegExp(`<a href="${FOTO}" class="foto-ampliable[^"]*" data-visor`), `${ruta}: la foto no abre el visor`);
        assert.match(res.text, /aria-label="Ampliar[^"]*Aceite usado/, `${ruta}: el enlace no dice qué foto amplía`);
        assert.match(res.text, /<dialog id="visorImagen"/, `${ruta}: falta el visor en la página`);
    }

    // Con los datos de ejemplo la foto es «javascript:alert(1)»: no se enlaza.
    supabase.manejador = responderConDatos;
    for (const ruta of ['/solicitudes', '/solicitudes/7']) {
        const res = await request(app).get(ruta).set('Cookie', SESION);
        assert.ok(!res.text.includes('href="javascript:'), `${ruta} enlaza una URL javascript:`);
        assert.ok(!/data-visor\s/.test(res.text.replace(/<dialog id="visorImagen"[\s\S]*?<\/dialog>/, '')), `${ruta} abre el visor con una URL insegura`);
    }
});

test('las listas se paginan en el servidor con 25 filas y conteo exacto', async () => {
    await request(app).get('/gestores?pagina=3').set('Cookie', SESION);
    const consulta = supabase.consultas.find((c) => c.tabla === 'perfiles_gestor' && c.opciones.count === 'exact');
    assert.deepEqual(consulta.filtros.find((f) => f[0] === 'range').slice(1), [50, 74]);
});

test('el Excel del reporte trae filtros, las dos tablas, sus notas y solo cifras agregadas', async () => {
    const res = await request(app).get('/reportes/excel?categoria=PELIGROSO').set('Cookie', SESION).buffer(true).parse((r, cb) => {
        const partes = [];
        r.on('data', (p) => partes.push(p));
        r.on('end', () => cb(null, Buffer.concat(partes)));
    });
    assert.equal(res.status, 200);
    assert.match(res.headers['content-type'], /spreadsheetml\.sheet/);
    assert.match(res.headers['content-disposition'], /attachment; filename="reciclaje-por-municipio-\d{4}-\d{2}-\d{2}\.xlsx"/);

    const libro = new ExcelJS.Workbook();
    await libro.xlsx.load(res.body);
    assert.deepEqual(libro.worksheets.map((h) => h.name), ['Recolecciones', 'Cantidades por unidad']);
    const filas = (nombre) => {
        const lista = [];
        libro.getWorksheet(nombre).eachRow((fila) => lista.push(fila.values.slice(1).join('|')));
        return lista;
    };
    const recolecciones = filas('Recolecciones');
    assert.ok(recolecciones.some((f) => f.includes('Categoría: Peligroso (RESPEL)')), 'faltan los filtros');
    assert.ok(recolecciones.includes('Municipio|Aprovechable|Peligroso (RESPEL)|RAEE|Escombros (RCD)|Riesgo biológico|Total confirmadas|Recolectadas sin confirmar'));
    assert.ok(recolecciones.some((f) => f.startsWith('Total|')), 'falta la fila de total');
    assert.ok(recolecciones.some((f) => f.includes('confirmadas solas a las 72 horas')), 'faltan las notas');
    const unidades = filas('Cantidades por unidad');
    assert.ok(unidades.includes('Municipio|kg'));
    assert.doesNotMatch([...recolecciones, ...unidades].join('\n'), /laura@correo\.test|1098000000/);
});

test('los avisos firmados se anuncian en regiones status o alert', async () => {
    const exito = await request(app).get(conAviso('/gestores', 'Gestor aprobado')).set('Cookie', SESION);
    assert.match(exito.text, /role="status"[^>]*>\s*<div class="aviso" data-aviso>[\s\S]*?Gestor aprobado/);
    const error = await request(app).get(conAviso('/materiales', '<b>Falló</b>', 'error')).set('Cookie', SESION);
    assert.match(error.text, /role="alert"[\s\S]*?data-aviso-error[\s\S]*?&lt;b&gt;Falló&lt;\/b&gt;/);
});

test('un PDF de más de 4 MB se abre con un enlace firmado corto: no cabe en una respuesta serverless', async () => {
    const { VIGENCIA_ENLACE_S } = require('../src/utils/archivos');
    const original = supabase.storage.from;
    supabase.storage.from = (bucket) => ({
        ...original(bucket),
        async download() { return { data: new Blob([Buffer.alloc(5 * 1024 * 1024)]), error: null }; }
    });
    try {
        for (const [ruta, bucket] of [['/gestores/1/permiso', 'permisos'], ['/solicitudes/7/certificado', 'certificados']]) {
            supabase.storageOps.length = 0;
            const res = await request(app).get(ruta).set('Cookie', SESION);
            assert.equal(res.status, 302, ruta);
            assert.ok(res.headers.location.startsWith(`https://almacenamiento.test/${bucket}/`), res.headers.location);
            assert.equal(res.headers['cache-control'], 'no-store');
            const firma = supabase.storageOps.find((o) => o.op === 'firmar');
            assert.equal(firma.segundos, VIGENCIA_ENLACE_S);
        }
    } finally {
        supabase.storage.from = original;
    }
});

test('el permiso que se sube desde el panel no puede pasar de 4 MB', async () => {
    const gestorService = require('../src/services/GestorService');
    const grande = Buffer.concat([Buffer.from('%PDF-1.7'), Buffer.alloc(4 * 1024 * 1024)]);
    await assert.rejects(() => gestorService.subirPermiso(1, grande), /supera los 4 MB/);
});
