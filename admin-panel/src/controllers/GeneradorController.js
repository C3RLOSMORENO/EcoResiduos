const GeneradorService = require('../services/GeneradorService');

exports.listarGeneradores = async (req, res) => {
    try {
        const generadores = await GeneradorService.listarTodos();
        res.render('generadores', {
            activeTab: 'generadores',
            generadores,
            error: req.query.error,
            success: req.query.success
        });
    } catch (error) {
        res.render('generadores', {
            activeTab: 'generadores',
            generadores: [],
            error: 'No se pudieron cargar los usuarios ciudadanos.',
            success: null
        });
    }
};
