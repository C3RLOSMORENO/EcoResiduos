const asistenteService = require('../services/AsistenteService');
const { crearLimite } = require('../utils/limiteIntentos');

// Preguntas por administrador: el plan gratis de Gemini tiene cuota por
// minuto y por día, y una pestaña olvidada en un bucle no debe gastarla.
const limite = crearLimite({ maximo: 20, ventanaMs: 5 * 60 * 1000 });

const asistenteController = {
    /** POST /asistente/preguntar: responde en JSON la última pregunta del historial. */
    async preguntar(req, res) {
        const historial = asistenteService.historialValido(req.body && req.body.historial);
        if (!historial) {
            return res.status(400).json({ ok: false, mensaje: 'Escribe una pregunta para el asistente.' });
        }

        const clave = (req.user && req.user.id) || req.ip;
        const espera = limite.espera(clave);
        if (espera > 0) {
            const minutos = Math.ceil(espera / 60000);
            return res.status(429).json({ ok: false, mensaje: `Hiciste muchas preguntas seguidas. Intenta de nuevo en ${minutos} ${minutos === 1 ? 'minuto' : 'minutos'}.` });
        }
        limite.fallo(clave);

        try {
            const { respuesta, consultas } = await asistenteService.preguntar(historial);
            return res.json({ ok: true, respuesta, consultas });
        } catch (err) {
            if (err instanceof asistenteService.ErrorAsistente) {
                return res.status(err.estado).json({ ok: false, mensaje: err.message });
            }
            console.error('Error del asistente:', err);
            return res.status(500).json({ ok: false, mensaje: 'El asistente no pudo responder. Inténtalo de nuevo en unos minutos.' });
        }
    }
};

module.exports = asistenteController;
module.exports.limite = limite;
