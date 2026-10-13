const GeneradorService = require('../services/GeneradorService');
const { leerPagina, paginacion } = require('../utils/web');
const { renderLista } = require('../utils/errores');
const { filtrosCiudadanos } = require('../utils/filtros');

/** GET /ciudadanos: generadores registrados en la app, con búsqueda y municipio. */
exports.listarGeneradores = (req, res) => {
    const pagina = leerPagina(req.query);
    const filtros = filtrosCiudadanos(req.query);
    return renderLista(res, 'generadores', {
        comunes: { titulo: 'Ciudadanos', activeTab: 'generadores', filtros },
        cargar: async () => {
            const { generadores, total } = await GeneradorService.listar({ ...filtros, pagina });
            return { generadores, pag: paginacion({ total, pagina, ruta: '/ciudadanos', query: req.query }) };
        },
        vacio: { generadores: [], pag: null }
    });
};
