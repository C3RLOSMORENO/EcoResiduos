const supabase = require('../config/supabase');

const materialService = {
    // Consulta todos los materiales ordenados por identificador ascendente
    async getAllMateriales() {
        const { data, error } = await supabase
            .from('materiales_residuos')
            .select('*')
            .order('id', { ascending: true });

        if (error) {
            throw new Error(`Error en base de datos al listar materiales: ${error.message}`);
        }

        return data || [];
    },

    async getMaterialById(id) {
        if (!id) {
            throw new Error('El identificador del material es obligatorio.');
        }

        const { data, error } = await supabase
            .from('materiales_residuos')
            .select('*')
            .eq('id', id)
            .single();

        if (error || !data) {
            throw new Error(`Error al obtener material: ${error ? error.message : 'Material no encontrado'}`);
        }

        return {
            id: data.id ?? data.ID,
            codigo: data.codigo ?? data.CODIGO ?? '',
            nombre_comun: data.nombre_comun ?? data.NOMBRE_COMUN ?? '',
            categoria: data.categoria ?? data.CATEGORIA ?? 'PELIGROSO',
            descripcion: data.descripcion ?? data.DESCRIPCION ?? '',
            guia_manejo: data.guia_manejo ?? data.GUIA_MANEJO ?? ''
        };
    },

    // Inserta un nuevo residuo verificando código alfanumérico y categoría oficial
    async createMaterial(dto = {}) {
        const codigoLimpio = String(dto.codigo || '').trim().toUpperCase();
        const nombreComunLimpio = String(dto.nombre_comun || dto.nombre || '').trim();
        let categoriaLimpia = String(dto.categoria || 'PELIGROSO').trim().toUpperCase();
        const descripcionLimpia = String(dto.descripcion || '').trim();
        const guiaManejoLimpia = dto.guia_manejo && String(dto.guia_manejo).trim() !== ''
            ? String(dto.guia_manejo).trim()
            : null;

        const codigoRegex = /^[A-Z0-9.\-_]+$/;
        if (!codigoLimpio || !codigoRegex.test(codigoLimpio)) {
            throw new Error('El código oficial del residuo es obligatorio y debe ser alfanumérico (ejemplo: Y8, Y9.2, A1160).');
        }

        if (!nombreComunLimpio || nombreComunLimpio.length < 3) {
            throw new Error('El nombre descriptivo del material es obligatorio y debe tener al menos 3 caracteres.');
        }

        const categoriasPermitidas = ['PELIGROSO', 'RIESGO_BIOLOGICO', 'RCD', 'RAEE', 'APROVECHABLE'];
        if (!categoriasPermitidas.includes(categoriaLimpia)) {
            categoriaLimpia = 'PELIGROSO';
        }

        if (!descripcionLimpia || descripcionLimpia.length < 10) {
            throw new Error('La descripción técnica del residuo es obligatoria y debe contener al menos 10 caracteres.');
        }

        const payloadMaterial = {
            codigo: codigoLimpio,
            nombre_comun: nombreComunLimpio,
            categoria: categoriaLimpia,
            descripcion: descripcionLimpia,
            guia_manejo: guiaManejoLimpia
        };

        const { data, error } = await supabase
            .from('materiales_residuos')
            .insert([payloadMaterial])
            .select();

        if (error) {
            throw new Error(`Error en base de datos al crear material: ${error.message}`);
        }

        return data;
    },

    async updateMaterial(id, dto = {}) {
        if (!id) {
            throw new Error('El identificador del material es obligatorio para la actualización.');
        }

        const codigoLimpio = String(dto.codigo || '').trim().toUpperCase();
        const nombreComunLimpio = String(dto.nombre_comun || dto.nombre || '').trim();
        let categoriaLimpia = String(dto.categoria || 'PELIGROSO').trim().toUpperCase();
        const descripcionLimpia = String(dto.descripcion || '').trim();
        const guiaManejoLimpia = dto.guia_manejo && String(dto.guia_manejo).trim() !== ''
            ? String(dto.guia_manejo).trim()
            : null;

        const codigoRegex = /^[A-Z0-9.\-_]+$/;
        if (!codigoLimpio || !codigoRegex.test(codigoLimpio)) {
            throw new Error('El código oficial del residuo es obligatorio y debe ser alfanumérico (ejemplo: Y8, Y9.2, A1160).');
        }

        if (!nombreComunLimpio || nombreComunLimpio.length < 3) {
            throw new Error('El nombre descriptivo del material es obligatorio y debe tener al menos 3 caracteres.');
        }

        const categoriasPermitidas = ['PELIGROSO', 'RIESGO_BIOLOGICO', 'RCD', 'RAEE', 'APROVECHABLE'];
        if (!categoriasPermitidas.includes(categoriaLimpia)) {
            categoriaLimpia = 'PELIGROSO';
        }

        if (!descripcionLimpia || descripcionLimpia.length < 10) {
            throw new Error('La descripción técnica del residuo es obligatoria y debe contener al menos 10 caracteres.');
        }

        const payloadUpdate = {
            codigo: codigoLimpio,
            nombre_comun: nombreComunLimpio,
            categoria: categoriaLimpia,
            descripcion: descripcionLimpia,
            guia_manejo: guiaManejoLimpia
        };

        const { data, error } = await supabase
            .from('materiales_residuos')
            .update(payloadUpdate)
            .eq('id', id)
            .select();

        if (error) {
            throw new Error(`Error en base de datos al actualizar material: ${error.message}`);
        }

        return data;
    },

    // Elimina el residuo limpiando previamente sus referencias intermedias
    async deleteMaterial(id) {
        if (!id) {
            throw new Error('El identificador del material es obligatorio para eliminarlo.');
        }

        await supabase
            .from('gestor_material')
            .delete()
            .eq('material_id', id);

        const { error } = await supabase
            .from('materiales_residuos')
            .delete()
            .eq('id', id);

        if (error) {
            throw new Error(`Error en base de datos al eliminar material: ${error.message}`);
        }

        return true;
    }
};

module.exports = materialService;