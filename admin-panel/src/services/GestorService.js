const supabase = require('../config/supabase');

// Convierte la lista de IDs recibida en un arreglo de números enteros válidos
function extractMaterialIds(dto) {
    const raw = dto.materiales_ids || dto['materiales_ids[]'] || dto.material_ids || dto.residuos || [];
    if (Array.isArray(raw)) {
        return raw.map((id) => parseInt(id, 10)).filter((id) => !isNaN(id));
    }
    if (typeof raw === 'string' || typeof raw === 'number') {
        const parsed = parseInt(raw, 10);
        return !isNaN(parsed) ? [parsed] : [];
    }
    return [];
}

const gestorService = {
    // Consulta gestores y sus residuos autorizados mediante la tabla intermedia gestor_material
    async getAllGestores() {
        const { data, error } = await supabase
            .from('perfiles_gestor')
            .select(`
                *,
                gestor_material (
                    material_id,
                    verificado,
                    materiales_residuos (
                        id,
                        codigo,
                        nombre_comun,
                        categoria
                    )
                )
            `)
            .order('id', { ascending: true });

        if (error) {
            throw new Error(`Error al consultar gestores: ${error.message}`);
        }

        return (data || []).map((row) => {
            const materiales = (row.gestor_material || [])
                .map((gm) => gm.materiales_residuos)
                .filter(Boolean);

            const materialesPorVerificar = (row.gestor_material || []).filter((gm) => gm.verificado === false).length;

            return {
                id: row.id ?? row.ID,
                nit: row.nit ?? row.NIT ?? '',
                razon_social: row.razon_social ?? row.RAZON_SOCIAL ?? row.Razon_Social ?? '',
                municipio: row.municipio ?? row.MUNICIPIO ?? 'BUCARAMANGA',
                direccion: row.direccion ?? row.DIRECCION ?? '',
                representante_legal: row.representante_legal ?? row.REPRESENTANTE_LEGAL ?? null,
                telefono_contacto: row.telefono_contacto ?? row.TELEFONO_CONTACTO ?? '',
                email_contacto: row.email_contacto ?? row.EMAIL_CONTACTO ?? '',
                latitud: row.latitud !== undefined && row.latitud !== null ? row.latitud : (row.LATITUD !== undefined ? row.LATITUD : 7.119349),
                longitud: row.longitud !== undefined && row.longitud !== null ? row.longitud : (row.LONGITUD !== undefined ? row.LONGITUD : -73.122741),
                estado_verificacion: row.estado_verificacion ?? row.ESTADO_VERIFICACION ?? 'APROBADO',
                disponible: row.disponible !== undefined ? row.disponible : (row.DISPONIBLE !== undefined ? row.DISPONIBLE : true),
                materiales,
                materiales_por_verificar: materialesPorVerificar
            };
        });
    },

    async getGestorById(id) {
        if (!id) {
            throw new Error('El identificador del gestor es obligatorio.');
        }

        const { data, error } = await supabase
            .from('perfiles_gestor')
            .select(`
                *,
                gestor_material (
                    material_id,
                    verificado,
                    materiales_residuos (
                        id,
                        codigo,
                        nombre_comun,
                        categoria
                    )
                )
            `)
            .eq('id', id)
            .single();

        if (error || !data) {
            throw new Error(`Error al obtener gestor: ${error ? error.message : 'Registro no encontrado'}`);
        }

        const materialIds = (data.gestor_material || []).map((gm) => gm.material_id);
        // Materiales que el gestor declaró al registrarse y aún no se han aprobado.
        const materialIdsPorVerificar = (data.gestor_material || [])
            .filter((gm) => gm.verificado === false)
            .map((gm) => gm.material_id);
        const materiales = (data.gestor_material || [])
            .map((gm) => gm.materiales_residuos)
            .filter(Boolean);

        return {
            id: data.id ?? data.ID,
            nit: data.nit ?? data.NIT ?? '',
            razon_social: data.razon_social ?? data.RAZON_SOCIAL ?? data.Razon_Social ?? '',
            municipio: data.municipio ?? data.MUNICIPIO ?? 'BUCARAMANGA',
            direccion: data.direccion ?? data.DIRECCION ?? '',
            representante_legal: data.representante_legal ?? data.REPRESENTANTE_LEGAL ?? '',
            telefono_contacto: data.telefono_contacto ?? data.TELEFONO_CONTACTO ?? '',
            email_contacto: data.email_contacto ?? data.EMAIL_CONTACTO ?? '',
            latitud: data.latitud !== undefined && data.latitud !== null ? data.latitud : (data.LATITUD !== undefined ? data.LATITUD : 7.119349),
            longitud: data.longitud !== undefined && data.longitud !== null ? data.longitud : (data.LONGITUD !== undefined ? data.LONGITUD : -73.122741),
            estado_verificacion: data.estado_verificacion ?? data.ESTADO_VERIFICACION ?? 'APROBADO',
            disponible: data.disponible !== undefined ? data.disponible : (data.DISPONIBLE !== undefined ? data.DISPONIBLE : true),
            material_ids: materialIds,
            material_ids_por_verificar: materialIdsPorVerificar,
            materiales
        };
    },

    // Valida datos de entrada y crea el registro con geocodificación pasiva
    async createGestor(dto = {}) {
        const nitLimpio = String(dto.nit || '').trim();
        const razonSocialLimpia = String(dto.razon_social || '').trim().toUpperCase();
        const municipioLimpio = dto.municipio && String(dto.municipio).trim() !== ''
            ? String(dto.municipio).trim().toUpperCase()
            : 'BUCARAMANGA';
        const direccionLimpia = String(dto.direccion || '').trim();
        const representanteLegalRaw = dto.representante_legal || dto.contacto;
        const representanteLegalLimpio = representanteLegalRaw && String(representanteLegalRaw).trim() !== ''
            ? String(representanteLegalRaw).trim()
            : null;
        const telefonoContactoLimpio = String(dto.telefono_contacto || dto.telefono || '').trim();
        const emailContactoLimpio = String(dto.email_contacto || dto.email || '').trim().toLowerCase();
        const materialIds = extractMaterialIds(dto);

        // Regla: El NIT debe ser numérico entre 8 y 15 dígitos
        const nitRegex = /^\d{8,15}$/;
        if (!nitRegex.test(nitLimpio)) {
            throw new Error('El NIT es obligatorio y debe ser numérico entre 8 y 15 dígitos (sin guiones ni puntos).');
        }

        if (!razonSocialLimpia || razonSocialLimpia.length < 3) {
            throw new Error('La razón social es obligatoria y debe contener al menos 3 caracteres.');
        }

        if (!direccionLimpia || direccionLimpia.length < 5) {
            throw new Error('La dirección física es obligatoria y debe contener al menos 5 caracteres descriptivos.');
        }

        if (!telefonoContactoLimpio) {
            throw new Error('El teléfono principal de contacto es obligatorio.');
        }

        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(emailContactoLimpio)) {
            throw new Error('El correo electrónico de contacto no tiene un formato válido (ejemplo: contacto@empresa.com).');
        }

        let latitud = 7.119349;
        let longitud = -73.122741;

        // Intenta obtener coordenadas en OpenStreetMap; si falla, usa el centro de Bucaramanga
        try {
            const consulta = encodeURIComponent(`${direccionLimpia}, ${municipioLimpio}, Santander, Colombia`);
            const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${consulta}&limit=1`, {
                headers: { 'User-Agent': 'EcoResiduos-AdminPanel' }
            });
            const data = await res.json();
            if (data && data.length > 0) {
                latitud = parseFloat(data[0].lat);
                longitud = parseFloat(data[0].lon);
            }
        } catch {
            // Asigna coordenadas por defecto en Bucaramanga
        }

        const payloadGestor = {
            nit: nitLimpio,
            razon_social: razonSocialLimpia,
            municipio: municipioLimpio,
            direccion: direccionLimpia,
            representante_legal: representanteLegalLimpio,
            telefono_contacto: telefonoContactoLimpio,
            email_contacto: emailContactoLimpio,
            latitud,
            longitud,
            estado_verificacion: 'APROBADO',
            disponible: true
        };

        const { data: gestorCreado, error: gestorError } = await supabase
            .from('perfiles_gestor')
            .insert([payloadGestor])
            .select();

        if (gestorError) {
            throw new Error(`Error en base de datos al crear gestor: ${gestorError.message}`);
        }

        const nuevoGestor = gestorCreado && gestorCreado[0];

        // Registra los residuos asociados en la tabla intermedia verificados por el administrador
        if (nuevoGestor && materialIds.length > 0) {
            const relaciones = materialIds.map((matId) => ({
                gestor_id: nuevoGestor.id,
                material_id: matId,
                verificado: true
            }));

            await supabase
                .from('gestor_material')
                .insert(relaciones);
        }

        return gestorCreado;
    },

    // Actualiza datos del gestor y sincroniza las relaciones con materiales
    async updateGestor(id, dto = {}) {
        if (!id) {
            throw new Error('El identificador del gestor es obligatorio para la actualización.');
        }

        const nitLimpio = String(dto.nit || '').trim();
        const razonSocialLimpia = String(dto.razon_social || '').trim().toUpperCase();
        const municipioLimpio = dto.municipio && String(dto.municipio).trim() !== ''
            ? String(dto.municipio).trim().toUpperCase()
            : 'BUCARAMANGA';
        const direccionLimpia = String(dto.direccion || '').trim();
        const representanteLegalLimpio = dto.representante_legal && String(dto.representante_legal).trim() !== ''
            ? String(dto.representante_legal).trim()
            : null;
        const telefonoContactoLimpio = String(dto.telefono_contacto || '').trim();
        const emailContactoLimpio = String(dto.email_contacto || '').trim().toLowerCase();
        const materialIds = extractMaterialIds(dto);

        const nitRegex = /^\d{8,15}$/;
        if (!nitRegex.test(nitLimpio)) {
            throw new Error('El NIT es obligatorio y debe ser numérico entre 8 y 15 dígitos (sin guiones ni puntos).');
        }

        if (!razonSocialLimpia || razonSocialLimpia.length < 3) {
            throw new Error('La razón social es obligatoria y debe contener al menos 3 caracteres.');
        }

        if (!direccionLimpia || direccionLimpia.length < 5) {
            throw new Error('La dirección física es obligatoria y debe contener al menos 5 caracteres descriptivos.');
        }

        if (!telefonoContactoLimpio) {
            throw new Error('El teléfono principal de contacto es obligatorio.');
        }

        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(emailContactoLimpio)) {
            throw new Error('El correo electrónico de contacto no tiene un formato válido (ejemplo: contacto@empresa.com).');
        }

        let latitud = 7.119349;
        let longitud = -73.122741;

        try {
            const consulta = encodeURIComponent(`${direccionLimpia}, ${municipioLimpio}, Santander, Colombia`);
            const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${consulta}&limit=1`, {
                headers: { 'User-Agent': 'EcoResiduos-AdminPanel' }
            });
            const data = await res.json();
            if (data && data.length > 0) {
                latitud = parseFloat(data[0].lat);
                longitud = parseFloat(data[0].lon);
            }
        } catch {
            // Asigna coordenadas por defecto en Bucaramanga
        }

        const payloadUpdate = {
            nit: nitLimpio,
            razon_social: razonSocialLimpia,
            municipio: municipioLimpio,
            direccion: direccionLimpia,
            representante_legal: representanteLegalLimpio,
            telefono_contacto: telefonoContactoLimpio,
            email_contacto: emailContactoLimpio,
            latitud,
            longitud
        };

        if (dto.estado_verificacion) {
            payloadUpdate.estado_verificacion = String(dto.estado_verificacion).trim().toUpperCase();
        }
        if (dto.disponible !== undefined) {
            payloadUpdate.disponible = dto.disponible === true || dto.disponible === 'true' || dto.disponible === 'on' || dto.disponible === '1';
        }

        const { data: gestorActualizado, error: gestorError } = await supabase
            .from('perfiles_gestor')
            .update(payloadUpdate)
            .eq('id', id)
            .select();

        if (gestorError) {
            throw new Error(`Error en base de datos al actualizar gestor: ${gestorError.message}`);
        }

        // Reemplaza los materiales asignados con la nueva selección
        await supabase
            .from('gestor_material')
            .delete()
            .eq('gestor_id', id);

        if (materialIds.length > 0) {
            const relaciones = materialIds.map((matId) => ({
                gestor_id: parseInt(id, 10),
                material_id: matId,
                verificado: true
            }));

            await supabase
                .from('gestor_material')
                .insert(relaciones);
        }

        return gestorActualizado;
    },

    // Actualiza el estado de verificación del gestor (Auditoría Admin)
    async updateEstadoVerificacion(id, estado) {
        if (!id) throw new Error('El identificador del gestor es obligatorio');
        const estadosValidos = ['PENDIENTE', 'APROBADO', 'RECHAZADO', 'SUSPENDIDO'];
        const estadoUpper = String(estado).trim().toUpperCase();
        if (!estadosValidos.includes(estadoUpper)) {
            throw new Error(`Estado inválido. Debe ser uno de: ${estadosValidos.join(', ')}`);
        }

        const { data, error } = await supabase
            .from('perfiles_gestor')
            .update({ estado_verificacion: estadoUpper })
            .eq('id', id)
            .select();

        if (error) {
            throw new Error(`Error al actualizar estado del gestor: ${error.message}`);
        }
        return data;
    },

    // Elimina el gestor y sus dependencias en la tabla intermedia
    async deleteGestor(id) {
        if (!id) {
            throw new Error('El identificador del gestor es obligatorio para la eliminación.');
        }

        await supabase
            .from('gestor_material')
            .delete()
            .eq('gestor_id', id);

        const { error } = await supabase
            .from('perfiles_gestor')
            .delete()
            .eq('id', id);

        if (error) {
            throw new Error(`Error en base de datos al eliminar gestor: ${error.message}`);
        }

        return true;
    }
};

module.exports = gestorService;