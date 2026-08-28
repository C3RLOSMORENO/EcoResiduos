const supabase = require('../config/supabase');

const materialService = {
    async getAllMateriales() {
        const { data, error } = await supabase
            .from('materiales_residuos')
            .select('*')
            .order('id', { ascending: true });

        if (error) throw new Error(`Error BD al listar materiales: ${error.message}`);
        return data || [];
    },

    async createMaterial(dto) {
        const { codigo, nombre_comun, categoria, descripcion, guia_manejo } = dto;

        const { data, error } = await supabase
            .from('materiales_residuos')
            .insert([{
                codigo: codigo.trim().toUpperCase(),
                nombre_comun: nombre_comun.trim(),
                categoria,
                descripcion: descripcion.trim(),
                guia_manejo: guia_manejo ? guia_manejo.trim() : null
            }])
            .select();

        if (error) throw new Error(`Error BD al crear material: ${error.message}`);
        return data;
    },

    async deleteMaterial(id) {
        const { error } = await supabase
            .from('materiales_residuos')
            .delete()
            .eq('id', id);

        if (error) throw new Error(`Error BD al eliminar material: ${error.message}`);
        return true;
    }
};

module.exports = materialService;