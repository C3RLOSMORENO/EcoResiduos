const supabase = require('../config/supabase');

const autoridadService = {
    async getAllAutoridades() {
        const { data, error } = await supabase
            .from('autoridades_ambientales')
            .select('*')
            .order('id', { ascending: true });

        if (error) throw new Error(`Error BD al listar autoridades: ${error.message}`);
        return data || [];
    },

    async createAutoridad(dto) {
        const { nombre, sigla, jurisdiccion, telefono, email, sitio_web, direccion } = dto;

        const { data, error } = await supabase
            .from('autoridades_ambientales')
            .insert([{
                nombre: nombre.trim(),
                sigla: sigla.trim().toUpperCase(),
                jurisdiccion: jurisdiccion.trim(),
                telefono: telefono.trim(),
                email: email.trim().toLowerCase(),
                sitio_web: sitio_web.trim(),
                direccion: direccion.trim()
            }])
            .select();

        if (error) throw new Error(`Error BD al crear autoridad: ${error.message}`);
        return data;
    },

    async deleteAutoridad(id) {
        const { error } = await supabase
            .from('autoridades_ambientales')
            .delete()
            .eq('id', id);

        if (error) throw new Error(`Error BD al eliminar autoridad: ${error.message}`);
        return true;
    }
};

module.exports = autoridadService;