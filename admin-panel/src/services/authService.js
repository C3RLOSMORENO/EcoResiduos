const supabase = require('../config/supabase');
const { crearClienteAuth } = require('../config/supabase');
const { errorDeBase } = require('../utils/errores');

// Supabase Auth no respondió (sin conexión, tiempo agotado o error 5xx). No
// dice nada de la sesión: no hay que cerrarla por esto.
function fallaDelServicio(error) {
    return Boolean(error) && (error.name === 'AuthRetryableFetchError' || Number(error.status) >= 500);
}

function errorServicio(error) {
    console.error('Supabase Auth no respondió:', error.message);
    return errorLogin('SERVICIO', 'No pudimos comprobar la sesión.');
}

// Error de inicio de sesión con un código para que el controlador decida qué
// decir: CREDENCIALES (correo, contraseña o rol) o SERVICIO (Supabase falló).
function errorLogin(codigo, detalle) {
    const error = new Error(detalle || codigo);
    error.codigo = codigo;
    return error;
}

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
            // 400: correo o contraseña errados. Cualquier otro estado es una
            // falla del servicio, que no debe contar como intento fallido.
            throw errorLogin(fallaDelServicio(error) || (error.status && error.status !== 400) ? 'SERVICIO' : 'CREDENCIALES', error.message);
        }

        // Una cuenta de la app (generador o gestor) con la contraseña correcta
        // recibe el mismo mensaje que una contraseña errada: el panel no debe
        // servir para comprobar contraseñas de la app.
        if (!(await this.esAdmin(data.user.id))) {
            await this.logout(data.session.access_token).catch(() => {});
            throw errorLogin('CREDENCIALES', 'La cuenta no tiene rol ADMIN.');
        }

        return {
            session: data.session,
            user: data.user
        };
    },

    // Usuario del token si pertenece a un administrador; null en otro caso
    async getAdmin(accessToken) {
        const { data, error } = await supabase.auth.getUser(accessToken);
        if (fallaDelServicio(error)) throw errorServicio(error);
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
            throw errorDeBase('No pudimos comprobar los permisos de la cuenta.', error);
        }

        return String(data?.rol || '').toUpperCase() === 'ADMIN';
    },

    // Renueva la sesión con el refresh token. Devuelve { session, user } del
    // administrador o null si el token ya no sirve o la cuenta dejó de ser ADMIN.
    async renovar(refreshToken) {
        if (!refreshToken) return null;
        const { data, error } = await crearClienteAuth().auth.refreshSession({ refresh_token: refreshToken });
        if (fallaDelServicio(error)) throw errorServicio(error);
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
            throw errorDeBase('No pudimos cerrar la sesión en Supabase.', error);
        }

        return { success: true };
    }
};

module.exports = authService;
