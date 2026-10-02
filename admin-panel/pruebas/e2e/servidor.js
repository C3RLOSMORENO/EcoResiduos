// Panel con Supabase simulado para las pruebas de extremo a extremo. Guarda
// en memoria lo que cambia el administrador (por ejemplo, aprobar un gestor)
// para que la página siguiente lo muestre. Nunca toca la base de datos real.
process.env.SUPABASE_URL = process.env.SUPABASE_URL || 'https://proyecto.supabase.co';

const express = require('express');
const { instalarSupabaseFalso } = require('../apoyo/supabaseFalso');
const datos = require('../apoyo/datos');

const supabase = instalarSupabaseFalso();
require('../../src/services/geocodificador').geocodificar = async () => null;
const app = require('../../src/crearApp')();

const PUERTO = Number(process.env.PUERTO_E2E || 3998);

// La foto se sirve desde el mismo panel porque la CSP solo admite imágenes
// propias y de Supabase.
const FOTO = `http://localhost:${PUERTO}/__e2e/foto.svg`;
let gestor;
function reiniciar() {
    gestor = structuredClone({ ...datos.gestor, municipio: 'GIRÓN' });
}
reiniciar();
const solicitud = { ...datos.solicitud, municipio: 'BUCARAMANGA', foto_url: FOTO };

supabase.manejador = (consulta) => {
    if (consulta.tabla === 'perfiles_gestor' && consulta.accion === 'select') {
        return consulta.modo === 'lista' ? { data: [gestor], count: 1 } : { data: gestor };
    }
    if (consulta.tabla === 'solicitudes_recoleccion' && consulta.accion === 'select' && !consulta.opciones.head) {
        return consulta.modo === 'lista' ? { data: [solicitud], count: 1 } : { data: solicitud };
    }
    return datos.responderConDatos(consulta);
};
supabase.manejadorRpc = (nombre, params) => {
    if (nombre === 'cambiar_verificacion_gestor_admin') {
        gestor.estado_verificacion = params.p_estado;
        gestor.gestor_material = gestor.gestor_material.map((gm) => ({ ...gm, verificado: true }));
    }
    return { data: null, error: null };
};

const servidor = express();
servidor.get('/__e2e/foto.svg', (req, res) => {
    res.type('image/svg+xml').send(`<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900" viewBox="0 0 1600 900">
<rect width="1600" height="900" fill="#5f7d5a"/><circle cx="400" cy="450" r="220" fill="#e6c34a"/></svg>`);
});
// Cada prueba empieza con el gestor pendiente de revisión.
servidor.post('/__e2e/reiniciar', (req, res) => { reiniciar(); res.sendStatus(204); });
servidor.use(app);
servidor.listen(PUERTO, () => console.log(`Panel de prueba en http://localhost:${PUERTO}`));
