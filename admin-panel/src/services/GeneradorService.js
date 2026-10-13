const supabase = require('../config/supabase');
const { municipioAdmitido, variantesMunicipio } = require('../utils/municipios');
const { rango, textoBusqueda } = require('../utils/web');
const { errorDeBase } = require('../utils/errores');

class GeneradorService {
    /**
     * Listado paginado. Solo los datos que necesita la lista (Ley 1581 de 2012).
     *
     * @param {{q?: string, municipio?: string, pagina?: number}} [opciones]
     * @returns {Promise<{generadores: object[], total: number}>} Cada generador con
     *     el número de publicaciones que ha hecho.
     * @throws {Error} Si falla la consulta.
     */
    async listar({ q, municipio, pagina = 1 } = {}) {
        let consulta = supabase
            .from('perfiles_generador')
            .select('id, usuario_id, nombre_completo_o_empresa, documento_nit, email, telefono, municipio, created_at', { count: 'exact' });

        const termino = textoBusqueda(q);
        if (termino) {
            consulta = consulta.or(`nombre_completo_o_empresa.ilike.%${termino}%,documento_nit.ilike.%${termino}%`);
        }
        const municipioFiltro = municipioAdmitido(municipio);
        if (municipioFiltro) consulta = consulta.in('municipio', variantesMunicipio(municipioFiltro));

        const { desde, hasta } = rango(pagina);
        const { data, error, count } = await consulta
            .order('created_at', { ascending: false })
            .range(desde, hasta);

        if (error) {
            throw errorDeBase('No pudimos cargar los ciudadanos.', error);
        }

        const generadores = data || [];
        const publicaciones = await this.contarPublicaciones(generadores.map((g) => g.id));
        return {
            generadores: generadores.map((g) => ({ ...g, publicaciones: publicaciones.get(g.id) || 0 })),
            total: count || 0
        };
    }

    /**
     * Un conteo por generador de la página (máximo 25 consultas pequeñas).
     *
     * @param {number[]} ids
     * @returns {Promise<Map<number, number>>}
     */
    async contarPublicaciones(ids) {
        const conteos = await Promise.all(ids.map((id) => supabase
            .from('solicitudes_recoleccion')
            .select('id', { count: 'exact', head: true })
            .eq('generador_id', id)));
        return new Map(ids.map((id, i) => [id, conteos[i].count || 0]));
    }
}

module.exports = new GeneradorService();
