const test = require('node:test');
const assert = require('node:assert/strict');
const { instalarSupabaseFalso } = require('./apoyo/supabaseFalso');
const { responderConDatos, solicitud } = require('./apoyo/datos');
const { conAviso } = require('../src/utils/web');

const supabase = instalarSupabaseFalso();
const geocodificador = require('../src/services/geocodificador');
geocodificador.geocodificar = async () => null;

const request = require('supertest');
const app = require('../src/crearApp')();

const SESION = 'sb_access_token=token-admin';
const CAIDA = { data: null, error: { code: '08006', message: 'connection to server failed' } };

test.beforeEach(() => {
    supabase.limpiar();
    supabase.manejador = responderConDatos;
});

// La consola del servidor registra el detalle técnico; en las pruebas sobra.
function enSilencio(fn) {
    return async () => {
        const original = console.error;
        console.error = () => {};
        try { await fn(); } finally { console.error = original; }
    };
}

test('si falla la carga de un detalle o un formulario, se queda en la página con «Reintentar»', enSilencio(async () => {
    const casos = [
        ['/solicitudes/7', 'solicitudes_recoleccion', 'No pudimos cargar la solicitud 7'],
        ['/gestores/1', 'perfiles_gestor', 'No pudimos cargar el gestor'],
        ['/gestores/edit/1', 'perfiles_gestor', 'No pudimos cargar el gestor'],
        ['/materiales/edit/2', 'materiales_residuos', 'No pudimos cargar el material'],
        ['/autoridades/edit/5', 'autoridades_ambientales', 'No pudimos cargar la autoridad ambiental']
    ];
    for (const [ruta, tabla, titulo] of casos) {
        supabase.manejador = (c) => (c.tabla === tabla && c.modo !== 'lista' ? CAIDA : responderConDatos(c));
        const res = await request(app).get(ruta).set('Cookie', SESION);
        assert.equal(res.status, 503, ruta);
        assert.match(res.text, new RegExp(`<h1 class="titulo-pagina">${titulo}</h1>`), ruta);
        assert.match(res.text, new RegExp(`<a href="${ruta.replace(/\//g, '\\/')}" class="enlace[^"]*">Reintentar</a>`), `${ruta}: Reintentar debe volver a la misma página`);
        assert.ok(!res.text.includes('connection to server failed'), `${ruta}: muestra el error técnico`);
    }
}));

test('un material o una autoridad que no existe responde 404, no un error', async () => {
    supabase.manejador = (c) => (['materiales_residuos', 'autoridades_ambientales'].includes(c.tabla) && c.modo !== 'lista' ? { data: null } : responderConDatos(c));
    for (const ruta of ['/materiales/edit/2', '/autoridades/edit/5']) {
        const res = await request(app).get(ruta).set('Cookie', SESION);
        assert.equal(res.status, 404, ruta);
        assert.match(res.text, /Página no encontrada/, ruta);
    }
});

test('el reporte sin recolecciones lo dice en lugar de mostrar tablas en cero', async () => {
    supabase.manejador = (c) => (c.tabla === 'solicitudes_recoleccion' ? { data: [], count: 0 } : responderConDatos(c));
    const conFiltros = await request(app).get('/reportes?desde=2020-01-01&hasta=2020-01-31').set('Cookie', SESION);
    assert.equal(conFiltros.status, 200);
    assert.match(conFiltros.text, /No hay recolecciones con esos filtros/);
    assert.ok(!conFiltros.text.includes('<canvas'), 'no debe dibujar un gráfico vacío');
    const sinFiltros = await request(app).get('/reportes').set('Cookie', SESION);
    assert.match(sinFiltros.text, /Aún no hay recolecciones/);
});

test('el certificado se muestra junto al estado, solo en lo recolectado', async () => {
    const filas = [
        { ...solicitud, id: 1, estado: 'PUBLICADO', municipio: 'GIRÓN', foto_url: null, certificado_url: null },
        { ...solicitud, id: 2, estado: 'RECOLECTADO', municipio: 'GIRÓN', foto_url: null, certificado_url: null },
        { ...solicitud, id: 3, estado: 'RECOLECTADO', municipio: 'GIRÓN', foto_url: null, certificado_url: 'https://almacenamiento.test/c.pdf' }
    ];
    supabase.manejador = (c) => (c.tabla === 'solicitudes_recoleccion' && c.modo === 'lista' ? { data: filas, count: filas.length } : responderConDatos(c));
    const html = (await request(app).get('/solicitudes').set('Cookie', SESION)).text;
    assert.ok(!html.includes('<th scope="col">Certificado</th>'), 'la columna Certificado ya no existe');
    const filasHtml = html.split('<tr>').slice(2);
    assert.ok(!/Sin certificado|Certificado</.test(filasHtml[0]), 'una solicitud publicada no habla de certificado');
    assert.match(filasHtml[1], /Sin certificado/);
    assert.match(filasHtml[2], /href="\/solicitudes\/3\/certificado"[^>]*target="_blank" rel="noopener noreferrer"/);
    assert.ok(!html.includes('https://almacenamiento.test/c.pdf'), 'la URL de almacenamiento no se filtra en el HTML');
});

test('el enlace para ordenar no copia los parámetros de un aviso', async () => {
    const html = (await request(app).get(conAviso('/solicitudes?municipio=Gir%C3%B3n', 'Listo')).set('Cookie', SESION)).text;
    const enlace = html.match(/<a class="orden-enlace" href="([^"]+)"/)[1];
    assert.match(enlace, /municipio=Gir%C3%B3n/);
    assert.match(enlace, /orden=fecha/);
    assert.ok(!/msg=|firma=|type=/.test(enlace), enlace);
});

test('las tablas del reporte se desplazan con la primera columna fija y las listas pueden pasar a tarjetas', async () => {
    const reporte = (await request(app).get('/reportes').set('Cookie', SESION)).text;
    assert.match(reporte, /<table class="tabla tabla-primera-fija" data-sin-apilar>/);
    const lista = (await request(app).get('/solicitudes').set('Cookie', SESION)).text;
    assert.match(lista, /<div class="tabla-contenedor"[^>]*>\s*<table class="tabla">/);
});

test('las cifras van a la derecha y los filtros no compiten con la tabla', async () => {
    const lista = (await request(app).get('/solicitudes').set('Cookie', SESION)).text;
    assert.match(lista, /<th scope="col" class="num">Cantidad<\/th>/);
    assert.match(lista, /<td class="num">120 kg<\/td>/);
    assert.match(lista, /<form method="GET" action="\/solicitudes" class="panel-filtros /);
    // La paginación va en el mismo bloque que su tabla, pegada a su pie.
    assert.match(lista, /<\/table>\s*<\/div>\s*<nav class="paginacion/);
    // Ver detalle solo lleva a otra pantalla: botón delineado, no tonal.
    assert.match(lista, /class="btn-outlined btn-sm" aria-label="Ver detalle/);
});

test('en un detalle la etiqueta de cada dato es pequeña y el dato es el protagonista', async () => {
    const html = (await request(app).get('/solicitudes/7').set('Cookie', SESION)).text;
    assert.match(html, /<dt class="dato-etiqueta">Cantidad estimada<\/dt><dd>/);
    assert.ok(!html.includes('<dt class="text-label-l'), 'quedó una etiqueta con el estilo anterior');
});
