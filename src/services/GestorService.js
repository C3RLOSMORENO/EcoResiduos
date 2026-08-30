const supabase = require('../config/supabase');

// Convierte los IDs de materiales seleccionados a un arreglo de números limpios
function extractMaterialIds(dto) {
    const raw = dto.materiales_ids || dto['materiales_ids[]'] || dto.material_ids || [];
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
    async getAllGestores() {
        // Traemos gestores y sus materiales autorizados mediante la tabla intermedia gestor_material
        const { data, error } = await supabase
            .from('perfiles_gestor')
            .select(`
                *,
                gestor_material (
                    material_id,
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

        // Aplanamos la lista de materiales y aseguramos valores por defecto si una columna viene nula
        return (data || []).map((row) => {
            const materiales = (row.gestor_material || [])
                .map((gm) => gm.materiales_residuos)
                .filter(Boolean);

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
                materiales
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
            materiales
        };
    },

    async createGestor(dto = {}) {
        // Limpiamos texto para evitar inconsistencias en búsquedas y filtros
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

        // Validaciones de negocio antes de tocar la base de datos
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

        // Geocodificación pasiva: convertimos dirección a GPS con fallback a Bucaramanga si falla la API
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
            // Si Nominatim falla o no hay internet, usamos las coordenadas centrales de la ciudad
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

        // Guardamos la relación N:M en la tabla intermedia
        if (nuevoGestor && materialIds.length > 0) {
            const relaciones = materialIds.map((matId) => ({
                gestor_id: nuevoGestor.id,
                material_id: matId
            }));

            await supabase
                .from('gestor_material')
                .insert(relaciones);
        }

        return gestorCreado;
    },

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

        // Recalculamos coordenadas por si la dirección cambió
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
            // Fallback a coordenadas de Bucaramanga si falla la API
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

        const { data: gestorActualizado, error: gestorError } = await supabase
            .from('perfiles_gestor')
            .update(payloadUpdate)
            .eq('id', id)
            .select();

        if (gestorError) {
            throw new Error(`Error en base de datos al actualizar gestor: ${gestorError.message}`);
        }

        // Sincronizamos materiales: borramos los anteriores e insertamos la nueva selección
        await supabase
            .from('gestor_material')
            .delete()
            .eq('gestor_id', id);

        if (materialIds.length > 0) {
            const relaciones = materialIds.map((matId) => ({
                gestor_id: parseInt(id, 10),
                material_id: matId
            }));

            await supabase
                .from('gestor_material')
                .insert(relaciones);
        }

        return gestorActualizado;
    },

    async deleteGestor(id) {
        if (!id) {
            throw new Error('El identificador del gestor es obligatorio para la eliminación.');
        }

        // Borramos primero las relaciones en gestor_material para evitar errores de clave foránea
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