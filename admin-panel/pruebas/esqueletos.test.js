// Cada esqueleto de carga reproduce su pantalla con los textos reales (título,
// etiquetas de los filtros, columnas y títulos de las tarjetas). Si alguien
// cambia una pantalla y olvida su esqueleto, el cambio de página «salta».
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { instalarSupabaseFalso } = require('./apoyo/supabaseFalso');
const { responderConDatos } = require('./apoyo/datos');

const supabase = instalarSupabaseFalso();
require('../src/services/geocodificador').geocodificar = async () => null;
const request = require('supertest');
const app = require('../src/crearApp')();

const SESION = 'sb_access_token=token-admin';
const MAIN = fs.readFileSync(path.join(__dirname, '..', 'src', 'public', 'js', 'main.js'), 'utf8');

const PANTALLAS = {
    inicio: '/dashboard',
    solicitudes: '/solicitudes',
    gestores: '/gestores',
    ciudadanos: '/ciudadanos',
    materiales: '/materiales',
    autoridades: '/autoridades',
    reportes: '/reportes',
    'detalle-solicitud': '/solicitudes/7',
    'detalle-gestor': '/gestores/1'
};

test.beforeEach(() => {
    supabase.limpiar();
    supabase.manejador = responderConDatos;
});

// Texto que se ve: sin lo que es solo para lectores de pantalla ni los íconos.
function textoVisible(html) {
    return html
        .replace(/<span[^>]*(sr-only|aria-hidden="true")[^>]*>[\s\S]*?<\/span>/g, '')
        .replace(/<[^>]+>/g, ' ')
        .replace(/&nbsp;/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
}

function todos(html, regex) {
    return [...html.matchAll(regex)].map((m) => textoVisible(m[1])).filter(Boolean);
}

async function pagina(ruta) {
    const res = await request(app).get(ruta).set('Cookie', SESION);
    assert.equal(res.status, 200, ruta);
    return res.text;
}

function plantilla(html, nombre) {
    const bloque = html.match(new RegExp(`<template id="esqueleto-${nombre}">([\\s\\S]*?)</template>`));
    assert.ok(bloque, `falta la plantilla esqueleto-${nombre}`);
    return bloque[1];
}

test('cada pantalla con esqueleto tiene su plantilla y main.js la usa', async () => {
    const html = await pagina('/dashboard');
    for (const nombre of [...Object.keys(PANTALLAS), 'formulario']) {
        plantilla(html, nombre);
        assert.ok(MAIN.includes(`'${nombre}'`), `main.js no abre esqueleto-${nombre}`);
    }
    assert.ok(!/<template id="esqueleto-lista">|<template id="esqueleto-detalle">/.test(html), 'quedó un esqueleto genérico');
});

test('el esqueleto muestra el título, los filtros y las columnas reales de su pantalla', async () => {
    for (const [nombre, ruta] of Object.entries(PANTALLAS)) {
        const real = await pagina(ruta);
        const esqueleto = plantilla(real, nombre);

        const titulo = todos(esqueleto, /<p class="titulo-pagina">([\s\S]*?)<\/p>/g);
        if (titulo.length) assert.deepEqual(titulo, todos(real, /<h1 class="titulo-pagina">([\s\S]*?)<\/h1>/g), `${nombre}: título`);

        const etiquetasReales = todos(real, /<label[^>]*class="campo-etiqueta"[^>]*>([\s\S]*?)<\/label>/g);
        todos(esqueleto, /<span class="campo-etiqueta">([\s\S]*?)<\/span>/g).forEach((etiqueta) => {
            assert.ok(etiquetasReales.includes(etiqueta), `${nombre}: el filtro «${etiqueta}» no está en la pantalla`);
        });

        // Las columnas de la primera tabla, en el mismo orden.
        const primeraTabla = (html) => (html.match(/<thead>([\s\S]*?)<\/thead>/) || [])[1] || '';
        const columnasEsqueleto = todos(primeraTabla(esqueleto), /<th[^>]*>([\s\S]*?)<\/th>/g);
        if (columnasEsqueleto.length) {
            const reales = todos(primeraTabla(real.slice(real.indexOf('<main'))), /<th scope="col"[^>]*>([\s\S]*?)<\/th>/g);
            assert.deepEqual(columnasEsqueleto, reales.slice(0, columnasEsqueleto.length), `${nombre}: columnas`);
        }

        const titulosReales = todos(real, /<(?:h2|figcaption)[^>]*>([\s\S]*?)<\/(?:h2|figcaption)>/g);
        todos(esqueleto, /<p class="(?:tarjeta-titulo|seccion-titulo)">([\s\S]*?)<\/p>/g).forEach((t) => {
            assert.ok(titulosReales.includes(t), `${nombre}: la sección «${t}» no está en la pantalla`);
        });
    }
});

test('el esqueleto no agrega encabezados ni un segundo h1 a la página', async () => {
    const html = await pagina('/dashboard');
    const esqueletos = [...html.matchAll(/<template id="esqueleto-[^"]+">([\s\S]*?)<\/template>/g)].map((m) => m[1]).join('');
    assert.ok(!/<h[1-6][\s>]/.test(esqueletos), 'los títulos del esqueleto deben ser <p>: todo el esqueleto es aria-hidden');
});

test('mientras carga, la navegación marca el destino y la tabla se apila como la real', () => {
    assert.match(MAIN, /marcarNavegacion\(url\)/);
    assert.match(MAIN, /prepararTabla\(tabla\);\s*tabla\.classList\.toggle\('tabla-apilada'/);
});
