const supabase = require('../config/supabase');

const authService = {
    async login(email, password) {
        if (!email || !password) {
            throw new Error('Debe proporcionar tanto el correo electrónico como la contraseña.');
        }

        // Limpiamos espacios y pasamos a minúsculas para evitar fallos de tipeo
        const sanitizedEmail = String(email).trim().toLowerCase();

        const { data, error } = await supabase.auth.signInWithPassword({
            email: sanitizedEmail,
            password: password
        });

        if (error) {
            throw new Error(error.message || 'Error al autenticar las credenciales ingresadas.');
        }

        return {
            session: data.session,
            user: data.user
        };
    },

    async logout() {
        const { error } = await supabase.auth.signOut();

        if (error) {
            throw new Error(error.message || 'Error al cerrar sesión.');
        }

        return { success: true };
    }
};

module.exports = authService;


