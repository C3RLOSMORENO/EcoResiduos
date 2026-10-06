const supabase = require('../config/supabase');
const { claveMetadatos } = require('../utils/recorridos');

const recorridoService = {
    // Guarda en los metadatos del usuario hasta qué versión vio el recorrido
    // de una pantalla. Se guarda en la cuenta y no solo en el navegador: el
    // administrador no vuelve a verlo en otro equipo.
    async guardar(usuarioId, pantalla, { version, estado, paso }) {
        const { error } = await supabase.auth.admin.updateUserById(usuarioId, {
            user_metadata: {
                [claveMetadatos(pantalla)]: { version, estado, paso, fecha: new Date().toISOString() }
            }
        });
        if (error) {
            console.error(`No se guardó el recorrido ${pantalla}: ${error.message}`);
            throw new Error('No pudimos guardar el recorrido.');
        }
    }
};

module.exports = recorridoService;
