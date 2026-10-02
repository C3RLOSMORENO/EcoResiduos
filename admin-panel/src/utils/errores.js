// Errores de Supabase convertidos en mensajes para el administrador. El
// detalle técnico (código y texto de PostgreSQL) va al registro del
// servidor, nunca a la pantalla: ahí revelaría tablas, columnas y
// restricciones de la base.
const CAUSAS_POR_CODIGO = {
    23505: 'Ya existe un registro con esos datos (por ejemplo, el mismo código o NIT).',
    23503: 'Tiene registros relacionados que lo impiden.',
    23502: 'Falta un dato obligatorio.',
    22001: 'Uno de los textos es demasiado largo.',
    '22P02': 'Uno de los datos no tiene el formato esperado.',
    23514: 'Uno de los datos no cumple las reglas de la base.'
};

// mensaje: qué no se pudo hacer, en una frase que termina en punto
// («No pudimos guardar el material.»).
function errorDeBase(mensaje, error) {
    const codigo = error && error.code ? String(error.code) : '';
    const detalle = error ? [codigo, error.message].filter(Boolean).join(' ') : 'sin detalle';
    console.error(`${mensaje} [${detalle}]`);

    // Las funciones de la base lanzan sus propios mensajes en español con
    // RAISE EXCEPTION (código P0001): esos sí son para el usuario.
    if (codigo === 'P0001' && error.message) return new Error(error.message);

    const causa = CAUSAS_POR_CODIGO[codigo];
    return new Error(causa ? `${mensaje} ${causa}` : `${mensaje} Intenta de nuevo en unos minutos.`);
}

// El registro no existe: el controlador responde 404 en lugar de un error.
function noEncontrado(mensaje) {
    const error = new Error(mensaje);
    error.codigo = 'NO_ENCONTRADO';
    return error;
}

// Una pantalla de detalle o edición que no cargó: 404 si el registro no
// existe; si falló la base, el error dentro del panel con «Reintentar», en la
// misma dirección (antes se volvía a la lista y se perdía la página).
// que: lo que no cargó, en minúscula («el gestor», «la solicitud 7»).
function responderErrorCarga(res, next, err, { activeTab, que, volver }) {
    if (err && err.codigo === 'NO_ENCONTRADO') return next();
    const titulo = `No pudimos cargar ${que}`;
    const mensaje = err && err.message;
    return res.status(503).render('error-carga', {
        activeTab,
        titulo,
        volver,
        // El mensaje del servicio solo se muestra si dice algo más que el
        // título (por ejemplo, un mensaje propio de una función de la base).
        detalle: mensaje && !mensaje.startsWith('No pudimos cargar') ? mensaje : ''
    });
}

// Una lista (o el inicio, o el reporte) con su estado de error: si la
// consulta falla, la misma pantalla sin datos y el mensaje en errorCarga, que
// la vista muestra con «Reintentar».
// comunes: lo que la vista lleva siempre (título, pestaña, filtros…).
// cargar: función que trae los datos; vacio: su reemplazo si falla.
async function renderLista(res, vista, { comunes, cargar, vacio }) {
    let datos;
    try {
        datos = await cargar();
    } catch (err) {
        console.error(`No cargó la vista ${vista}:`, err);
        return res.status(500).render(vista, { ...comunes, ...vacio, errorCarga: err.message });
    }
    return res.render(vista, { ...comunes, ...datos, errorCarga: null });
}

module.exports = { errorDeBase, noEncontrado, responderErrorCarga, renderLista };
