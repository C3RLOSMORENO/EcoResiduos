// Inventario de rutas (PROMPT_PANEL_ADMIN.md §4): cada ruta del código está
// en esta lista y cada una responde como debe sin sesión, sin token CSRF y
// con sesión. Además, crear, editar y eliminar por todos sus alias, con las
// validaciones de cada formulario.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { instalarSupabaseFalso } = require('./apoyo/supabaseFalso');
const { responderConDatos } = require('./apoyo/datos');

const supabase = instalarSupabaseFalso();
const geocodificador = require('../src/services/geocodificador');
geocodificador.geocodificar = async () => ({ latitud: 7.1, longitud: -73.1 });

const request = require('supertest');
const app = require('../src/crearApp')();
const { TOKEN_CSRF, COOKIE_CSRF } = require('./apoyo/csrf');

const SESION = `sb_access_token=token-admin; ${COOKIE_CSRF}`;

// Si agregas o quitas una ruta, actualiza esta lista y el inventario.
const INVENTARIO = [
    'GET /', 'GET /accesibilidad', 'GET /login', 'POST /login', 'POST /auth/login', 'GET /logout', 'POST /logout',
    'GET /restablecer-password', 'POST /sesion/renovar', 'GET /componentes',
    'GET /dashboard',
    'GET /gestores', 'POST /gestores', 'POST /gestores/guardar', 'GET /gestores/nuevo',
    'GET /gestores/edit/:id', 'GET /gestores/editar/:id', 'POST /gestores/edit/:id', 'POST /gestores/editar/:id',
    'POST /gestores/delete/:id', 'POST /gestores/eliminar/:id', 'GET /gestores/:id/permiso', 'POST /gestores/:id/permiso',
    'POST /gestores/estado/:id', 'POST /gestores/:id/estado', 'POST /gestores/:id/materiales/verificar-todos',
    'POST /gestores/:id/materiales/:materialId/verificar', 'POST /gestores/:id/materiales/:materialId/quitar',
    'POST /gestores/:id/imagenes/quitar',
    'GET /gestores/:id',
    'GET /materiales', 'POST /materiales', 'POST /materiales/guardar', 'GET /materiales/nuevo',
    'GET /materiales/edit/:id', 'GET /materiales/editar/:id', 'POST /materiales/edit/:id', 'POST /materiales/editar/:id',
    'POST /materiales/delete/:id', 'POST /materiales/eliminar/:id',
    'GET /autoridades', 'POST /autoridades', 'POST /autoridades/guardar', 'GET /autoridades/nuevo',
    'GET /autoridades/edit/:id', 'GET /autoridades/editar/:id', 'POST /autoridades/edit/:id', 'POST /autoridades/editar/:id',
    'POST /autoridades/delete/:id', 'POST /autoridades/eliminar/:id',
    'GET /solicitudes', 'GET /solicitudes/:id', 'GET /solicitudes/:id/certificado', 'POST /solicitudes/:id/cancelar',
    'POST /solicitudes/:id/problema/no-recogido', 'POST /solicitudes/:id/estado',
    'GET /ciudadanos',
    'GET /reportes', 'GET /reportes/excel',
    'POST /recorridos/:pantalla',
    'POST /asistente/preguntar'
];

const PUBLICAS = new Set(['GET /', 'GET /accesibilidad', 'GET /login', 'POST /login', 'POST /auth/login', 'GET /logout', 'POST /logout', 'GET /restablecer-password']);

// Lee las rutas tal como están escritas en src/routes/, con el prefijo con el
// que index.js monta cada archivo.
function rutasDelCodigo() {
    const carpeta = path.join(__dirname, '..', 'src', 'routes');
    const indice = fs.readFileSync(path.join(carpeta, 'index.js'), 'utf8');
    const archivoDe = Object.fromEntries([...indice.matchAll(/const (\w+) = require\('\.\/(\w+)'\)/g)].map((m) => [m[1], m[2]]));
    const montajes = [['', 'index']];
    for (const m of indice.matchAll(/router\.use\('([^']+)',(?:\s*requireAuth,)?\s*(\w+)\)/g)) {
        montajes.push([m[1] === '/' ? '' : m[1], archivoDe[m[2]]]);
    }
    const rutas = [];
    for (const [prefijo, archivo] of montajes) {
        const codigo = fs.readFileSync(path.join(carpeta, `${archivo}.js`), 'utf8');
        for (const m of codigo.matchAll(/router\.(get|post)\('([^']+)'/g)) {
            const ruta = (prefijo + (m[2] === '/' && prefijo ? '' : m[2])).replace(/\(\\\\d\+\)/g, '');
            rutas.push(`${m[1].toUpperCase()} ${ruta}`);
        }
    }
    return rutas;
}

