const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY && process.env.SUPABASE_SERVICE_ROLE_KEY.trim();
const anonKey = process.env.SUPABASE_ANON_KEY && process.env.SUPABASE_ANON_KEY.trim();
const supabaseKey = serviceKey || anonKey;

if (!supabaseUrl || !supabaseKey) {
    throw new Error('Faltan las credenciales SUPABASE_URL y SUPABASE_ANON_KEY (o SUPABASE_SERVICE_ROLE_KEY) en el entorno.');
}

const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false }
});

module.exports = supabase;