// El panel y la app usan la misma paleta Material 3: la fuente es
// app/lib/theme/eco_colors.dart. Estas pruebas fallan si alguien cambia un
// color en un lado y no en el otro, o si un par de colores deja de cumplir el
// contraste de WCAG 2.1 AA (Resolución 1519 de 2020).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const DART = fs.readFileSync(path.join(__dirname, '..', '..', 'app', 'lib', 'theme', 'eco_colors.dart'), 'utf8');
const CSS = fs.readFileSync(path.join(__dirname, '..', 'src', 'public', 'css', 'input.css'), 'utf8');

const kebab = (s) => s.replace(/[A-Z]/g, (m) => `-${m.toLowerCase()}`);
// 0xAARRGGBB de Flutter a #RRGGBB.
const hex = (argb) => `#${argb.slice(4).toUpperCase()}`;

/** Texto de una llamada de Dart, desde su nombre hasta el paréntesis que la cierra. */
function bloqueDart(inicio) {
    const i = DART.indexOf(inicio);
    assert.ok(i >= 0, `falta ${inicio} en eco_colors.dart`);
    let nivel = 0;
    for (let j = DART.indexOf('(', i); j < DART.length; j++) {
        if (DART[j] === '(') nivel++;
        if (DART[j] === ')' && --nivel === 0) return DART.slice(i, j);
    }
    throw new Error(`bloque sin cerrar: ${inicio}`);
}

/** Variables CSS que debería tener el panel para un tema de la app. */
function paletaDeLaApp(esquema, colores) {
    const t = {};
    for (const m of bloqueDart(`const ${esquema} = ColorScheme(`).matchAll(/(\w+): Color\(0x([0-9A-Fa-f]{8})\)/g)) {
        const nombre = m[1] === 'onInverseSurface' ? 'inverse-on-surface' : kebab(m[1]);
        t[`--md-sys-color-${nombre}`] = hex(`0x${m[2]}`);
    }
    for (const m of bloqueDart(`const ${colores} = EcoColores(`).matchAll(/(Categoria|EstadoSolicitud)\.(\w+):\s*CategoriaColor\(([\s\S]*?)\n\s*\)/g)) {
        const base = `${m[1] === 'Categoria' ? '--eco-cat-' : '--eco-estado-'}${kebab(m[2])}`;
        const c = Object.fromEntries([...m[3].matchAll(/(\w+): Color\(0x([0-9A-Fa-f]{8})\)/g)].map((x) => [x[1], hex(`0x${x[2]}`)]));
        Object.assign(t, { [`${base}-color`]: c.color, [`${base}-on`]: c.onColor, [`${base}-container`]: c.container, [`${base}-on-container`]: c.onContainer });
    }
    return t;
}

/** Variables con valor hexadecimal de un tramo del CSS. */
function variablesCss(desde, hasta) {
    const tramo = CSS.slice(desde, hasta);
    return Object.fromEntries([...tramo.matchAll(/(--[\w-]+):\s*(#[0-9A-Fa-f]{6})\b/g)].map((m) => [m[1], m[2].toUpperCase()]));
}

const finClaro = CSS.indexOf('@media (prefers-color-scheme: dark)');
const iniSistema = CSS.indexOf(':root:not([data-tema="claro"]) {');
const iniBoton = CSS.indexOf(':root[data-tema="oscuro"],');
const TEMAS = {
    claro: { css: variablesCss(0, finClaro), app: paletaDeLaApp('ecoLightColorScheme', 'ecoColoresLight') },
    'oscuro del sistema': { css: variablesCss(iniSistema, CSS.indexOf('}', iniSistema)), app: paletaDeLaApp('ecoDarkColorScheme', 'ecoColoresDark') },
    'oscuro del botón': { css: variablesCss(iniBoton, CSS.indexOf('}', iniBoton)), app: paletaDeLaApp('ecoDarkColorScheme', 'ecoColoresDark') }
};

test('cada tema del panel tiene los mismos colores que la app', () => {
    for (const [nombre, { css, app }] of Object.entries(TEMAS)) {
        assert.ok(Object.keys(app).length > 80, `la paleta de la app (${nombre}) se leyó completa`);
        for (const [variable, valor] of Object.entries(app)) {
            if (!(variable in css)) continue; // la app tiene roles que el panel no usa
            assert.equal(css[variable], valor, `${variable} en el tema ${nombre}`);
        }
    }
});

test('el modo oscuro es el mismo con la preferencia del sistema y con el botón', () => {
    assert.deepEqual(TEMAS['oscuro del sistema'].css, TEMAS['oscuro del botón'].css);
});

const luminancia = (h) => {
    const [r, g, b] = [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16) / 255)
        .map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
const contraste = (a, b) => {
    const [x, y] = [luminancia(a), luminancia(b)].sort((p, q) => q - p);
    return (x + 0.05) / (y + 0.05);
};

test('los pares de texto y fondo cumplen el contraste de WCAG 2.1 AA', () => {
    // 4.5:1 para texto (1.4.3) y 3:1 para el borde de un control (1.4.11).
    // outline-variant no se mide: en Material 3 es solo para divisores decorativos.
    const pares = [
        ['primary', 'on-primary', 4.5], ['primary-container', 'on-primary-container', 4.5],
        ['secondary-container', 'on-secondary-container', 4.5], ['tertiary-container', 'on-tertiary-container', 4.5],
        ['error', 'on-error', 4.5], ['error-container', 'on-error-container', 4.5],
        ['surface', 'on-surface', 4.5], ['surface', 'on-surface-variant', 4.5],
        ['surface-container', 'on-surface-variant', 4.5], ['surface', 'primary', 4.5],
        ['inverse-surface', 'inverse-on-surface', 4.5], ['inverse-surface', 'inverse-primary', 4.5],
        ['surface', 'outline', 3]
    ];
    for (const [nombre, { css }] of Object.entries(TEMAS)) {
        for (const [fondo, texto, minimo] of pares) {
            const r = contraste(css[`--md-sys-color-${fondo}`], css[`--md-sys-color-${texto}`]);
            assert.ok(r >= minimo, `${texto} sobre ${fondo} en el tema ${nombre}: ${r.toFixed(2)}:1, mínimo ${minimo}:1`);
        }
    }
});

test('en el modo oscuro las tarjetas son más claras que el fondo, como pide Material 3', () => {
    const oscuro = TEMAS['oscuro del botón'].css;
    assert.match(CSS.slice(iniBoton, CSS.indexOf('}', iniBoton)), /--eco-tarjeta: var\(--md-sys-color-surface-container-low\)/);
    assert.ok(luminancia(oscuro['--md-sys-color-surface-container-low']) > luminancia(oscuro['--md-sys-color-surface']));
    assert.ok(!/bg-surface-container-lowest/.test(CSS), 'las tarjetas usan --eco-tarjeta');
});
