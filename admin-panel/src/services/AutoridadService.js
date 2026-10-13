const supabase = require('../config/supabase');

const { rango, textoBusqueda } = require('../utils/web');
const { errorDeBase, noEncontrado } = require('../utils/errores');

const autoridadService = {
    /**
     * Página de autoridades ordenadas por nombre, con búsqueda por nombre, sigla
     * o jurisdicción.
     *
     * @param {{q?: string, pagina?: number}} [opciones]
     * @returns {Promise<{autoridades: object[], total: number}>}
     * @throws {Error} Si falla la consulta.
     */
    async listarAutoridades({ q, pagina = 1 } = {}) {
        let consulta = supabase
            .from('autoridades_ambientales')
            .select('*', { count: 'exact' });

        const termino = textoBusqueda(q);
        if (termino) {
            consulta = consulta.or(`nombre.ilike.%${termino}%,sigla.ilike.%${termino}%,jurisdiccion.ilike.%${termino}%`);
        }

        const { desde, hasta } = rango(pagina);
        const { data, error, count } = await consulta
            .order('nombre', { ascending: true })
            .range(desde, hasta);

        if (error) {
            throw errorDeBase('No pudimos cargar las autoridades.', error);
        }
        return { autoridades: data || [], total: count || 0 };
    },

    /**
     * Todas las autoridades ambientales, ordenadas por identificador.
     *
     * @returns {Promise<object[]>}
     * @throws {Error} Si falla la consulta.
     */
    async getAllAutoridades() {
        const { data, error } = await supabase
            .from('autoridades_ambientales')
            .select('*')
            .order('id', { ascending: true });

        if (error) {
            throw errorDeBase('No pudimos cargar las autoridades.', error);
        }

        return (data || []).map((row) => ({
            id: row.id ?? row.ID,
            nombre: row.nombre ?? row.NOMBRE ?? '',
            sigla: row.sigla ?? row.SIGLA ?? '',
            jurisdiccion: row.jurisdiccion ?? row.JURISDICCION ?? '',
            telefono: row.telefono ?? row.TELEFONO ?? '',
            email: row.email ?? row.EMAIL ?? '',
            sitio_web: row.sitio_web ?? row.SITIO_WEB ?? row.Sitio_Web ?? '',
            direccion: row.direccion ?? row.DIRECCION ?? '',
            horario: row.horario ?? ''
        }));
    },

    /**
     * @param {number|string} id
     * @returns {Promise<object>} La autoridad con los campos que usa el formulario.
     * @throws {Error} Con codigo NO_ENCONTRADO si no existe.
     */
    async getAutoridadById(id) {
        if (!id) {
            throw new Error('El identificador de la autoridad es obligatorio.');
        }

        const { data, error } = await supabase
            .from('autoridades_ambientales')
            .select('*')
            .eq('id', id)
            .maybeSingle();

        if (error) throw errorDeBase('No pudimos cargar la autoridad.', error);
        if (!data) {
            throw noEncontrado('No encontramos la autoridad.');
        }

        return {
            id: data.id ?? data.ID,
            nombre: data.nombre ?? data.NOMBRE ?? '',
            sigla: data.sigla ?? data.SIGLA ?? '',
            jurisdiccion: data.jurisdiccion ?? data.JURISDICCION ?? '',
            telefono: data.telefono ?? data.TELEFONO ?? '',
            email: data.email ?? data.EMAIL ?? '',
            sitio_web: data.sitio_web ?? data.SITIO_WEB ?? data.Sitio_Web ?? '',
            direccion: data.direccion ?? data.DIRECCION ?? '',
            horario: data.horario ?? ''
        };
    },

    /**
     * Registra una autoridad. El nombre es obligatorio; si faltan la sigla, el
     * correo o el sitio web, se completan con valores por defecto.
     *
     * @param {object} [dto] Campos del formulario.
     * @returns {Promise<object[]>} La fila creada.
     * @throws {Error} Si el nombre tiene menos de 3 caracteres o falla la base.
     */
    async createAutoridad(dto = {}) {
        let siglaLimpia = String(dto.sigla || '').trim().toUpperCase();
        const nombreLimpio = String(dto.nombre || '').trim();
        const jurisdiccionLimpia = String(dto.jurisdiccion || 'Santander').trim();
        const telefonoLimpio = String(dto.telefono || 'Sin registrar').trim();
        let emailLimpio = String(dto.email || '').trim().toLowerCase();
        let sitioWebLimpio = String(dto.sitio_web || '').trim();
        const direccionLimpia = String(dto.direccion || dto.municipio || 'Santander').trim();
        const horarioLimpio = String(dto.horario || '').trim();

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
            direccion: direccionLimpia,
            horario: horarioLimpio || null
        };

        const { data, error } = await supabase
            .from('autoridades_ambientales')
            .insert([payloadAutoridad])
            .select();

        if (error) {
            throw errorDeBase('No pudimos guardar la autoridad.', error);
        }

        return data;
    },

    /**
     * Mismas validaciones y valores por defecto que createAutoridad.
     *
     * @param {number|string} id
     * @param {object} [dto] Campos del formulario.
     * @returns {Promise<object[]>} La fila actualizada.
     * @throws {Error} Si el nombre tiene menos de 3 caracteres o falla la base.
     */
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
        const horarioLimpio = String(dto.horario || '').trim();

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
            direccion: direccionLimpia,
            horario: horarioLimpio || null
        };

        const { data, error } = await supabase
            .from('autoridades_ambientales')
            .update(payloadUpdate)
            .eq('id', id)
            .select();

        if (error) {
            throw errorDeBase('No pudimos guardar los cambios de la autoridad.', error);
        }

        return data;
    },

    /**
     * @param {number|string} id
     * @returns {Promise<true>}
     * @throws {Error} Si falla la base.
     */
    async deleteAutoridad(id) {
        if (!id) {
            throw new Error('El identificador de la autoridad es obligatorio para eliminarla.');
        }

        const { error } = await supabase
            .from('autoridades_ambientales')
            .delete()
            .eq('id', id);

        if (error) {
            throw errorDeBase('No pudimos eliminar la autoridad.', error);
        }

        return true;
    }
};

module.exports = autoridadService;