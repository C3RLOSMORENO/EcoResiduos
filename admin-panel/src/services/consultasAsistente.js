// Consultas que el asistente puede pedir. Son de solo lectura y con
// parámetros cerrados: el modelo elige cuál usar y con qué filtros, pero nunca
// escribe SQL ni ve una tabla completa. De los ciudadanos solo salen conteos:
// sus datos personales (Ley 1581 de 2012) no se envían al modelo.
const supabase = require('../config/supabase');
const dashboardService = require('./DashboardService');
const reporteService = require('./ReporteService');
const { MUNICIPIOS, municipioAdmitido, variantesMunicipio } = require('../utils/municipios');
const { CATEGORIAS, ESTADOS_SOLICITUD, ESTADOS_GESTOR } = require('../utils/formato');
const { rangoBogota, haceDias } = require('../utils/fechas');
const { errorDeBase } = require('../utils/errores');

const DIAS_SIN_CERTIFICADO = 7;
const MAX_NOMBRES = 25;

/**
 * Error de un parámetro: se le devuelve al modelo para que se lo explique al
 * administrador, en lugar de consultar con un filtro que no existe.
 */
class ParametroInvalido extends Error {}

/**
 * @param {*} valor
 * @returns {?string} El municipio como aparece en MUNICIPIOS, o null si vino vacío.
 * @throws {ParametroInvalido} Si no es uno de los seis municipios.
 */
function municipioDe(valor) {
    if (!valor) return null;
    const admitido = municipioAdmitido(valor);
    if (!admitido) throw new ParametroInvalido(`«${valor}» no es uno de los municipios del proyecto (${MUNICIPIOS.join(', ')}).`);
    return admitido;
}

/**
 * @param {*} valor
 * @param {string[]} validos
 * @param {string} que Nombre del parámetro, para el mensaje.
 * @returns {?string} El valor en mayúsculas, o null si vino vacío.
 * @throws {ParametroInvalido} Si no está en la lista.
 */
function opcionDe(valor, validos, que) {
    if (!valor) return null;
    const clave = String(valor).trim().toUpperCase().replace(/\s+/g, '_');
    if (!validos.includes(clave)) throw new ParametroInvalido(`«${valor}» no es un ${que} válido (${validos.join(', ')}).`);
    return clave;
}

/**
 * Texto para buscar con ilike: sin los caracteres que PostgREST usa para
 * armar filtros (coma, paréntesis, %, *), para que no cambien la consulta.
 *
 * @param {*} valor
 * @returns {string}
 */
function textoBusqueda(valor) {
    return String(valor || '').replace(/[^\p{L}\p{N}\s.-]/gu, ' ').replace(/\s+/g, ' ').trim().slice(0, 60);
}

/**
 * @param {{count: ?number, error: ?object}} respuesta
 * @param {string} que Lo que se contaba, para el mensaje de error.
 * @returns {number}
 * @throws {Error} Si la consulta falló.
 */
function conteoDe({ count, error }, que) {
    if (error) throw errorDeBase(`No pudimos contar ${que}.`, error);
    return count || 0;
}

