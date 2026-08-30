const supabase = require('../config/supabase');

const autoridadService = {
    async getAllAutoridades() {
        const { data, error } = await supabase
            .from('autoridades_ambientales')
            .select('*')
            .order('id', { ascending: true });

        if (error) {
            throw new Error(`Error en base de datos al listar autoridades: ${error.message}`);
        }

        // Mapeo tolerante si las columnas vienen en mayúsculas o minúsculas
        return (data || []).map((row) => ({
            id: row.id ?? row.ID,
            nombre: row.nombre ?? row.NOMBRE ?? '',
            sigla: row.sigla ?? row.SIGLA ?? '',
            jurisdiccion: row.jurisdiccion ?? row.JURISDICCION ?? '',
            telefono: row.telefono ?? row.TELEFONO ?? '',
            email: row.email ?? row.EMAIL ?? '',
            sitio_web: row.sitio_web ?? row.SITIO_WEB ?? row.Sitio_Web ?? '',
            direccion: row.direccion ?? row.DIRECCION ?? ''
        }));
    },

    async getAutoridadById(id) {
        if (!id) {
            throw new Error('El identificador de la autoridad es obligatorio.');
        }

        const { data, error } = await supabase
            .from('autoridades_ambientales')
            .select('*')
            .eq('id', id)
            .single();

        if (error || !data) {
            throw new Error(`Error al obtener autoridad: ${error ? error.message : 'Autoridad no encontrada'}`);
        }

        return {
            id: data.id ?? data.ID,
            nombre: data.nombre ?? data.NOMBRE ?? '',
            sigla: data.sigla ?? data.SIGLA ?? '',
            jurisdiccion: data.jurisdiccion ?? data.JURISDICCION ?? '',
            telefono: data.telefono ?? data.TELEFONO ?? '',
            email: data.email ?? data.EMAIL ?? '',
            sitio_web: data.sitio_web ?? data.SITIO_WEB ?? data.Sitio_Web ?? '',
            direccion: data.direccion ?? data.DIRECCION ?? ''
        };
    },

    async createAutoridad(dto = {}) {
        // Sigla institucional en mayúsculas (ej: CDMB, CAS, AMB)
        const siglaLimpia = String(dto.sigla || '').trim().toUpperCase();
        const nombreLimpio = String(dto.nombre || '').trim();
        const jurisdiccionLimpia = String(dto.jurisdiccion || '').trim();
        const telefonoLimpio = String(dto.telefono || '').trim();
        const emailLimpio = String(dto.email || '').trim().toLowerCase();
        const sitioWebLimpio = String(dto.sitio_web || '').trim();
        const direccionLimpia = String(dto.direccion || '').trim();

        if (!siglaLimpia || siglaLimpia.length < 2) {
            throw new Error('La sigla oficial de la autoridad es obligatoria (ejemplo: CDMB, CAS, AMB).');
        }

        if (!nombreLimpio || nombreLimpio.length < 5) {
            throw new Error('El nombre institucional de la autoridad es obligatorio y debe tener al menos 5 caracteres.');
        }

        if (!jurisdiccionLimpia) {
            throw new Error('La jurisdicción territorial de la autoridad es obligatoria.');
        }

        if (!telefonoLimpio) {
            throw new Error('El teléfono institucional de contacto es obligatorio.');
        }

        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(emailLimpio)) {
            throw new Error('El correo electrónico institucional no tiene un formato válido (ejemplo: contacto@cdmb.gov.co).');
        }

        const urlRegex = /^(https?:\/\/)?([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(\/[^\s]*)?$/i;
        if (!sitioWebLimpio || !urlRegex.test(sitioWebLimpio)) {
            throw new Error('El portal web oficial debe ser una URL válida (ejemplo: https://www.cdmb.gov.co).');
        }

        if (!direccionLimpia) {
            throw new Error('La dirección física de la sede principal es obligatoria.');
        }

        const payloadAutoridad = {
            sigla: siglaLimpia,
            nombre: nombreLimpio,
            jurisdiccion: jurisdiccionLimpia,
            telefono: telefonoLimpio,
            email: emailLimpio,
            sitio_web: sitioWebLimpio,
            direccion: direccionLimpia
        };

        const { data, error } = await supabase
            .from('autoridades_ambientales')
            .insert([payloadAutoridad])
            .select();

        if (error) {
            throw new Error(`Error en base de datos al crear autoridad: ${error.message}`);
        }

        return data;
    },

    async updateAutoridad(id, dto = {}) {
        if (!id) {
            throw new Error('El identificador de la autoridad es obligatorio para la actualización.');
        }

        const siglaLimpia = String(dto.sigla || '').trim().toUpperCase();
        const nombreLimpio = String(dto.nombre || '').trim();
        const jurisdiccionLimpia = String(dto.jurisdiccion || '').trim();
        const telefonoLimpio = String(dto.telefono || '').trim();
        const emailLimpio = String(dto.email || '').trim().toLowerCase();
        const sitioWebLimpio = String(dto.sitio_web || '').trim();
        const direccionLimpia = String(dto.direccion || '').trim();

        if (!siglaLimpia || siglaLimpia.length < 2) {
            throw new Error('La sigla oficial de la autoridad es obligatoria (ejemplo: CDMB, CAS, AMB).');
        }

        if (!nombreLimpio || nombreLimpio.length < 5) {
            throw new Error('El nombre institucional de la autoridad es obligatorio y debe tener al menos 5 caracteres.');
        }

        if (!jurisdiccionLimpia) {
            throw new Error('La jurisdicción territorial de la autoridad es obligatoria.');
        }

        if (!telefonoLimpio) {
            throw new Error('El teléfono institucional de contacto es obligatorio.');
        }

        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(emailLimpio)) {
            throw new Error('El correo electrónico institucional no tiene un formato válido (ejemplo: contacto@cdmb.gov.co).');
        }

        const urlRegex = /^(https?:\/\/)?([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(\/[^\s]*)?$/i;
        if (!sitioWebLimpio || !urlRegex.test(sitioWebLimpio)) {
            throw new Error('El portal web oficial debe ser una URL válida (ejemplo: https://www.cdmb.gov.co).');
        }

        if (!direccionLimpia) {
            throw new Error('La dirección física de la sede principal es obligatoria.');
        }

        const payloadUpdate = {
            sigla: siglaLimpia,
            nombre: nombreLimpio,
            jurisdiccion: jurisdiccionLimpia,
            telefono: telefonoLimpio,
            email: emailLimpio,
            sitio_web: sitioWebLimpio,
            direccion: direccionLimpia
        };

        const { data, error } = await supabase
            .from('autoridades_ambientales')
            .update(payloadUpdate)
            .eq('id', id)
            .select();

        if (error) {
            throw new Error(`Error en base de datos al actualizar autoridad: ${error.message}`);
        }

        return data;
    },

    async deleteAutoridad(id) {
        if (!id) {
            throw new Error('El identificador de la autoridad es obligatorio para eliminarla.');
        }

        const { error } = await supabase
            .from('autoridades_ambientales')
            .delete()
            .eq('id', id);

        if (error) {
            throw new Error(`Error en base de datos al eliminar autoridad: ${error.message}`);
        }

        return true;
    }
};

module.exports = autoridadService;