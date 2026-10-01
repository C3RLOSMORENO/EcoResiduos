const GeneradorService = require('../services/GeneradorService');
const { leerPagina, paginacion } = require('../utils/web');
const { municipioAdmitido } = require('../utils/municipios');

exports.listarGeneradores = async (req, res) => {
    const pagina = leerPagina(req.query);
    const filtros = {
        q: String(req.query.q || '').trim(),
        municipio: municipioAdmitido(req.query.municipio) || ''
    };
    try {
        const { generadores, total } = await GeneradorService.listar({ ...filtros, pagina });
        res.render('generadores', {
            titulo: 'Ciudadanos',
            activeTab: 'generadores',
            generadores,
            filtros,
            pag: paginacion({ total, pagina, ruta: '/ciudadanos', query: req.query }),
            errorCarga: null
        });
    } catch (error) {
        res.status(500).render('generadores', {
            titulo: 'Ciudadanos',
            activeTab: 'generadores',
            generadores: [],
            filtros,
            pag: null,
            errorCarga: error.message
        });
    }
};
