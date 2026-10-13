// Foto de perfil (logo) y portada que cada gestor pone desde la app. Viven en
// el bucket público «fotos_perfil» de Supabase y la tabla guarda solo la ruta
// (migración 20261006000000_foto_perfil_y_portada.sql).
const { faltaEnEsquema } = require('./web');

const BUCKET = 'fotos_perfil';

// La misma forma que exige la restricción de la base: <uid>/<carpeta>/<marca>.<ext>.
// Una ruta con otra forma no se convierte en URL.
const RUTA_VALIDA = /^[0-9a-f-]{36}\/(perfil|portada)\/[0-9]+\.(jpg|jpeg|png|webp)$/;

const COLUMNAS = {
    perfil: 'foto_perfil_path',
    portada: 'portada_path'
};

/**
 * URL pública de una ruta del bucket.
 *
 * @param {?string} ruta Valor de foto_perfil_path o portada_path.
 * @returns {?string} La URL, o null si no hay ruta o no tiene la forma esperada.
 */
function urlFotoPerfil(ruta) {
    if (typeof ruta !== 'string' || !RUTA_VALIDA.test(ruta)) return null;
    let origen;
    try {
        origen = new URL(process.env.SUPABASE_URL).origin;
    } catch {
        return null;
    }
    return `${origen}/storage/v1/object/public/${BUCKET}/${ruta}`;
}

/**
 * Las consultas con columnas escritas a mano piden también la foto. Si la
 * migración aún no se ha ejecutado, la columna no existe: se repite la
 * consulta sin ella y el panel sigue funcionando, con iniciales.
 *
 * @param {(columnaExtra: string) => Promise<object>} consultar Arma y ejecuta la
 *     consulta; recibe el texto que se agrega a la lista de columnas.
 * @returns {Promise<object>} La respuesta de Supabase ({ data, error, … }).
 */
async function conFotoSiExiste(consultar) {
    const respuesta = await consultar(`, ${COLUMNAS.perfil}`);
    if (respuesta && respuesta.error && faltaEnEsquema(respuesta.error)) return consultar('');
    return respuesta;
}

module.exports = { BUCKET, COLUMNAS, RUTA_VALIDA, urlFotoPerfil, conFotoSiExiste };
