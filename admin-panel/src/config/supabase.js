const { createClient } = require('@supabase/supabase-js');
const { cargarEntorno } = require('./entorno');
const { fetchConLimite } = require('../utils/tiempoLimite');

cargarEntorno();

const supabaseUrl = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY && process.env.SUPABASE_SERVICE_ROLE_KEY.trim();
const anonKey = process.env.SUPABASE_ANON_KEY && process.env.SUPABASE_ANON_KEY.trim();

// El panel administra datos protegidos por RLS: sin la llave service_role no
// funciona. server.js ya lo revisa al arrancar con un mensaje más detallado;
// esto cubre a quien cargue el módulo por otro camino.
if (!supabaseUrl || !serviceKey || !anonKey) {
    throw new Error('Faltan SUPABASE_URL, SUPABASE_ANON_KEY o SUPABASE_SERVICE_ROLE_KEY en el archivo .env');
}

const opcionesServidor = {
    auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false
    },
    global: { fetch: fetchConLimite() }
};

// Cliente de datos con service_role. Nunca se inicia sesión con él: si lo
// hiciera, pasaría a enviar el token de ese usuario y lo compartirían todas
// las peticiones del servidor.
const supabase = createClient(supabaseUrl, serviceKey, opcionesServidor);

// Cliente nuevo por petición para iniciar sesión con correo y contraseña.
function crearClienteAuth() {
    return createClient(supabaseUrl, anonKey, opcionesServidor);
}

module.exports = supabase;
module.exports.crearClienteAuth = crearClienteAuth;
