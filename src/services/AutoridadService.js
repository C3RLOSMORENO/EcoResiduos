const supabase = require('../config/supabase');

const autoridadService = {
    // Consulta autoridades ambientales registradas en el departamento de Santander
    async getAllAutoridades() {
        const { data, error } = await supabase
            .from('autoridades_ambientales')
            .select('*')
            .order('id', { ascending: true });

        if (error) {
            throw new Error(`Error en base de datos al listar autoridades: ${error.message}`);
        }

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

    // Valida y registra una nueva entidad de control ambiental
    async createAutoridad(dto = {}) {
        let siglaLimpia = String(dto.sigla || '').trim().toUpperCase();
        const nombreLimpio = String(dto.nombre || '').trim();
        const jurisdiccionLimpia = String(dto.jurisdiccion || 'Santander').trim();
        const telefonoLimpio = String(dto.telefono || 'Sin registrar').trim();
        let emailLimpio = String(dto.email || '').trim().toLowerCase();
        let sitioWebLimpio = String(dto.sitio_web || '').trim();
        const direccionLimpia = String(dto.direccion || dto.municipio || 'Santander').trim();

        if (!nombreLimpio || nombreLimpio.length < 3) {
            throw new Error('El nombre institucional de la autoridad es obligatorio.');
        }

        if (!siglaLimpia) {
            siglaLimpia = nombreLimpio.substring(0, 4).toUpperCase();
        }

        if (!emailLimpio) {
            emailLimpio = 'contacto@autoridad.gov.co';
        }

        if (!sitioWebLimpio) {
            sitioWebLimpio = 'https://www.santander.gov.co';
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

        let siglaLimpia = String(dto.sigla || '').trim().toUpperCase();
        const nombreLimpio = String(dto.nombre || '').trim();
        const jurisdiccionLimpia = String(dto.jurisdiccion || 'Santander').trim();
        const telefonoLimpio = String(dto.telefono || 'Sin registrar').trim();
        let emailLimpio = String(dto.email || '').trim().toLowerCase();
        let sitioWebLimpio = String(dto.sitio_web || '').trim();
        const direccionLimpia = String(dto.direccion || dto.municipio || 'Santander').trim();

        if (!nombreLimpio || nombreLimpio.length < 3) {
            throw new Error('El nombre institucional de la autoridad es obligatorio.');
        }

        if (!siglaLimpia) {
            siglaLimpia = nombreLimpio.substring(0, 4).toUpperCase();
        }

        if (!emailLimpio) {
            emailLimpio = 'contacto@autoridad.gov.co';
        }

        if (!sitioWebLimpio) {
            sitioWebLimpio = 'https://www.santander.gov.co';
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