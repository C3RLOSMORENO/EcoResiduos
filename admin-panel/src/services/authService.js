const supabase = require('../config/supabase');
const { crearClienteAuth } = require('../config/supabase');

const authService = {
    // Autentica credenciales mediante Supabase Auth y exige el rol ADMIN
    async login(email, password) {
        if (!email || !password) {
            throw new Error('Debe proporcionar tanto el correo electrónico como la contraseña.');
        }

        const sanitizedEmail = String(email).trim().toLowerCase();

        const { data, error } = await crearClienteAuth().auth.signInWithPassword({
            email: sanitizedEmail,
            password: password
        });

        if (error) {
            throw new Error('Correo o contraseña incorrectos.');
        }

        if (!(await this.esAdmin(data.user.id))) {
            await this.logout(data.session.access_token);
            throw new Error('Esta cuenta no tiene permisos de administrador.');
        }

        return {
            session: data.session,
            user: data.user
        };
    },

    // Usuario del token si pertenece a un administrador; null en otro caso
    async getAdmin(accessToken) {
        const { data, error } = await supabase.auth.getUser(accessToken);
        if (error || !data || !data.user) {
            return null;
        }
        return (await this.esAdmin(data.user.id)) ? data.user : null;
    },

    // El rol vive en la tabla usuarios, que los clientes de la app no pueden escribir
    async esAdmin(userId) {
        const { data, error } = await supabase
            .from('usuarios')
            .select('rol')
            .eq('id', userId)
            .maybeSingle();

        if (error) {
            throw new Error(`Error al consultar el rol del usuario: ${error.message}`);
        }

        return String(data?.rol || '').toUpperCase() === 'ADMIN';
    },

    // Renueva la sesión con el refresh token. Devuelve { session, user } del
    // administrador o null si el token ya no sirve o la cuenta dejó de ser ADMIN.
    async renovar(refreshToken) {
        if (!refreshToken) return null;
        const { data, error } = await crearClienteAuth().auth.refreshSession({ refresh_token: refreshToken });
        if (error || !data || !data.session || !data.user) {
            return null;
        }
        if (!(await this.esAdmin(data.user.id))) {
            return null;
        }
        return { session: data.session, user: data.user };
    },

    // Revoca la sesión del token en Supabase Auth
    async logout(accessToken) {
        if (!accessToken) {
            return { success: true };
        }

        const { error } = await supabase.auth.admin.signOut(accessToken);

        if (error) {
            throw new Error(error.message || 'Error al cerrar sesión.');
        }

        return { success: true };
    }
};

module.exports = authService;
