const supabase = require('../config/supabase');
const { CATEGORIAS_CATALOGO } = require('../utils/formato');
const { rango, textoBusqueda } = require('../utils/web');

const textoOpcional = (valor) => (valor && String(valor).trim() !== '' ? String(valor).trim() : null);

function errorConCodigo(mensaje, codigo) {
    const error = new Error(mensaje);
    error.codigo = codigo;
    return error;
}

const materialService = {
    async listarMateriales({ q, categoria, orden, pagina = 1 } = {}) {
        let consulta = supabase
            .from('materiales_residuos')
            .select('*', { count: 'exact' });

        const termino = textoBusqueda(q);
        if (termino) {
            consulta = consulta.or(`codigo.ilike.%${termino}%,nombre_comun.ilike.%${termino}%,descripcion.ilike.%${termino}%,subcategoria.ilike.%${termino}%`);
        }
        const cat = String(categoria || '').toUpperCase();
        if (CATEGORIAS_CATALOGO.includes(cat)) consulta = consulta.eq('categoria', cat);

        const { desde, hasta } = rango(pagina);
        const { data, error, count } = await consulta
            .order(orden === '-nombre' || orden === 'nombre' ? 'nombre_comun' : 'codigo', { ascending: orden !== '-nombre' && orden !== '-codigo' })
            .range(desde, hasta);

        if (error) {
            throw new Error(`No pudimos cargar los materiales: ${error.message}`);
        }
        return { materiales: data || [], total: count || 0 };
    },

    // Las solicitudes son historia: con ellas el material no se borra.
    async getDependencias(id) {
        const [solicitudes, gestores] = await Promise.all([
            supabase.from('solicitudes_recoleccion').select('id', { count: 'exact', head: true }).eq('material_id', id),
            supabase.from('gestor_material').select('material_id', { count: 'exact', head: true }).eq('material_id', id)
        ]);
        if (solicitudes.error) {
            throw new Error(`No pudimos revisar las solicitudes del material: ${solicitudes.error.message}`);
        }
        return {
            solicitudes: solicitudes.count || 0,
            gestores: gestores.count || 0,
            tieneHistoria: (solicitudes.count || 0) > 0
        };
    },

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
            categoria: data.categoria ?? data.CATEGORIA ?? '',
            descripcion: data.descripcion ?? data.DESCRIPCION ?? '',
            guia_manejo: data.guia_manejo ?? data.GUIA_MANEJO ?? '',
            subcategoria: data.subcategoria ?? '',
            advertencia_manejo: data.advertencia_manejo ?? ''
        };
    },

    // Inserta un nuevo residuo verificando código alfanumérico y categoría oficial
    async createMaterial(dto = {}) {
        const codigoLimpio = String(dto.codigo || '').trim().toUpperCase();
        const nombreComunLimpio = String(dto.nombre_comun || dto.nombre || '').trim();
        const categoriaLimpia = String(dto.categoria || '').trim().toUpperCase();
        const descripcionLimpia = String(dto.descripcion || '').trim();
        const guiaManejoLimpia = textoOpcional(dto.guia_manejo);
        const subcategoriaLimpia = textoOpcional(dto.subcategoria);
        const advertenciaLimpia = textoOpcional(dto.advertencia_manejo);

        const codigoRegex = /^[A-Z0-9.\-_]+$/;
        if (!codigoLimpio || !codigoRegex.test(codigoLimpio)) {
            throw new Error('El código oficial del residuo es obligatorio y debe ser alfanumérico (ejemplo: Y8, Y9.2, A1160).');
        }

        if (!nombreComunLimpio || nombreComunLimpio.length < 3) {
            throw new Error('El nombre descriptivo del material es obligatorio y debe tener al menos 3 caracteres.');
        }

        if (!CATEGORIAS_CATALOGO.includes(categoriaLimpia)) {
            throw new Error('Elige la categoría del material.');
        }

        if (!descripcionLimpia || descripcionLimpia.length < 10) {
            throw new Error('La descripción técnica del residuo es obligatoria y debe contener al menos 10 caracteres.');
        }

        const payloadMaterial = {
            codigo: codigoLimpio,
            nombre_comun: nombreComunLimpio,
            categoria: categoriaLimpia,
            descripcion: descripcionLimpia,
            guia_manejo: guiaManejoLimpia,
            subcategoria: subcategoriaLimpia,
            advertencia_manejo: advertenciaLimpia
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
        const categoriaLimpia = String(dto.categoria || '').trim().toUpperCase();
        const descripcionLimpia = String(dto.descripcion || '').trim();
        const guiaManejoLimpia = textoOpcional(dto.guia_manejo);
        const subcategoriaLimpia = textoOpcional(dto.subcategoria);
        const advertenciaLimpia = textoOpcional(dto.advertencia_manejo);

        const codigoRegex = /^[A-Z0-9.\-_]+$/;
        if (!codigoLimpio || !codigoRegex.test(codigoLimpio)) {
            throw new Error('El código oficial del residuo es obligatorio y debe ser alfanumérico (ejemplo: Y8, Y9.2, A1160).');
        }

        if (!nombreComunLimpio || nombreComunLimpio.length < 3) {
            throw new Error('El nombre descriptivo del material es obligatorio y debe tener al menos 3 caracteres.');
        }

        if (!CATEGORIAS_CATALOGO.includes(categoriaLimpia)) {
            throw new Error('Elige la categoría del material.');
        }

        if (!descripcionLimpia || descripcionLimpia.length < 10) {
            throw new Error('La descripción técnica del residuo es obligatoria y debe contener al menos 10 caracteres.');
        }

        const payloadUpdate = {
            codigo: codigoLimpio,
            nombre_comun: nombreComunLimpio,
            categoria: categoriaLimpia,
            descripcion: descripcionLimpia,
            guia_manejo: guiaManejoLimpia,
            subcategoria: subcategoriaLimpia,
            advertencia_manejo: advertenciaLimpia
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

    // Solo se elimina un material sin solicitudes; antes se quita de los
    // gestores que lo tenían asignado.
    async deleteMaterial(id) {
        if (!id) {
            throw new Error('El identificador del material es obligatorio para eliminarlo.');
        }

        const dependencias = await this.getDependencias(id);
        if (dependencias.tieneHistoria) {
            throw errorConCodigo(
                `No se puede eliminar: hay ${dependencias.solicitudes} solicitud(es) de este material y se perdería su historia.`,
                'TIENE_HISTORIA'
            );
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