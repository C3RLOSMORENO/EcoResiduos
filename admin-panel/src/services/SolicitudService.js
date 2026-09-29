const supabase = require('../config/supabase');

class SolicitudService {
    async listarTodas() {
        const { data, error } = await supabase
            .from('solicitudes_recoleccion')
            .select('*, materiales_residuos(nombre_comun)')
            .order('created_at', { ascending: false });

        if (error) {
            console.error('Error al listar solicitudes de recolección:', error.message);
            throw error;
        }
        return data;
    }

    async cambiarEstado(id, nuevoEstado) {
        const { data, error } = await supabase
            .from('solicitudes_recoleccion')
            .update({ estado: nuevoEstado, updated_at: new Date().toISOString() })
            .eq('id', id);

        if (error) throw error;
        return data;
    }
}

module.exports = new SolicitudService();

