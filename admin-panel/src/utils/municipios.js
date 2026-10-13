// Misma lista que la app (app/lib/utils/municipios.dart).
const MUNICIPIOS = [
    'Bucaramanga',
    'Floridablanca',
    'Girón',
    'Piedecuesta',
    'Barrancabermeja',
    'Sabana de Torres'
];

/**
 * Texto en minúsculas, sin tildes y con un solo espacio entre palabras, para
 * comparar nombres escritos de distintas formas.
 *
 * @param {string} texto
 * @returns {string}
 */
function normalizar(texto) {
    return String(texto || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/\s+/g, ' ')
        .trim()
        .toLowerCase();
}

/**
 * Municipio admitido que corresponde al texto, sin importar mayúsculas, tildes
 * ni espacios.
 *
 * @param {string} texto Nombre escrito por el usuario o leído de la base.
 * @returns {?string} El nombre como aparece en MUNICIPIOS, o null si no es uno de los 6.
 */
function municipioAdmitido(texto) {
    const buscado = normalizar(texto);
    if (!buscado) return null;
    return MUNICIPIOS.find((m) => normalizar(m) === buscado) || null;
}

/**
 * La base guarda el municipio como lo escribió cada cliente (la app y el panel
 * lo pasan a mayúsculas, con o sin tilde). Para filtrar en la consulta se
 * prueban las formas conocidas.
 *
 * @param {string} nombre Municipio tal como aparece en MUNICIPIOS.
 * @returns {string[]} Las formas distintas del nombre, sin repetidos.
 */
function variantesMunicipio(nombre) {
    const sinTildes = nombre.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
    return [...new Set([
        nombre,
        nombre.toUpperCase(),
        nombre.toLowerCase(),
        sinTildes,
        sinTildes.toUpperCase(),
        sinTildes.toLowerCase()
    ])];
}

/**
 * Forma en que el panel guarda el municipio (igual que la app al registrar).
 *
 * @param {string} texto
 * @returns {?string} El municipio en mayúsculas, o null si no es uno de los admitidos.
 */
function municipioParaGuardar(texto) {
    const admitido = municipioAdmitido(texto);
    return admitido ? admitido.toUpperCase() : null;
}

module.exports = {
    MUNICIPIOS,
    normalizar,
    municipioAdmitido,
    variantesMunicipio,
    municipioParaGuardar
};
