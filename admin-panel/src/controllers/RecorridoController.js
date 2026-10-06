const recorridoService = require('../services/RecorridoService');
const { RECORRIDOS, registroValido } = require('../utils/recorridos');

const recorridoController = {
    // El navegador avisa cuando muestra, termina o salta un recorrido. Si no
    // se puede guardar, el panel sigue igual: el navegador ya lo anotó y no
    // lo vuelve a mostrar en este equipo.
    async guardar(req, res) {
        const pantalla = req.params.pantalla;
        if (!Object.prototype.hasOwnProperty.call(RECORRIDOS, pantalla)) {
            return res.status(404).json({ ok: false, mensaje: 'Esa pantalla no tiene recorrido.' });
        }
        const registro = registroValido(pantalla, req.body);
        if (!registro) {
            return res.status(400).json({ ok: false, mensaje: 'Datos del recorrido no válidos.' });
        }
        try {
            await recorridoService.guardar(req.user.id, pantalla, registro);
            return res.status(200).json({ ok: true });
        } catch (err) {
            return res.status(503).json({ ok: false, mensaje: err.message });
        }
    }
};

module.exports = recorridoController;
