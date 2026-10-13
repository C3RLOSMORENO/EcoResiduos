// Los identificadores de la base son enteros positivos. Cualquier otra cosa
// en la URL (/materiales/edit/abc, /autoridades/edit/-1) responde 404 aquí,
// sin llegar a Supabase ni mostrar el error de PostgreSQL.
const ENTERO_POSITIVO = /^[1-9]\d{0,14}$/;

/**
 * Responde 404 si el identificador no es un entero positivo. Se registra con
 * router.param, que pasa el valor del parámetro como cuarto argumento.
 *
 * @param {import('express').Request} req
 * @param {import('express').Response} res
 * @param {import('express').NextFunction} next
 * @param {string} valor
 */
function validarId(req, res, next, valor) {
    if (ENTERO_POSITIVO.test(String(valor))) return next();
    if (req.get('X-Requested-With') === 'fetch') {
        return res.status(404).json({ ok: false, mensaje: 'No encontramos ese registro.' });
    }
    return res.status(404).render('404', { titulo: 'Página no encontrada' });
}

/**
 * Registra la validación para cada parámetro de identificador del router.
 *
 * @param {import('express').Router} router
 * @param {...string} parametros Nombres de los parámetros (id, materialId…).
 */
function validarIds(router, ...parametros) {
    parametros.forEach((nombre) => router.param(nombre, validarId));
}

module.exports = { validarId, validarIds };
