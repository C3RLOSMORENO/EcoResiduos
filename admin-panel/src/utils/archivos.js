// Límites de tamaño de los PDF que pasan por el panel.
//
// En Vercel (y en otros servicios serverless) el cuerpo de una petición y el
// de una respuesta no pueden pasar de 4,5 MB. Por eso el panel sube como
// máximo 4 MB y, para ver un PDF más grande (los que suben las empresas desde
// la app pueden llegar a 10 MB), redirige a un enlace firmado de Supabase que
// vence en dos minutos, en lugar de enviarlo por la función.
const TAMANO_MAXIMO_SUBIDA = 4 * 1024 * 1024;
const TAMANO_MAXIMO_RESPUESTA = 4 * 1024 * 1024;
const VIGENCIA_ENLACE_S = 120;

/**
 * El archivo listo para el controlador: el contenido si cabe en una
 * respuesta, o un enlace firmado si no.
 *
 * @param {import('@supabase/supabase-js').SupabaseClient} supabase
 * @param {string} bucket
 * @param {string} ruta Ruta del archivo dentro del bucket.
 * @param {Blob} archivo Lo que entregó storage.download.
 * @returns {Promise<{buffer?: Buffer, url?: string}>}
 * @throws {Error} Si el archivo es grande y no se pudo firmar el enlace.
 */
async function entregaDePdf(supabase, bucket, ruta, archivo) {
    const buffer = Buffer.from(await archivo.arrayBuffer());
    if (buffer.length <= TAMANO_MAXIMO_RESPUESTA) return { buffer };
    const { data, error } = await supabase.storage.from(bucket).createSignedUrl(ruta, VIGENCIA_ENLACE_S);
    if (error || !data || !data.signedUrl) {
        console.error(`No se firmó el enlace de ${bucket}/${ruta}: ${error ? error.message : 'sin URL'}`);
        throw new Error('El PDF es muy grande y no pudimos generar el enlace para abrirlo. Intenta de nuevo.');
    }
    return { url: data.signedUrl };
}

module.exports = { TAMANO_MAXIMO_SUBIDA, TAMANO_MAXIMO_RESPUESTA, VIGENCIA_ENLACE_S, entregaDePdf };