const EJEMPLO_ID = { gestores: '1', materiales: '2', autoridades: '5', solicitudes: '7' };
const concreta = (ruta) => ruta
    .replace(':materialId', '2')
    .replace(':pantalla', 'dashboard')
    .replace(':id', EJEMPLO_ID[ruta.split('/')[1]] || '1');

test.beforeEach(() => {
    supabase.limpiar();
    supabase.manejador = responderConDatos;
});

test('el inventario coincide con las rutas del código: ninguna sobra ni falta', () => {
    const codigo = rutasDelCodigo();
    assert.deepEqual([...codigo].sort(), [...INVENTARIO].sort());
});

test('sin sesión, toda ruta protegida lleva a /login; las públicas responden', async () => {
    for (const ruta of INVENTARIO) {
        const [metodo, patron] = ruta.split(' ');
        const url = concreta(patron);
        if (metodo === 'GET') {
            const res = await request(app).get(url);
            if (PUBLICAS.has(ruta)) {
                assert.ok([200, 302].includes(res.status), `${ruta}: ${res.status}`);
                if (res.status === 302) assert.doesNotMatch(res.headers.location, /volver=/, ruta);
            } else {
                assert.equal(res.status, 302, ruta);
                assert.match(res.headers.location, /^\/login\?.*volver=/, ruta);
            }
        } else if (!PUBLICAS.has(ruta)) {
            const res = await request(app).post(url).set('Cookie', COOKIE_CSRF).set('X-CSRF-Token', TOKEN_CSRF).type('form').send({});
            assert.equal(res.status, 302, ruta);
            assert.match(res.headers.location, /^\/login\?/, ruta);
        }
    }
});

test('todo POST sin token CSRF se rechaza con 403, también el login', async () => {
    for (const ruta of INVENTARIO.filter((r) => r.startsWith('POST '))) {
        const url = concreta(ruta.slice(5));
        const res = await request(app).post(url).set('Cookie', 'sb_access_token=token-admin').type('form').send({});
        assert.equal(res.status, 403, ruta);
    }
    const escrituras = supabase.consultas.filter((c) => c.accion !== 'select');
    assert.equal(escrituras.length, 0, 'un POST rechazado no debe escribir en la base');
    assert.equal(supabase.rpcs.length, 0);
});

test('con sesión, toda ruta GET responde sin errores', async () => {
    for (const ruta of INVENTARIO.filter((r) => r.startsWith('GET '))) {
        const res = await request(app).get(concreta(ruta.slice(4))).set('Cookie', SESION);
        assert.ok(res.status < 400, `${ruta}: ${res.status}`);
    }
});

// --- Crear, editar y eliminar -------------------------------------------------

const enviar = (url, cuerpo = {}) => request(app).post(url).set('Cookie', SESION).set('X-CSRF-Token', TOKEN_CSRF).type('form').send(cuerpo);
const escrituras = (tabla, accion) => supabase.consultas.filter((c) => c.tabla === tabla && c.accion === accion);
function aviso(res) {
    const destino = new URL(res.headers.location, 'http://panel.test');
    return { ruta: destino.pathname, mensaje: destino.searchParams.get('msg'), tipo: destino.searchParams.get('type') };
}

const MATERIAL = { codigo: ' y9.2 ', nombre_comun: 'Pilas alcalinas', categoria: 'peligroso', descripcion: 'Pilas usadas de equipos del hogar.' };