const herramientas = {
    resumen_general: {
        descripcion: 'Cifras generales del panel: solicitudes por estado, gestores por estado, materiales, autoridades, '
            + 'postulaciones (ofertas de los gestores), pendientes de acción y solicitudes por municipio. Úsala para preguntas '
            + 'generales («¿cómo vamos?», «dame un resumen») o cuando no haya una herramienta más específica.',
        parametros: {},
        async ejecutar() {
            const datos = await dashboardService.getDashboardKpis();
            const porMunicipio = Object.fromEntries(datos.chartData.municipiosLabels
                .map((m, i) => [m, datos.chartData.municipiosData[i]]));
            return {
                cifras: datos.kpis,
                pendientes_de_accion: datos.pendientesAccion,
                solicitudes_por_municipio: porMunicipio,
                ...(datos.errores.length ? { no_se_pudo_contar: datos.errores } : {})
            };
        }
    },

    contar_gestores: {
        descripcion: 'Cuenta las empresas gestoras y da sus nombres. Filtra por estado de verificación, municipio, '
            + 'material que reciben (nombre o código, por ejemplo «aceite», «llantas», «Y8») o categoría de residuo.',
        parametros: {
            estado: { tipo: 'string', valores: ESTADOS_GESTOR, descripcion: 'Estado de verificación del gestor.' },
            municipio: { tipo: 'string', valores: MUNICIPIOS, descripcion: 'Municipio del gestor.' },
            material: { tipo: 'string', descripcion: 'Nombre o código del material que recibe el gestor.' },
            categoria: { tipo: 'string', valores: Object.keys(CATEGORIAS), descripcion: 'Categoría del material que recibe.' }
        },
        async ejecutar(args) {
            const estado = opcionDe(args.estado, ESTADOS_GESTOR, 'estado de gestor');
            const municipio = municipioDe(args.municipio);
            const categoria = opcionDe(args.categoria, Object.keys(CATEGORIAS), 'categoría');
            const material = textoBusqueda(args.material);

            if (!material && !categoria) {
                let consulta = supabase.from('perfiles_gestor')
                    .select('id, razon_social, municipio, estado_verificacion', { count: 'exact' });
                if (estado) consulta = consulta.eq('estado_verificacion', estado);
                if (municipio) consulta = consulta.in('municipio', variantesMunicipio(municipio));
                const respuesta = await consulta.order('razon_social', { ascending: true }).limit(MAX_NOMBRES);
                const total = conteoDe(respuesta, 'los gestores');
                return {
                    total,
                    gestores: (respuesta.data || []).map((g) => ({ nombre: g.razon_social, municipio: g.municipio, estado: g.estado_verificacion })),
                    ...(total > MAX_NOMBRES ? { nota: `Solo se listan los primeros ${MAX_NOMBRES} nombres.` } : {})
                };
            }

            // Por material: se parte de gestor_material, y un gestor que recibe
            // varios materiales que coinciden se cuenta una sola vez.
            let consulta = supabase.from('gestor_material')
                .select('verificado, materiales_residuos!inner(codigo, nombre_comun, categoria), '
                    + 'perfiles_gestor!inner(id, razon_social, municipio, estado_verificacion)');
            if (categoria) consulta = consulta.eq('materiales_residuos.categoria', categoria);
            if (material) consulta = consulta.or(`nombre_comun.ilike.%${material}%,codigo.ilike.%${material}%`, { referencedTable: 'materiales_residuos' });
            if (estado) consulta = consulta.eq('perfiles_gestor.estado_verificacion', estado);
            if (municipio) consulta = consulta.in('perfiles_gestor.municipio', variantesMunicipio(municipio));
            const { data, error } = await consulta.limit(1000);
            if (error) throw errorDeBase('No pudimos contar los gestores por material.', error);

            const porGestor = new Map();
            (data || []).forEach((fila) => {
                const g = fila.perfiles_gestor;
                if (!g) return;
                const actual = porGestor.get(g.id) || { nombre: g.razon_social, municipio: g.municipio, estado: g.estado_verificacion, materiales: [] };
                const m = fila.materiales_residuos || {};
                actual.materiales.push(`${m.nombre_comun}${fila.verificado ? '' : ' (sin verificar)'}`);
                porGestor.set(g.id, actual);
            });
            const gestores = [...porGestor.values()].sort((a, b) => String(a.nombre).localeCompare(String(b.nombre), 'es'));
            return {
                total: gestores.length,
                gestores: gestores.slice(0, MAX_NOMBRES),
                ...(gestores.length > MAX_NOMBRES ? { nota: `Solo se listan los primeros ${MAX_NOMBRES} nombres.` } : {})
            };
        }
    },

    contar_solicitudes: {
        descripcion: 'Cuenta las solicitudes de recolección (también llamadas publicaciones) por estado. Estados: PUBLICADO '
            + '(abierta, esperando ofertas), EN_NEGOCIACION (con gestor elegido, en proceso), RECOLECTADO (completada, ya '
            + 'recogida) y CANCELADO. Filtra por municipio, categoría, material, rango de fechas de creación y problemas reportados.',
        parametros: {
            estado: { tipo: 'string', valores: ESTADOS_SOLICITUD, descripcion: 'Si se omite, devuelve el conteo de cada estado.' },
            municipio: { tipo: 'string', valores: MUNICIPIOS, descripcion: 'Municipio de la recolección.' },
            categoria: { tipo: 'string', valores: Object.keys(CATEGORIAS), descripcion: 'Categoría del residuo.' },
            material: { tipo: 'string', descripcion: 'Nombre o código del material.' },
            desde: { tipo: 'string', descripcion: 'Primer día, AAAA-MM-DD (fecha de publicación).' },
            hasta: { tipo: 'string', descripcion: 'Último día incluido, AAAA-MM-DD.' },
            con_problema: { tipo: 'boolean', descripcion: 'true: solo las que tienen un problema reportado sin resolver.' }
        },
        async ejecutar(args) {
            const estado = opcionDe(args.estado, ESTADOS_SOLICITUD, 'estado de solicitud');
            const municipio = municipioDe(args.municipio);
            const categoria = opcionDe(args.categoria, Object.keys(CATEGORIAS), 'categoría');
            const material = textoBusqueda(args.material);
            const fechas = rangoBogota(args.desde, args.hasta);
            const conMaterial = categoria || material;

            const contarEstado = (e) => {
                const embebido = conMaterial ? ', materiales_residuos!inner(categoria)' : '';
                let consulta = supabase.from('solicitudes_recoleccion').select(`id${embebido}`, { count: 'exact', head: true }).eq('estado', e);
                if (municipio) consulta = consulta.in('municipio', variantesMunicipio(municipio));
                if (categoria) consulta = consulta.eq('materiales_residuos.categoria', categoria);
                if (material) consulta = consulta.or(`nombre_comun.ilike.%${material}%,codigo.ilike.%${material}%`, { referencedTable: 'materiales_residuos' });
                if (fechas.gte) consulta = consulta.gte('created_at', fechas.gte);
                if (fechas.lt) consulta = consulta.lt('created_at', fechas.lt);
                if (args.con_problema === true) consulta = consulta.eq('problema_reportado', true);
                return consulta;
            };

            const estados = estado ? [estado] : ESTADOS_SOLICITUD;
            const conteos = await Promise.all(estados.map(async (e) => [e, conteoDe(await contarEstado(e), 'las solicitudes')]));
            const porEstado = Object.fromEntries(conteos);
            return {
                total: conteos.reduce((suma, [, n]) => suma + n, 0),
                por_estado: porEstado,
                filtros_aplicados: {
                    municipio, categoria, material: material || null,
                    desde: fechas.desde, hasta: fechas.hasta, con_problema: args.con_problema === true
                }
            };
        }
    },

    cantidades_recolectadas: {
        descripcion: 'Recolecciones confirmadas por municipio: cuántas hubo, de qué categorías y las cantidades declaradas '
            + 'sumadas por unidad (KG, TON, L, M3; las unidades nunca se suman entre sí). Incluye las recolectadas que '
            + 'siguen sin confirmar. Es el mismo cálculo de la pantalla Reportes.',
        parametros: {
            desde: { tipo: 'string', descripcion: 'Primer día, AAAA-MM-DD (fecha de confirmación).' },
            hasta: { tipo: 'string', descripcion: 'Último día incluido, AAAA-MM-DD.' },
            categoria: { tipo: 'string', valores: Object.keys(CATEGORIAS), descripcion: 'Categoría del residuo.' }
        },
        async ejecutar(args) {
            const categoria = opcionDe(args.categoria, Object.keys(CATEGORIAS), 'categoría');
            const reporte = await reporteService.reciclajePorMunicipio({ desde: args.desde, hasta: args.hasta, categoria });
            const resumir = (fila) => ({
                confirmadas: fila.confirmadas,
                sin_confirmar: fila.sinConfirmar,
                por_categoria: Object.fromEntries(Object.entries(fila.porCategoria).filter(([, n]) => n > 0)),
                cantidad_por_unidad: Object.fromEntries(Object.entries(fila.porUnidad).filter(([, n]) => n > 0))
            });
            return {
                total: resumir(reporte.total),
                por_municipio: Object.fromEntries(reporte.filas.map((f) => [f.municipio, resumir(f)]))
            };
        }
    },

    contar_certificados: {
        descripcion: 'Certificados (actas) que cargan los gestores al terminar una recolección: cuántos hay de disposición '
            + 'final y de aprovechamiento, y cuántas recolecciones siguen sin certificado (y cuántas llevan más de '
            + `${DIAS_SIN_CERTIFICADO} días así).`,
        parametros: {
            municipio: { tipo: 'string', valores: MUNICIPIOS, descripcion: 'Municipio de la recolección.' },
            desde: { tipo: 'string', descripcion: 'Primer día, AAAA-MM-DD (fecha en que se cargó el certificado).' },
            hasta: { tipo: 'string', descripcion: 'Último día incluido, AAAA-MM-DD.' }
        },
        async ejecutar(args) {
            const municipio = municipioDe(args.municipio);
            const fechas = rangoBogota(args.desde, args.hasta);
            const base = () => {
                let consulta = supabase.from('solicitudes_recoleccion').select('id', { count: 'exact', head: true });
                if (municipio) consulta = consulta.in('municipio', variantesMunicipio(municipio));
                return consulta;
            };
            const conCertificado = (tipo) => {
                let consulta = base().not('certificado_url', 'is', null).neq('certificado_url', '').eq('certificado_tipo', tipo);
                if (fechas.gte) consulta = consulta.gte('certificado_at', fechas.gte);
                if (fechas.lt) consulta = consulta.lt('certificado_at', fechas.lt);
                return consulta;
            };
            const sinCertificado = () => base().eq('estado', 'RECOLECTADO').or('certificado_url.is.null,certificado_url.eq.');

            const [disposicion, aprovechamiento, faltan, atrasados] = await Promise.all([
                conCertificado('DISPOSICION_FINAL'),
                conCertificado('APROVECHAMIENTO'),
                sinCertificado(),
                sinCertificado().lt('recolectado_at', haceDias(DIAS_SIN_CERTIFICADO))
            ]);
            const d = conteoDe(disposicion, 'los certificados');
            const a = conteoDe(aprovechamiento, 'los certificados');
            return {
                certificados_total: d + a,
                disposicion_final: d,
                aprovechamiento: a,
                recolectadas_sin_certificado: conteoDe(faltan, 'las recolecciones sin certificado'),
                sin_certificado_hace_mas_de_7_dias: conteoDe(atrasados, 'las recolecciones sin certificado'),
                filtros_aplicados: { municipio, desde: fechas.desde, hasta: fechas.hasta }
            };
        }
    },

    listar_materiales: {
        descripcion: 'Materiales del catálogo (código, nombre y categoría). Filtra por categoría o por texto.',
        parametros: {
            categoria: { tipo: 'string', valores: Object.keys(CATEGORIAS), descripcion: 'Categoría del material.' },
            texto: { tipo: 'string', descripcion: 'Parte del nombre o del código.' }
        },
        async ejecutar(args) {
            const categoria = opcionDe(args.categoria, Object.keys(CATEGORIAS), 'categoría');
            const texto = textoBusqueda(args.texto);
            let consulta = supabase.from('materiales_residuos').select('codigo, nombre_comun, categoria', { count: 'exact' });
            if (categoria) consulta = consulta.eq('categoria', categoria);
            if (texto) consulta = consulta.or(`nombre_comun.ilike.%${texto}%,codigo.ilike.%${texto}%`);
            const respuesta = await consulta.order('codigo', { ascending: true }).limit(50);
            return {
                total: conteoDe(respuesta, 'los materiales'),
                materiales: (respuesta.data || []).map((m) => ({ codigo: m.codigo, nombre: m.nombre_comun, categoria: m.categoria }))
            };
        }
    },

    contar_ciudadanos: {
        descripcion: 'Cuántos ciudadanos (generadores) están registrados en la app, en total o por municipio. '
            + 'Solo da conteos: los datos personales no se comparten.',
        parametros: {
            municipio: { tipo: 'string', valores: MUNICIPIOS, descripcion: 'Municipio del ciudadano.' }
        },
        async ejecutar(args) {
            const municipio = municipioDe(args.municipio);
            if (municipio) {
                const respuesta = await supabase.from('perfiles_generador').select('id', { count: 'exact', head: true })
                    .in('municipio', variantesMunicipio(municipio));
                return { municipio, total: conteoDe(respuesta, 'los ciudadanos') };
            }
            const conteos = await Promise.all(MUNICIPIOS.map(async (m) => [m, conteoDe(
                await supabase.from('perfiles_generador').select('id', { count: 'exact', head: true }).in('municipio', variantesMunicipio(m)),
                'los ciudadanos'
            )]));
            const total = conteoDe(await supabase.from('perfiles_generador').select('id', { count: 'exact', head: true }), 'los ciudadanos');
            return { total, por_municipio: Object.fromEntries(conteos) };
        }
    },

    listar_autoridades: {
        descripcion: 'Autoridades ambientales registradas (CDMB, AMB, CAS…) con su jurisdicción y contacto.',
        parametros: {},
        async ejecutar() {
            const { data, error } = await supabase.from('autoridades_ambientales')
                .select('sigla, nombre, jurisdiccion, telefono, email, sitio_web')
                .order('sigla', { ascending: true });
            if (error) throw errorDeBase('No pudimos leer las autoridades.', error);
            return { total: (data || []).length, autoridades: data || [] };
        }
    }
};

/**
 * Corre una herramienta. Un parámetro inválido o una consulta fallida no
 * rompen la conversación: vuelven como { error } para que el modelo lo diga.
 *
 * @param {string} nombre
 * @param {object} [args]
 * @returns {Promise<object>}
 */
async function ejecutar(nombre, args) {
    const herramienta = herramientas[nombre];
    if (!herramienta) return { error: `No existe la consulta ${nombre}.` };
    try {
        return await herramienta.ejecutar(args && typeof args === 'object' ? args : {});
    } catch (err) {
        if (!(err instanceof ParametroInvalido)) console.error(`El asistente no pudo ejecutar ${nombre}:`, err);
        return { error: err.message };
    }
}

module.exports = { herramientas, ejecutar, textoBusqueda };
