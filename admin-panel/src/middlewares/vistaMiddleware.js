const formato = require('../utils/formato');
const { MUNICIPIOS } = require('../utils/municipios');
const { jsonParaScript } = require('../utils/web');

// Ayudas y avisos disponibles en todas las vistas.
function vistaMiddleware(req, res, next) {
    res.locals.f = formato;
    res.locals.MUNICIPIOS = MUNICIPIOS;
    res.locals.jsonParaScript = jsonParaScript;
    res.locals.query = req.query || {};
    res.locals.rutaActual = req.path;

    // URL actual sin el aviso, para volver a ella después de una acción.
    const params = new URLSearchParams();
    Object.entries(req.query || {}).forEach(([k, v]) => {
        if (!['msg', 'type', 'success', 'error'].includes(k) && typeof v === 'string' && v) params.set(k, v);
    });
    const cadena = params.toString();
    res.locals.urlActual = (req.path || '/') + (cadena ? `?${cadena}` : '');

    const q = req.query || {};
    const texto = (valor) => String(Array.isArray(valor) ? valor[0] : valor).slice(0, 400);
    if (q.msg) {
        res.locals.aviso = { tipo: q.type === 'error' ? 'error' : 'exito', mensaje: texto(q.msg) };
    } else if (q.error) {
        res.locals.aviso = { tipo: 'error', mensaje: texto(q.error) };
    } else if (q.success) {
        res.locals.aviso = { tipo: 'exito', mensaje: texto(q.success) };
    } else {
        res.locals.aviso = null;
    }
    next();
}

module.exports = vistaMiddleware;
