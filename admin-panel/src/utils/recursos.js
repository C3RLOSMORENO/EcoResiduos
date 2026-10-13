// Archivos estáticos con caché larga. Cada URL lleva un número de versión
// sacado del contenido del archivo (?v=…): el navegador guarda el archivo un
// año sin volver a preguntar y, cuando el archivo cambia, cambia la URL y se
// descarga el nuevo. Sin ?v= se revalida en cada visita (con ETag, casi
// siempre un 304 sin contenido).
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const PUBLICO = path.join(__dirname, '..', 'public');
const MODULOS = path.join(__dirname, '..', '..', 'node_modules');

// Librerías de terceros servidas desde el propio panel (versión fija en
// package.json) en lugar de un CDN: la CSP solo permite scripts propios.
const LIBRERIAS = {
    '/vendor/chart.umd.js': path.join(MODULOS, 'chart.js', 'dist', 'chart.umd.js'),
    '/vendor/driver.js': path.join(MODULOS, 'driver.js', 'dist', 'driver.js.iife.js'),
    '/vendor/supabase.js': path.join(MODULOS, '@supabase', 'supabase-js', 'dist', 'umd', 'supabase.js')
};

const UN_ANO_S = 365 * 24 * 60 * 60;
const CACHE_LARGA = `public, max-age=${UN_ANO_S}, immutable`;
const CACHE_REVALIDAR = 'public, max-age=0, must-revalidate';

// La versión se recalcula solo si el archivo cambió (fecha y tamaño): en
// desarrollo, con «npm run dev:css» corriendo, cada cambio de estilos llega
// con una URL nueva sin reiniciar el servidor.
const versiones = new Map();

/**
 * @param {string} ruta Ruta pública, por ejemplo /css/style.css.
 * @returns {?string} Ruta del archivo en disco, o null si queda fuera de la carpeta pública.
 */
function archivoDe(ruta) {
    if (LIBRERIAS[ruta]) return LIBRERIAS[ruta];
    const archivo = path.join(PUBLICO, path.normalize(ruta));
    return archivo.startsWith(PUBLICO) ? archivo : null;
}

/**
 * Huella corta del contenido del archivo, guardada mientras el archivo no cambie.
 *
 * @param {string} archivo Ruta del archivo en disco.
 * @returns {?string} Los primeros 12 caracteres del SHA-256, o null si el archivo no existe.
 */
function version(archivo) {
    let datos;
    try {
        datos = fs.statSync(archivo);
    } catch {
        return null;
    }
    const huella = `${datos.mtimeMs}:${datos.size}`;
    const guardada = versiones.get(archivo);
    if (guardada && guardada.huella === huella) return guardada.version;
    const nueva = crypto.createHash('sha256').update(fs.readFileSync(archivo)).digest('hex').slice(0, 12);
    versiones.set(archivo, { huella, version: nueva });
    return nueva;
}

/**
 * URL de un archivo estático con su versión: recurso('/css/style.css') →
 * '/css/style.css?v=3f2a…'. Si el archivo no existe, la ruta queda igual.
 *
 * @param {string} ruta
 * @returns {string}
 */
function recurso(ruta) {
    const archivo = archivoDe(ruta);
    const v = archivo && version(archivo);
    return v ? `${ruta}?v=${v}` : ruta;
}

/**
 * Caché larga si la URL trae versión; si no, revalidar en cada visita.
 *
 * @param {import('express').Request} req
 * @returns {string} Valor para la cabecera Cache-Control.
 */
function cacheSegunVersion(req) {
    return req.query && req.query.v ? CACHE_LARGA : CACHE_REVALIDAR;
}

module.exports = { recurso, cacheSegunVersion, LIBRERIAS, PUBLICO, CACHE_LARGA, CACHE_REVALIDAR };
