// Panel con Supabase simulado para las pruebas de extremo a extremo. Guarda
// en memoria lo que cambia el administrador (por ejemplo, aprobar un gestor)
// para que la página siguiente lo muestre. Nunca toca la base de datos real.
const PUERTO = Number(process.env.PUERTO_E2E || 3998);
// Supabase «vive» en este mismo servidor: así se pueden servir los logos y
// portadas del bucket público fotos_perfil, y la CSP los admite.
process.env.SUPABASE_URL = process.env.SUPABASE_URL || `http://localhost:${PUERTO}`;
// El asistente aparece activo; la prueba responde la pregunta en el navegador
// y nunca se llama a Gemini.
process.env.GEMINI_API_KEY = 'llave-e2e';

const express = require('express');
const { instalarSupabaseFalso } = require('../apoyo/supabaseFalso');
const datos = require('../apoyo/datos');

const supabase = instalarSupabaseFalso();
require('../../src/services/geocodificador').geocodificar = async () => null;
const app = require('../../src/crearApp')();

// La foto se sirve desde el mismo panel porque la CSP solo admite imágenes
// propias y de Supabase.
const FOTO = `http://localhost:${PUERTO}/__e2e/foto.svg`;
const CUENTA_GESTOR = '7d5c2a3e-1f4b-4c8d-9e6a-2b3c4d5e6f70';
let gestor;
function reiniciar() {
    gestor = structuredClone({
        ...datos.gestor,
        municipio: 'GIRÓN',
        usuario_id: CUENTA_GESTOR,
        foto_perfil_path: `${CUENTA_GESTOR}/perfil/1.png`,
        portada_path: `${CUENTA_GESTOR}/portada/1.jpg`
    });
    // El administrador vuelve a ser nuevo: no ha visto ningún recorrido.
    supabase.metadatos = {};
}
reiniciar();
const solicitud = { ...datos.solicitud, municipio: 'BUCARAMANGA', foto_url: FOTO };

supabase.manejador = (consulta) => {
    if (consulta.tabla === 'perfiles_gestor' && consulta.accion === 'update') {
        Object.assign(gestor, consulta.payload);
        return { data: null };
    }
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
// Logo y portada de ejemplo del gestor, en la ruta pública de Storage.
servidor.get('/storage/v1/object/public/fotos_perfil/:cuenta/:carpeta/:archivo', (req, res) => {
    res.type('image/svg+xml');
    if (req.params.carpeta === 'portada') {
        return res.send(`<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="600" viewBox="0 0 1600 600">
<rect width="1600" height="600" fill="#2f5d3a"/><path d="M0 420 Q400 300 800 400 T1600 360 V600 H0Z" fill="#4f8a5b"/>
<path d="M0 500 Q500 420 1000 500 T1600 470 V600 H0Z" fill="#7fb38a"/></svg>`);
    }
    return res.send(`<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
<circle cx="256" cy="256" r="200" fill="#1f6b3a"/><path d="M256 130 C330 200 330 300 256 380 C182 300 182 200 256 130Z" fill="#b8e6be"/></svg>`);
});
// Cada prueba empieza con el gestor pendiente de revisión.
servidor.post('/__e2e/reiniciar', (req, res) => { reiniciar(); res.sendStatus(204); });
servidor.use(app);
servidor.listen(PUERTO, () => console.log(`Panel de prueba en http://localhost:${PUERTO}`));
