// Misma lista que la app (app/lib/utils/municipios.dart).
const MUNICIPIOS = [
    'Bucaramanga',
    'Floridablanca',
    'Girón',
    'Piedecuesta',
    'Barrancabermeja',
    'Sabana de Torres'
];

function normalizar(texto) {
    return String(texto || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/\s+/g, ' ')
        .trim()
        .toLowerCase();
}

// Municipio admitido que corresponde al texto sin importar mayúsculas, tildes
// ni espacios; null si no es uno de los 6.
function municipioAdmitido(texto) {
    const buscado = normalizar(texto);
    if (!buscado) return null;
    return MUNICIPIOS.find((m) => normalizar(m) === buscado) || null;
}

// La base guarda el municipio como lo escribió cada cliente (la app y el panel
// lo pasan a mayúsculas, con o sin tilde). Para filtrar en la consulta se
// prueban las formas conocidas.
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

// Forma en que el panel guarda el municipio (igual que la app al registrar).
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