test('materiales: crear y editar por los dos alias guarda los datos limpios', async () => {
    for (const url of ['/materiales', '/materiales/guardar']) {
        supabase.limpiar();
        supabase.manejador = responderConDatos;
        const res = await enviar(url, MATERIAL);
        assert.deepEqual(aviso(res), { ruta: '/materiales', mensaje: 'Material añadido al catálogo.', tipo: 'success' }, url);
        assert.deepEqual(escrituras('materiales_residuos', 'insert')[0].payload, [{
            codigo: 'Y9.2', nombre_comun: 'Pilas alcalinas', categoria: 'PELIGROSO', descripcion: 'Pilas usadas de equipos del hogar.',
            guia_manejo: null, subcategoria: null, advertencia_manejo: null
        }], url);
    }
    for (const url of ['/materiales/edit/2', '/materiales/editar/2']) {
        supabase.limpiar();
        supabase.manejador = responderConDatos;
        const res = await enviar(url, MATERIAL);
        assert.equal(aviso(res).mensaje, 'Material actualizado.', url);
        const update = escrituras('materiales_residuos', 'update')[0];
        assert.equal(update.valor('eq', 'id'), '2', url);
        assert.equal(update.payload.codigo, 'Y9.2', url);
    }
});

test('materiales: cada dato inválido vuelve al formulario con su mensaje y no guarda nada', async () => {
    const casos = [
        [{ codigo: 'Y 8' }, /código oficial/],
        [{ nombre_comun: 'Pi' }, /al menos 3 caracteres/],
        [{ categoria: 'INVENTADA' }, /Elige la categoría/],
        [{ descripcion: 'Corta' }, /al menos 10 caracteres/]
    ];
    for (const [cambio, mensaje] of casos) {
        supabase.limpiar();
        supabase.manejador = responderConDatos;
        const nuevo = aviso(await enviar('/materiales', { ...MATERIAL, ...cambio }));
        assert.equal(nuevo.ruta, '/materiales/nuevo');
        assert.equal(nuevo.tipo, 'error');
        assert.match(nuevo.mensaje, mensaje);
        const edicion = aviso(await enviar('/materiales/edit/2', { ...MATERIAL, ...cambio }));
        assert.equal(edicion.ruta, '/materiales/edit/2');
        assert.match(edicion.mensaje, mensaje);
        assert.equal(supabase.consultas.filter((c) => c.accion !== 'select').length, 0, JSON.stringify(cambio));
    }
});

test('materiales: un material sin solicitudes se elimina por los dos alias', async () => {
    for (const url of ['/materiales/delete/2', '/materiales/eliminar/2']) {
        supabase.limpiar();
        supabase.manejador = (consulta) => (consulta.opciones.head ? { data: null, count: 0 } : responderConDatos(consulta));
        const res = await enviar(url);
        assert.equal(aviso(res).mensaje, 'Material eliminado del catálogo.', url);
        assert.equal(escrituras('gestor_material', 'delete')[0].valor('eq', 'material_id'), '2', 'se quita de los gestores primero');
        assert.equal(escrituras('materiales_residuos', 'delete')[0].valor('eq', 'id'), '2', url);
    }
});

const AUTORIDAD = { nombre: 'Área Metropolitana de Bucaramanga', sigla: 'amb', email: 'Contacto@AMB.test', telefono: '6076444831' };

test('autoridades: crear, editar y eliminar por todos sus alias', async () => {
    for (const url of ['/autoridades', '/autoridades/guardar']) {
        supabase.limpiar();
        supabase.manejador = responderConDatos;
        const res = await enviar(url, AUTORIDAD);
        assert.deepEqual(aviso(res), { ruta: '/autoridades', mensaje: 'Autoridad ambiental registrada.', tipo: 'success' }, url);
        const fila = escrituras('autoridades_ambientales', 'insert')[0].payload[0];
        assert.equal(fila.sigla, 'AMB');
        assert.equal(fila.email, 'contacto@amb.test');
    }
    for (const url of ['/autoridades/edit/5', '/autoridades/editar/5']) {
        supabase.limpiar();
        supabase.manejador = responderConDatos;
        assert.equal(aviso(await enviar(url, AUTORIDAD)).mensaje, 'Autoridad actualizada.', url);
        assert.equal(escrituras('autoridades_ambientales', 'update')[0].valor('eq', 'id'), '5', url);
    }
    for (const url of ['/autoridades/delete/5', '/autoridades/eliminar/5']) {
        supabase.limpiar();
        supabase.manejador = responderConDatos;
        assert.equal(aviso(await enviar(url)).mensaje, 'Autoridad eliminada del directorio.', url);
        assert.equal(escrituras('autoridades_ambientales', 'delete')[0].valor('eq', 'id'), '5', url);
    }
});

