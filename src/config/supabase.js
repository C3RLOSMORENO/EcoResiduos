const { createClient } = require('@supabase/supabase-js');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY && process.env.SUPABASE_SERVICE_ROLE_KEY.trim();
const anonKey = process.env.SUPABASE_ANON_KEY && process.env.SUPABASE_ANON_KEY.trim();
const supabaseKey = serviceKey || anonKey;

if (!supabaseUrl || !supabaseKey) {
    throw new Error('Faltan credenciales de Supabase en el archivo .env');
}

const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: {
        persistSession: false,
        autoRefreshToken: false
    }
});

module.exports = supabase;