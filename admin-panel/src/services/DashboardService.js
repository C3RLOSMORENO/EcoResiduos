const supabase = require('../config/supabase');
const { conFotoSiExiste } = require('../utils/fotosPerfil');
const solicitudService = require('./SolicitudService');
const { MUNICIPIOS, variantesMunicipio } = require('../utils/municipios');
const { haceDias } = require('../utils/fechas');

const contar = (tabla) => supabase.from(tabla).select('id', { count: 'exact', head: true });

/**
 * Conteo que no tumba el tablero: si una consulta falla se muestra 0 y se
 * avisa una sola vez arriba.
 *
 * @param {PromiseLike<{count: ?number, error: ?object}>} promesa Consulta con count: 'exact'.
 * @param {string[]} errores Lista donde se anota el nombre si la consulta falla.
 * @param {string} nombre Lo que se contaba, para el aviso.
 * @returns {Promise<number>}
 */
async function conteo(promesa, errores, nombre) {
    const { count, error } = await promesa;
    if (error) {
        errores.push(nombre);
        return 0;
    }
    return count || 0;
}

const dashboardService = {
    /**
     * Cifras, pendientes y listas cortas del inicio en una sola ronda de consultas.
     * Nunca lanza un error por una consulta fallida: la anota en `errores`.
     *
     * @returns {Promise<{kpis: object, pendientesAccion: object, chartData: object,
     *     gestoresPendientes: object[], ultimasSolicitudes: object[], errores: string[]}>}
     */
    async getDashboardKpis() {
        const errores = [];
        const c = (promesa, nombre) => conteo(promesa, errores, nombre);

        // Las dos listas salen junto con los conteos, no después: no dependen
        // de ellos y así el inicio espera una sola ronda de consultas.
        const listas = Promise.all([
            conFotoSiExiste((foto) => supabase.from('perfiles_gestor')
                .select(`id, nit, razon_social, municipio, estado_verificacion, permiso_path, created_at${foto}`)
                .eq('estado_verificacion', 'PENDIENTE')
                .order('created_at', { ascending: true })
                .limit(6)),
            supabase.from('solicitudes_recoleccion')
                .select('id, cantidad_estimada, unidad_medida, estado, municipio, created_at, problema_reportado, materiales_residuos(codigo, nombre_comun, categoria)')
                .order('created_at', { ascending: false })
                .limit(8)
        ]);

        const [
            totalSolicitudes, solicitudesPublicadas, solicitudesEnProceso, solicitudesRecolectadas, solicitudesCanceladas,
            totalGestores, gestoresPendientesCount, gestoresAprobados, gestoresRechazados, gestoresSuspendidos,
            totalMateriales, totalAutoridades, totalPostulaciones,
            materialesPorVerificar, problemasReportados, sinCertificado,
            porMunicipio
        ] = await Promise.all([
            c(contar('solicitudes_recoleccion'), 'solicitudes'),
            c(contar('solicitudes_recoleccion').eq('estado', 'PUBLICADO'), 'solicitudes'),
            c(contar('solicitudes_recoleccion').eq('estado', 'EN_NEGOCIACION'), 'solicitudes'),
            c(contar('solicitudes_recoleccion').eq('estado', 'RECOLECTADO'), 'solicitudes'),
            c(contar('solicitudes_recoleccion').eq('estado', 'CANCELADO'), 'solicitudes'),
            c(contar('perfiles_gestor'), 'gestores'),
            c(contar('perfiles_gestor').eq('estado_verificacion', 'PENDIENTE'), 'gestores'),
            c(contar('perfiles_gestor').eq('estado_verificacion', 'APROBADO'), 'gestores'),
            c(contar('perfiles_gestor').eq('estado_verificacion', 'RECHAZADO'), 'gestores'),
            c(contar('perfiles_gestor').eq('estado_verificacion', 'SUSPENDIDO'), 'gestores'),
            c(contar('materiales_residuos'), 'materiales'),
            c(contar('autoridades_ambientales'), 'autoridades'),
            c(contar('postulaciones_recoleccion'), 'postulaciones'),
            c(supabase.from('gestor_material')
                .select('material_id, perfiles_gestor!inner(estado_verificacion)', { count: 'exact', head: true })
                .eq('verificado', false)
                .eq('perfiles_gestor.estado_verificacion', 'APROBADO'), 'materiales por verificar'),
            c(contar('solicitudes_recoleccion').eq('problema_reportado', true), 'problemas reportados'),
            c(contar('solicitudes_recoleccion')
                .eq('estado', 'RECOLECTADO')
                .or('certificado_url.is.null,certificado_url.eq.')
                .lt('recolectado_at', haceDias(solicitudService.DIAS_SIN_CERTIFICADO)), 'certificados'),
            Promise.all(MUNICIPIOS.map((m) => c(
                contar('solicitudes_recoleccion').in('municipio', variantesMunicipio(m)), 'municipios'
            )))
        ]);

        const [pendientes, ultimas] = await listas;
        if (pendientes.error) errores.push('gestores por revisar');
        if (ultimas.error) errores.push('últimas solicitudes');

        const sumaMunicipios = porMunicipio.reduce((a, b) => a + b, 0);
        const otros = Math.max(0, totalSolicitudes - sumaMunicipios);

        return {
            kpis: {
                totalSolicitudes,
                solicitudesRecolectadas,
                solicitudesPublicadas,
                solicitudesEnProceso,
                solicitudesCanceladas,
                totalGestores,
                gestoresPendientesCount,
                gestoresAprobados,
                gestoresRechazados,
                gestoresSuspendidos,
                totalMateriales,
                totalAutoridades,
                totalPostulaciones
            },
            pendientesAccion: {
                gestoresPorRevisar: gestoresPendientesCount,
                materialesPorVerificar,
                problemasReportados,
                sinCertificado
            },
            chartData: {
                municipiosLabels: [...MUNICIPIOS, ...(otros > 0 ? ['Otro / sin dato'] : [])],
                municipiosData: [...porMunicipio, ...(otros > 0 ? [otros] : [])]
            },
            gestoresPendientes: pendientes.data || [],
            ultimasSolicitudes: ultimas.data || [],
            errores: [...new Set(errores)]
        };
    }
};

module.exports = dashboardService;
