const supabase = require('../config/supabase');
const { variantesMunicipio } = require('../utils/municipios');
const { rango, faltaEnEsquema } = require('../utils/web');
const { rangoBogota, haceDias } = require('../utils/fechas');
const { errorDeBase } = require('../utils/errores');

const ESTADOS_CANCELABLES = ['PUBLICADO', 'EN_NEGOCIACION'];
const DIAS_SIN_CERTIFICADO = 7;

// Un problema sin resolver es problema_reportado = TRUE: al resolverlo
// (resolver_problema_no_recogido) vuelve a FALSE.
function aplicarFiltros(consulta, filtros) {
    if (filtros.estado) consulta = consulta.eq('estado', filtros.estado);
    if (filtros.municipio) consulta = consulta.in('municipio', variantesMunicipio(filtros.municipio));
    if (filtros.categoria) consulta = consulta.eq('materiales_residuos.categoria', filtros.categoria);
    if (filtros.q) consulta = consulta.or(`nombre_comun.ilike.%${filtros.q}%,codigo.ilike.%${filtros.q}%`, { referencedTable: 'materiales_residuos' });
    const fechas = rangoBogota(filtros.desde, filtros.hasta);
    if (fechas.gte) consulta = consulta.gte('created_at', fechas.gte);
    if (fechas.lt) consulta = consulta.lt('created_at', fechas.lt);
    if (filtros.generador) consulta = consulta.eq('generador_id', filtros.generador);
    if (filtros.problema) consulta = consulta.eq('problema_reportado', true);
    if (filtros.sinCertificado) {
        consulta = consulta
            .eq('estado', 'RECOLECTADO')
            .or('certificado_url.is.null,certificado_url.eq.')
            .lt('recolectado_at', haceDias(DIAS_SIN_CERTIFICADO));
    }
    return consulta;
}

const solicitudService = {
    ESTADOS_CANCELABLES,
    DIAS_SIN_CERTIFICADO,

    // Se puede resolver si el gestor la marcó recolectada, el generador
    // reportó el problema y aún no está confirmada.
    problemaResoluble(s) {
        return Boolean(s && s.problema_reportado && s.estado === 'RECOLECTADO' && !s.confirmado_at);
    },

    async listar(filtros, pagina = 1) {
        // !inner hace que los filtros por categoría o material descarten la
        // solicitud completa, no solo el material embebido.
        const embebido = filtros.categoria || filtros.q
            ? 'materiales_residuos!inner(id, codigo, nombre_comun, categoria)'
            : 'materiales_residuos(id, codigo, nombre_comun, categoria)';
        const { desde, hasta } = rango(pagina);

        const consulta = supabase
            .from('solicitudes_recoleccion')
            .select(`id, material_id, cantidad_estimada, unidad_medida, estado, municipio, created_at, foto_url,
                certificado_url, certificado_tipo, problema_reportado, recolectado_at, confirmado_at, ${embebido}`,
            { count: 'exact' });
        const { data, error, count } = await aplicarFiltros(consulta, filtros)
            .order('created_at', { ascending: filtros.orden === 'fecha' })
            .range(desde, hasta);

        if (error) {
            throw errorDeBase('No pudimos cargar las solicitudes.', error);
        }
        return { solicitudes: data || [], total: count || 0 };
    },

    async obtenerDetalle(id) {
        const { data: solicitud, error } = await supabase
            .from('solicitudes_recoleccion')
            .select('*, materiales_residuos(*)')
            .eq('id', id)
            .maybeSingle();

        if (error) throw errorDeBase('No pudimos cargar la solicitud.', error);
        if (!solicitud) return null;

        const [generador, historial, postulaciones, gestorAsignado] = await Promise.all([
            solicitud.generador_id
                ? supabase.from('perfiles_generador')
                    .select('id, nombre_completo_o_empresa, documento_nit, telefono, email, municipio')
                    .eq('id', solicitud.generador_id).maybeSingle()
                : Promise.resolve({ data: null }),
            supabase.from('solicitudes_historial_estados')
                .select('id, estado, created_at')
                .eq('solicitud_id', id)
                .order('created_at', { ascending: true }),
            supabase.from('postulaciones_recoleccion')
                .select('id, gestor_id, estado, propuesta, tipo_valor, valor, created_at, perfiles_gestor(id, razon_social, nit)')
                .eq('solicitud_id', id)
                .order('created_at', { ascending: true }),
            solicitud.gestor_asignado_id
                ? supabase.from('perfiles_gestor')
                    .select('id, razon_social, nit, telefono_contacto, email_contacto, municipio')
                    .eq('id', solicitud.gestor_asignado_id).maybeSingle()
                : Promise.resolve({ data: null })
        ]);

        return {
            solicitud,
            material: solicitud.materiales_residuos || null,
            generador: generador.data || null,
            historial: historial.error ? null : (historial.data || []),
            postulaciones: postulaciones.error ? null : (postulaciones.data || []),
            gestorAsignado: gestorAsignado.data || null
        };
    },

    // «Resuelto: no se recogió» (función resolver_problema_no_recogido): la
    // solicitud vuelve a EN_NEGOCIACION con el mismo gestor y ambos reciben aviso.
    async resolverNoRecogido(id, nota) {
        const solicitudId = parseInt(id, 10);
        if (!Number.isInteger(solicitudId)) {
            throw new Error('El identificador de la solicitud no es válido.');
        }
        const notaLimpia = String(nota || '').trim().slice(0, 300) || null;
        const { data, error } = await supabase.rpc('resolver_problema_no_recogido', {
            p_solicitud_id: solicitudId,
            p_nota: notaLimpia
        });
        if (error) {
            if (faltaEnEsquema(error)) {
                throw new Error('Falta aplicar la migración 20261003000200_resolucion_problemas_reportados.sql para resolver problemas desde el panel.');
            }
            throw errorDeBase('No pudimos resolver el problema.', error);
        }
        return data;
    },

    // Cancela en una sola transacción (función cancelar_solicitud_admin):
    // la solicitud queda CANCELADO y sus propuestas abiertas, RECHAZADA.
    async cancelar(id) {
        const solicitudId = parseInt(id, 10);
        if (!Number.isInteger(solicitudId)) {
            throw new Error('El identificador de la solicitud no es válido.');
        }

        const { data, error } = await supabase.rpc('cancelar_solicitud_admin', { p_solicitud_id: solicitudId });
        if (error) {
            if (faltaEnEsquema(error)) {
                throw new Error('Falta aplicar la migración 20261003000000_cancelar_solicitud_admin.sql para poder cancelar desde el panel.');
            }
            throw errorDeBase('No pudimos cancelar la solicitud.', error);
        }
        return data;
    }
};

module.exports = solicitudService;
