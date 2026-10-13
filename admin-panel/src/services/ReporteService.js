const supabase = require('../config/supabase');
const { MUNICIPIOS, municipioAdmitido } = require('../utils/municipios');
const { CATEGORIAS_CATALOGO, UNIDADES, etiquetaCategoria, unidadCorta } = require('../utils/formato');
const { rangoBogota } = require('../utils/fechas');
const { errorDeBase } = require('../utils/errores');

const OTRO = 'Otro / sin dato';
const LOTE = 1000;
// Orden de las columnas de unidades; las desconocidas van al final.
const ORDEN_UNIDADES = Object.keys(UNIDADES);

/**
 * PostgREST devuelve máximo 1000 filas por consulta: se lee por lotes.
 *
 * @param {() => object} construir Crea la consulta de nuevo en cada lote, sin .range().
 * @returns {Promise<object[]>} Todas las filas.
 * @throws {Error} Si falla alguno de los lotes.
 */
async function leerTodo(construir) {
    const filas = [];
    for (let desde = 0; ; desde += LOTE) {
        const { data, error } = await construir().range(desde, desde + LOTE - 1);
        if (error) throw errorDeBase('No pudimos armar el reporte.', error);
        filas.push(...(data || []));
        if (!data || data.length < LOTE) return filas;
    }
}

const categoriaDe = (s) => String((s.materiales_residuos && s.materiales_residuos.categoria) || '').toUpperCase() || 'SIN_CATEGORIA';
const unidadDe = (s) => String(s.unidad_medida || '').toUpperCase() || 'SIN_UNIDAD';

/**
 * @param {string} municipio
 * @param {string[]} categorias
 * @param {string[]} unidades
 * @returns {object} Una fila del reporte con todos los conteos en 0.
 */
function filaVacia(municipio, categorias, unidades) {
    return {
        municipio,
        porCategoria: Object.fromEntries(categorias.map((c) => [c, 0])),
        confirmadas: 0,
        sinConfirmar: 0,
        porUnidad: Object.fromEntries(unidades.map((u) => [u, 0]))
    };
}

/**
 * Agrega las solicitudes por municipio. Cuenta recolecciones por categoría y
 * suma las cantidades declaradas por separado en cada unidad: nunca se
 * convierten ni se mezclan unidades. Es una función pura para poder probar
 * las reglas sin base de datos.
 *
 * @param {object[]} confirmadas Solicitudes con confirmado_at.
 * @param {object[]} sinConfirmar Recolectadas que siguen sin confirmar.
 * @returns {{categorias: object[], unidades: object[], filas: object[], total: object, hayOtro: boolean}}
 */
function agregar(confirmadas, sinConfirmar) {
    const extras = [...new Set(confirmadas.map(categoriaDe).filter((c) => !CATEGORIAS_CATALOGO.includes(c)))];
    const categorias = [...CATEGORIAS_CATALOGO, ...extras];

    const presentes = new Set(confirmadas.map(unidadDe));
    const unidades = [
        ...ORDEN_UNIDADES.filter((u) => presentes.has(u)),
        ...[...presentes].filter((u) => !ORDEN_UNIDADES.includes(u)).sort()
    ];

    const filas = new Map([...MUNICIPIOS, OTRO].map((m) => [m, filaVacia(m, categorias, unidades)]));

    confirmadas.forEach((s) => {
        const fila = filas.get(municipioAdmitido(s.municipio) || OTRO);
        fila.porCategoria[categoriaDe(s)] += 1;
        fila.confirmadas += 1;
        fila.porUnidad[unidadDe(s)] += Number(s.cantidad_estimada) || 0;
    });

    sinConfirmar.forEach((s) => {
        filas.get(municipioAdmitido(s.municipio) || OTRO).sinConfirmar += 1;
    });

    const total = filaVacia('Total', categorias, unidades);
    filas.forEach((f) => {
        categorias.forEach((c) => { total.porCategoria[c] += f.porCategoria[c]; });
        unidades.forEach((u) => { total.porUnidad[u] += f.porUnidad[u]; });
        total.confirmadas += f.confirmadas;
        total.sinConfirmar += f.sinConfirmar;
    });

    const otro = filas.get(OTRO);
    const hayOtro = otro.confirmadas > 0 || otro.sinConfirmar > 0;

    return {
        categorias: categorias.map((c) => ({ clave: c, etiqueta: c === 'SIN_CATEGORIA' ? 'Sin categoría' : etiquetaCategoria(c) })),
        unidades: unidades.map((u) => ({ clave: u, etiqueta: u === 'SIN_UNIDAD' ? 'sin unidad' : unidadCorta(u) })),
        filas: [...filas.values()].filter((f) => f.municipio !== OTRO || hayOtro),
        total,
        hayOtro
    };
}

const reporteService = {
    agregar,
    OTRO,

    /**
     * Recolecciones confirmadas por municipio y categoría, más las que siguen
     * sin confirmar.
     *
     * @param {{desde?: string, hasta?: string, categoria?: string}} filtros Resultado de filtrosReporte.
     * @returns {Promise<object>} El resultado de agregar.
     * @throws {Error} Si falla alguna consulta.
     */
    async reciclajePorMunicipio(filtros) {
        const fechas = rangoBogota(filtros.desde, filtros.hasta);
        const embebido = filtros.categoria ? 'materiales_residuos!inner(categoria)' : 'materiales_residuos(categoria)';

        // Confirmadas por el generador o solas a las 72 h: tienen confirmado_at.
        const confirmadas = await leerTodo(() => {
            let consulta = supabase
                .from('solicitudes_recoleccion')
                .select(`id, municipio, cantidad_estimada, unidad_medida, confirmado_at, ${embebido}`)
                .not('confirmado_at', 'is', null);
            if (filtros.categoria) consulta = consulta.eq('materiales_residuos.categoria', filtros.categoria);
            if (fechas.gte) consulta = consulta.gte('confirmado_at', fechas.gte);
            if (fechas.lt) consulta = consulta.lt('confirmado_at', fechas.lt);
            return consulta.order('id', { ascending: true });
        });

        // Si pg_cron no está activo, estas nunca se confirman solas: se
        // muestran aparte para que el reporte no esconda la diferencia.
        const sinConfirmar = await leerTodo(() => {
            let consulta = supabase
                .from('solicitudes_recoleccion')
                .select(`id, municipio, recolectado_at, ${embebido}`)
                .not('recolectado_at', 'is', null)
                .is('confirmado_at', null)
                .eq('problema_reportado', false);
            if (filtros.categoria) consulta = consulta.eq('materiales_residuos.categoria', filtros.categoria);
            if (fechas.gte) consulta = consulta.gte('recolectado_at', fechas.gte);
            if (fechas.lt) consulta = consulta.lt('recolectado_at', fechas.lt);
            return consulta.order('id', { ascending: true });
        });

        return agregar(confirmadas, sinConfirmar);
    }
};

module.exports = reporteService;
