const formato = require('../utils/formato');
const { MUNICIPIOS } = require('../utils/municipios');
const { jsonParaScript, PARAMETROS_AVISO, avisoAutentico } = require('../utils/web');
const { recurso } = require('../utils/recursos');
const { URL_ICONOS } = require('../utils/iconos');

// Avisos que arma el navegador (no el servidor), así que no pueden ir
// firmados: la URL solo trae el código y el texto vive aquí.
const AVISOS_FIJOS = {
    'sesion-vencida': { tipo: 'error', mensaje: 'Tu sesión venció por inactividad. Inicia sesión para continuar donde ibas.' },
    'clave-actualizada': { tipo: 'exito', mensaje: 'Contraseña actualizada. Ya puedes iniciar sesión.' }
};

// Ayudas y avisos disponibles en todas las vistas.
function vistaMiddleware(req, res, next) {
    res.locals.f = formato;
    res.locals.MUNICIPIOS = MUNICIPIOS;
    res.locals.jsonParaScript = jsonParaScript;
    res.locals.recurso = recurso;
    res.locals.urlIconos = URL_ICONOS;
    res.locals.query = req.query || {};
    res.locals.rutaActual = req.path;

    // URL actual sin el aviso, para volver a ella después de una acción.
    const params = new URLSearchParams();
    Object.entries(req.query || {}).forEach(([k, v]) => {
        if (!PARAMETROS_AVISO.includes(k) && typeof v === 'string' && v) params.set(k, v);
    });
    const cadena = params.toString();
    res.locals.urlActual = (req.path || '/') + (cadena ? `?${cadena}` : '');

    const q = req.query || {};
    const texto = (valor) => String(Array.isArray(valor) ? valor[0] : valor || '');
    res.locals.aviso = null;
    if (q.msg && avisoAutentico(texto(q.msg), texto(q.type), texto(q.firma))) {
        res.locals.aviso = { tipo: texto(q.type) === 'error' ? 'error' : 'exito', mensaje: texto(q.msg).slice(0, 400) };
    } else if (AVISOS_FIJOS[texto(q.aviso)]) {
        res.locals.aviso = AVISOS_FIJOS[texto(q.aviso)];
    }
    next();
}

module.exports = vistaMiddleware;
