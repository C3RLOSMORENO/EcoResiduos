const SolicitudService = require('../services/SolicitudService');

exports.listarSolicitudes = async (req, res) => {
    try {
        const solicitudes = await SolicitudService.listarTodas();
        res.render('solicitudes', {
            activeTab: 'solicitudes',
            solicitudes,
            error: req.query.error,
            success: req.query.success
        });
    } catch (error) {
        res.render('solicitudes', {
            activeTab: 'solicitudes',
            solicitudes: [],
            error: 'No se pudieron cargar las solicitudes de recolección.',
            success: null
        });
    }
};

exports.cambiarEstado = async (req, res) => {
    try {
        const { id } = req.params;
        const { estado } = req.body;
        await SolicitudService.cambiarEstado(id, estado);
        res.redirect('/solicitudes?success=Estado+actualizado+correctamente');
    } catch (error) {
        res.redirect('/solicitudes?error=Error+al+actualizar+el+estado');
    }
};