test('autoridades: sin nombre no se guarda', async () => {
    const res = aviso(await enviar('/autoridades', { ...AUTORIDAD, nombre: ' ' }));
    assert.deepEqual(res, { ruta: '/autoridades/nuevo', mensaje: 'El nombre institucional de la autoridad es obligatorio.', tipo: 'error' });
    assert.equal(escrituras('autoridades_ambientales', 'insert').length, 0);
});

const GESTOR = {
    nit: '900.396.512-1',
    razon_social: 'Reciclajes del Oriente S.A.S.',
    municipio: 'Floridablanca',
    direccion: 'Calle 10 # 20-30',
    telefono_contacto: '6076768585',
    email_contacto: 'contacto@oriente.test',
    materiales_ids: ['2', '3']
};

test('gestores: crear por los dos alias lo deja aprobado, ubicado y con sus materiales verificados', async () => {
    for (const url of ['/gestores', '/gestores/guardar']) {
        supabase.limpiar();
        supabase.manejador = responderConDatos;
        const res = await enviar(url, GESTOR);
        const { ruta, tipo } = aviso(res);
        assert.equal(ruta, '/gestores/1', url);
        assert.equal(tipo, 'success', url);
        const fila = escrituras('perfiles_gestor', 'insert')[0].payload[0];
        assert.equal(fila.nit, '900396512', 'el NIT se guarda sin puntos ni dígito de verificación');
        assert.equal(fila.razon_social, 'RECICLAJES DEL ORIENTE S.A.S.');
        assert.equal(fila.estado_verificacion, 'APROBADO');
        assert.equal(fila.latitud, 7.1);
        assert.deepEqual(escrituras('gestor_material', 'insert')[0].payload, [
            { gestor_id: 1, material_id: 2, verificado: true },
            { gestor_id: 1, material_id: 3, verificado: true }
        ]);
    }
});

test('gestores: cada dato inválido vuelve al formulario con su mensaje y no guarda nada', async () => {
    const casos = [
        [{ nit: '12345' }, /NIT es obligatorio/],
        [{ razon_social: 'AB' }, /razón social/],
        [{ municipio: 'Medellín' }, /6 municipios/],
        [{ direccion: 'Cl 1' }, /dirección es obligatoria/],
        [{ telefono_contacto: '' }, /teléfono de contacto/],
        [{ email_contacto: 'sin-arroba' }, /correo de contacto/],
        [{ horario: 'x'.repeat(121) }, /120 caracteres/]
    ];
    for (const [cambio, mensaje] of casos) {
        supabase.limpiar();
        supabase.manejador = responderConDatos;
        const res = aviso(await enviar('/gestores', { ...GESTOR, ...cambio }));
        assert.equal(res.ruta, '/gestores/nuevo', JSON.stringify(cambio));
        assert.equal(res.tipo, 'error');
        assert.match(res.mensaje, mensaje);
        assert.equal(supabase.consultas.filter((c) => c.accion !== 'select').length, 0, JSON.stringify(cambio));
    }
});

test('gestores: el estado se cambia por los dos alias y un estado inventado se rechaza', async () => {
    for (const url of ['/gestores/estado/1', '/gestores/1/estado']) {
        supabase.limpiar();
        supabase.manejador = responderConDatos;
        const res = aviso(await enviar(url, { estado: 'SUSPENDIDO', motivo: 'Permiso vencido' }));
        assert.deepEqual(res, { ruta: '/gestores/1', mensaje: 'Estado del gestor: Suspendido.', tipo: 'success' }, url);
        assert.equal(supabase.rpcs[0].params.p_estado, 'SUSPENDIDO');
    }
    supabase.limpiar();
    supabase.manejador = responderConDatos;
    const malo = aviso(await enviar('/gestores/1/estado', { estado: 'VIP', redirectUrl: 'https://sitio-malo.test' }));
    assert.equal(malo.ruta, '/gestores/1', 'no redirige fuera del panel');
    assert.equal(malo.tipo, 'error');
    assert.match(malo.mensaje, /Estado inválido/);
    assert.equal(supabase.rpcs.length, 0);
});
