const supabase = require('../config/supabase');

const dashboardService = {
    async getDashboardKpis() {
        // 1. EstadÃ­sticas de solicitudes
        const { data: solicitudes, error: errSol } = await supabase
            .from('solicitudes_recoleccion')
            .select(`
                id,
                material_id,
                cantidad_estimada,
                unidad_medida,
                estado,
                municipio,
                created_at,
                materiales_residuos (
                    codigo,
                    nombre_comun,
                    categoria
                )
            `)
            .order('created_at', { ascending: false });

        if (errSol) {
            console.error('Error al consultar solicitudes para dashboard:', errSol.message);
        }

        // 2. EstadÃ­sticas de gestores
        const { data: gestores, error: errGest } = await supabase
            .from('perfiles_gestor')
            .select(`
                id,
                nit,
                razon_social,
                municipio,
                email_contacto,
                telefono_contacto,
                estado_verificacion,
                disponible,
                created_at
            `)
            .order('created_at', { ascending: false });

        if (errGest) {
            console.error('Error al consultar gestores para dashboard:', errGest.message);
        }

        // 3. Cantidad de materiales en catÃ¡logo
        const { count: totalMateriales } = await supabase
            .from('materiales_residuos')
            .select('id', { count: 'exact', head: true });

        // 4. Cantidad de autoridades ambientales
        const { count: totalAutoridades } = await supabase
            .from('autoridades_ambientales')
            .select('id', { count: 'exact', head: true });

        // 5. Total postulaciones
        const { count: totalPostulaciones } = await supabase
            .from('postulaciones_recoleccion')
            .select('id', { count: 'exact', head: true });

        const listaSolicitudes = solicitudes || [];
        const listaGestores = gestores || [];

        const totalSolicitudes = listaSolicitudes.length;
        const solicitudesRecolectadas = listaSolicitudes.filter(s => s.estado === 'RECOLECTADO').length;
        const solicitudesPublicadas = listaSolicitudes.filter(s => s.estado === 'PUBLICADO').length;
        const solicitudesEnProceso = listaSolicitudes.filter(s => s.estado === 'EN_NEGOCIACION').length;
        const solicitudesCanceladas = listaSolicitudes.filter(s => s.estado === 'CANCELADO').length;

        const totalGestores = listaGestores.length;
        const gestoresPendientes = listaGestores.filter(g => (g.estado_verificacion || '').toUpperCase() === 'PENDIENTE');
        const gestoresAprobados = listaGestores.filter(g => (g.estado_verificacion || '').toUpperCase() === 'APROBADO').length;
        const gestoresRechazados = listaGestores.filter(g => (g.estado_verificacion || '').toUpperCase() === 'RECHAZADO').length;

        return {
            kpis: {
                totalSolicitudes,
                solicitudesRecolectadas,
                solicitudesPublicadas,
                solicitudesEnProceso,
                solicitudesCanceladas,
                totalGestores,
                gestoresPendientesCount: gestoresPendientes.length,
                gestoresAprobados,
                gestoresRechazados,
                totalMateriales: totalMateriales || 0,
                totalAutoridades: totalAutoridades || 0,
                totalPostulaciones: totalPostulaciones || 0
            },
            gestoresPendientes: gestoresPendientes.slice(0, 6),
            ultimasSolicitudes: listaSolicitudes.slice(0, 8)
        };
    }
};

module.exports = dashboardService;

