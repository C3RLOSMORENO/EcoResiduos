const supabase = require('../config/supabase');

class GeneradorService {
    async listarTodos() {
        const { data, error } = await supabase
            .from('perfiles_generador')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) {
            console.error('Error al listar ciudadanos (generadores):', error.message);
            throw error;
        }
        return data;
    }
}

module.exports = new GeneradorService();
