const supabase = require('../config/supabase');

const gestorService = {
    async getAllGestores() {
        const { data, error } = await supabase
            .from('perfiles_gestor')
            .select('*')
            .order('id', { ascending: true });


        if (error) throw new Error(`Error BD al listar gestores: ${error.message}`);
        return data || [];
    },

    async createGestor(dto) {
        const { nit, razon_social, municipio, direccion, representante_legal, telefono_contacto, email_contacto, latitud, longitud } = dto;

        const { data, error } = await supabase
            .from('perfiles_gestor')
            .insert([{
                nit: nit.trim(),
                razon_social: razon_social.trim(),
                municipio: municipio.trim().toUpperCase(),
                direccion: direccion.trim(),
                representante_legal: representante_legal ? representante_legal.trim() : null,
                telefono_contacto: telefono_contacto.trim(),
                email_contacto: email_contacto.trim().toLowerCase(),
                latitud: parseFloat(latitud),
                longitud: parseFloat(longitud),
                estado_verificacion: 'APROBADO',
                disponible: true
            }])
            .select();

        if (error) throw new Error(`Error BD al crear gestor: ${error.message}`);
        return data;
    },

    async deleteGestor(id) {
        const { error } = await supabase
            .from('perfiles_gestor')
            .delete()
            .eq('id', id);

        if (error) throw new Error(`Error BD al eliminar gestor: ${error.message}`);
        return true;
    }
};

module.exports = gestorService;