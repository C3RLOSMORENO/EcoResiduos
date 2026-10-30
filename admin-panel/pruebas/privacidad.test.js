const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { instalarSupabaseFalso } = require('./apoyo/supabaseFalso');

instalarSupabaseFalso();
const request = require('supertest');
const app = require('../src/crearApp')();
const politica = require('../src/utils/politicaDatos');

const DART = fs.readFileSync(path.join(__dirname, '..', '..', 'app', 'lib', 'legal', 'politica_datos.dart'), 'utf8');

/**
 * Secciones de la política tal como las escribe la app: cada texto de Dart es
 * una secuencia de literales '…' contiguos, separados por comas.
 *
 * @returns {{titulo: string, parrafos: string[]}[]}
 */
function seccionesDeLaApp() {
    const constante = (nombre) => DART.match(new RegExp(`const ${nombre} = '([^']+)'`))[1];
    const valores = { versionPoliticaDatos: constante('versionPoliticaDatos'), correoDatosPersonales: constante('correoDatosPersonales') };
    const lista = DART.slice(DART.indexOf('const politicaDatos = ['));
    return lista.split('SeccionPolitica(').slice(1).map((bloque) => {
        const textos = [];
        let actual = '';
        for (const m of bloque.matchAll(/'((?:[^'\\]|\\.)*)'|,|\]\)/g)) {
            if (m[1] !== undefined) actual += m[1].replace(/\$(\w+)/g, (_, v) => valores[v]);
            else if (actual) { textos.push(actual); actual = ''; }
            if (m[0] === '])') break;
        }
        const [titulo, ...parrafos] = textos;
        return { titulo, parrafos };
    });
}

test('la política del panel y la de la app dicen exactamente lo mismo', () => {
    assert.equal(DART.match(/const versionPoliticaDatos = '([^']+)'/)[1], politica.VERSION, 'misma versión');
    assert.equal(DART.match(/const correoDatosPersonales = '([^']+)'/)[1], politica.CORREO, 'mismo correo');
    assert.deepEqual(seccionesDeLaApp(), politica.SECCIONES);
});

test('/privacidad es pública y cita la ley, los derechos y los plazos', async () => {
    const res = await request(app).get('/privacidad');
    assert.equal(res.status, 200);
    assert.equal((res.text.match(/<h1[\s>]/g) || []).length, 1);
    politica.SECCIONES.forEach((s) => assert.ok(res.text.includes(s.titulo), s.titulo));
    assert.match(res.text, /Ley 1581 de 2012/);
    assert.match(res.text, /artículo 8/);
    assert.match(res.text, /10 días hábiles/);
    assert.match(res.text, /Superintendencia de Industria y Comercio/);
});

test('el inicio de sesión y las pantallas del panel enlazan la política', async () => {
    const login = (await request(app).get('/login')).text;
    assert.match(login, /href="\/privacidad"/);
});
