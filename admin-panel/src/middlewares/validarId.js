// Los identificadores de la base son enteros positivos. Cualquier otra cosa
// en la URL (/materiales/edit/abc, /autoridades/edit/-1) responde 404 aquí,
// sin llegar a Supabase ni mostrar el error de PostgreSQL.
const ENTERO_POSITIVO = /^[1-9]\d{0,14}$/;

function validarId(req, res, next, valor) {
    if (ENTERO_POSITIVO.test(String(valor))) return next();
    if (req.get('X-Requested-With') === 'fetch') {
        return res.status(404).json({ ok: false, mensaje: 'No encontramos ese registro.' });
    }
    return res.status(404).render('404', { titulo: 'Página no encontrada' });
}

// Registra la validación para cada parámetro de identificador del router.
function validarIds(router, ...parametros) {
    parametros.forEach((nombre) => router.param(nombre, validarId));
}

module.exports = { validarId, validarIds };
