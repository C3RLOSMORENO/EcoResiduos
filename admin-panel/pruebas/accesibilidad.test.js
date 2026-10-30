const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { instalarSupabaseFalso } = require('./apoyo/supabaseFalso');
const { responderConDatos } = require('./apoyo/datos');

const supabase = instalarSupabaseFalso();
const geocodificador = require('../src/services/geocodificador');
geocodificador.geocodificar = async () => null;

const request = require('supertest');
const app = require('../src/crearApp')();

const SESION = 'sb_access_token=token-admin';
const PANTALLAS = ['/dashboard', '/solicitudes', '/solicitudes/7', '/gestores', '/gestores/1', '/materiales', '/autoridades', '/ciudadanos', '/reportes', '/componentes'];
const CSS = fs.readFileSync(path.join(__dirname, '..', 'src', 'public', 'css', 'style.css'), 'utf8');

test.beforeEach(() => {
    supabase.limpiar();
    supabase.manejador = responderConDatos;
});

test('dos regiones no comparten nombre: la tabla se nombra con su caption, no con el título de la sección', async () => {
    for (const ruta of PANTALLAS) {
        const html = (await request(app).get(ruta).set('Cookie', SESION)).text;
        const nombres = [...html.matchAll(/<(section|div)\b[^>]*?\baria-labelledby="([^"]+)"/g)].map((m) => m[2]);
        const repetidos = nombres.filter((n, i) => nombres.indexOf(n) !== i);
        assert.deepEqual(repetidos, [], `${ruta}: regiones con el mismo nombre: ${repetidos.join(', ')}`);
        nombres.join(' ').split(/\s+/).forEach((id) => {
            assert.ok(html.includes(`id="${id}"`), `${ruta}: aria-labelledby apunta a un id que no existe: ${id}`);
        });
    }
});

test('las tablas que se desplazan no empujan la página hacia el lado (WCAG 1.4.10)', () => {
    const regla = CSS.match(/\.tabla-contenedor\{[^}]*\}/);
    assert.ok(regla, 'falta .tabla-contenedor en el CSS compilado');
    assert.match(regla[0], /position:relative/);
    assert.match(regla[0], /overflow-x:auto/);
});

test('la barra fija no tapa el foco al subir con Shift+Tab (WCAG 2.4.11)', () => {
    assert.match(CSS, /scroll-padding-top:88px/);
});

test('el nombre del logo del menú contiene su texto visible (WCAG 2.5.3)', async () => {
    const html = (await request(app).get('/dashboard').set('Cookie', SESION)).text;
    const enlace = html.match(/<a href="\/dashboard" class="mb-4[^"]*" aria-label="([^"]+)">([\s\S]*?)<\/a>/);
    assert.ok(enlace, 'no se encontró el logo del menú');
    const visible = enlace[2].replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
    const nombre = enlace[1].replace(/[,:]/g, ' ').replace(/\s+/g, ' ');
    assert.ok(nombre.includes(visible), `«${enlace[1]}» no contiene el texto visible «${visible}»`);
});

test('cada página tiene un solo h1 y cada gráfico describe sus datos en texto visible', async () => {
    for (const ruta of PANTALLAS) {
        const html = (await request(app).get(ruta).set('Cookie', SESION)).text;
        assert.equal((html.match(/<h1[\s>]/g) || []).length, 1, `${ruta}: debe tener un solo h1`);
        for (const [, etiqueta] of html.matchAll(/(<canvas data-grafico=[^>]*>)/g)) {
            assert.match(etiqueta, /role="img"/, `${ruta}: gráfico sin role="img"`);
            const descripcion = (etiqueta.match(/aria-describedby="([^"]+)"/) || [])[1];
            assert.ok(descripcion, `${ruta}: gráfico sin aria-describedby`);
            const texto = html.match(new RegExp(`<p id="${descripcion}"[^>]*>([\\s\\S]*?)</p>`));
            assert.ok(texto && /\d/.test(texto[1]), `${ruta}: la descripción del gráfico no trae sus cifras`);
        }
    }
});

test('las preferencias de accesibilidad están en todas las pantallas, también sin sesión', async () => {
    for (const ruta of ['/dashboard', '/gestores', '/accesibilidad']) {
        const html = (await request(app).get(ruta).set('Cookie', SESION)).text;
        assert.match(html, /id="botonAccesibilidad"/, `${ruta}: falta el botón de accesibilidad`);
        assert.match(html, /src="\/js\/accesibilidad\.js\?v=/);
    }
    const login = (await request(app).get('/login')).text;
    assert.match(login, /id="botonAccesibilidad"/, 'el inicio de sesión también debe tenerlo');
    assert.match(login, /href="\/accesibilidad"/);
});

test('la declaración de accesibilidad es pública y cita la norma y sus limitaciones', async () => {
    const respuesta = await request(app).get('/accesibilidad');
    assert.equal(respuesta.status, 200);
    assert.equal((respuesta.text.match(/<h1[\s>]/g) || []).length, 1);
    assert.match(respuesta.text, /WCAG\) 2\.1/);
    assert.match(respuesta.text, /Resolución 1519 de 2020/);
    assert.match(respuesta.text, /Limitaciones conocidas/);
});

test('las preferencias guardadas se aplican antes de pintar y el CSS las interpreta', async () => {
    const html = (await request(app).get('/login')).text;
    const cabeza = html.slice(0, html.indexOf('</head>'));
    assert.match(cabeza, /localStorage\.getItem\('accesibilidad'\)/, 'head.ejs debe aplicar las preferencias antes del CSS');

    // Espaciado con los valores mínimos de WCAG 1.4.12 y tamaño de texto hasta 150 %.
    assert.match(CSS, /\[data-espaciado\][^{]*\{[^}]*letter-spacing:\.12em!important/);
    assert.match(CSS, /\[data-espaciado\][^{]*\{[^}]*word-spacing:\.16em!important/);
    assert.match(CSS, /\[data-espaciado\][^{]*\{[^}]*line-height:1\.5!important/);
    assert.match(CSS, /\[data-texto="150"\]\{--zoom:1\.5\}/);
    assert.match(CSS, /\[data-texto\] body\{zoom:var\(--zoom\)\}/);
    assert.match(CSS, /\[data-contraste\]\{--md-sys-color-on-surface-variant:var\(--md-sys-color-on-surface\)/);
});
