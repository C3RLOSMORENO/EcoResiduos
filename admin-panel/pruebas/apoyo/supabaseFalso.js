// Cliente de Supabase simulado: registra cada consulta y responde con lo que
// defina la prueba. Nunca toca la base de datos real.
const path = require('path');

const METODOS_FILTRO = [
    'eq', 'neq', 'in', 'is', 'not', 'or', 'gte', 'gt', 'lte', 'lt', 'ilike', 'like',
    'order', 'range', 'limit', 'filter', 'match', 'contains'
];

class ConsultaFalsa {
    constructor(cliente, tabla) {
        this.cliente = cliente;
        this.tabla = tabla;
        this.accion = 'select';
        this.columnas = null;
        this.opciones = {};
        this.payload = null;
        this.modo = 'lista';
        this.filtros = [];
    }

    select(columnas, opciones) {
        if (this.accion === 'select') {
            this.columnas = columnas;
            this.opciones = opciones || {};
        }
        return this;
    }

    insert(payload) { this.accion = 'insert'; this.payload = payload; return this; }
    update(payload) { this.accion = 'update'; this.payload = payload; return this; }
    delete() { this.accion = 'delete'; return this; }
    single() { this.modo = 'single'; return this; }
    maybeSingle() { this.modo = 'maybeSingle'; return this; }

    // Valor del primer filtro con ese método y columna.
    valor(metodo, columna) {
        const filtro = this.filtros.find((f) => f[0] === metodo && f[1] === columna);
        return filtro ? filtro[2] : undefined;
    }

    then(resolver, rechazar) {
        return Promise.resolve()
            .then(() => this.cliente.responder(this))
            .then(resolver, rechazar);
    }
}

METODOS_FILTRO.forEach((metodo) => {
    ConsultaFalsa.prototype[metodo] = function registrar(...args) {
        this.filtros.push([metodo, ...args]);
        return this;
    };
});

function respuestaPorDefecto(consulta) {
    if (consulta.opciones.head) return { data: null, error: null, count: 0 };
    if (consulta.modo !== 'lista') return { data: null, error: null };
    return { data: [], error: null, count: 0 };
}

function crearClienteFalso() {
    const cliente = {
        consultas: [],
        rpcs: [],
        storageOps: [],
        manejador: null,
        manejadorRpc: null,
        responder(consulta) {
            const r = this.manejador ? this.manejador(consulta) : undefined;
            return r === undefined ? respuestaPorDefecto(consulta) : { error: null, ...r };
        },
        from(tabla) {
            const consulta = new ConsultaFalsa(cliente, tabla);
            cliente.consultas.push(consulta);
            return consulta;
        },
        async rpc(nombre, params) {
            cliente.rpcs.push({ nombre, params });
            const r = cliente.manejadorRpc ? cliente.manejadorRpc(nombre, params) : undefined;
            return r === undefined ? { data: null, error: null } : r;
        },
        storage: {
            from(bucket) {
                return {
                    async createSignedUrl(ruta, segundos) {
                        cliente.storageOps.push({ bucket, op: 'firmar', ruta, segundos });
                        return { data: { signedUrl: `https://almacenamiento.test/${bucket}/${ruta}?firma=1` }, error: null };
                    },
                    async upload(ruta, contenido, opciones) {
                        cliente.storageOps.push({ bucket, op: 'subir', ruta, opciones, tamano: contenido.length });
                        return { data: { path: ruta }, error: null };
                    },
                    async remove(rutas) {
                        cliente.storageOps.push({ bucket, op: 'borrar', rutas });
                        return { data: null, error: null };
                    },
                    async download(ruta) {
                        cliente.storageOps.push({ bucket, op: 'descargar', ruta });
                        const buffer = Buffer.from('%PDF-1.7 contenido');
                        return { data: new Blob([buffer], { type: 'application/pdf' }), error: null };
                    }
                };
            }
        },
        // Metadatos del usuario (user_metadata) por id, como los guarda Supabase Auth.
        metadatos: {},
        authOps: [],
        auth: {
            async getUser(token) {
                if (token === 'token-admin') {
                    return { data: { user: { id: 'admin-1', email: 'admin@ecoresiduos.test', user_metadata: { ...(cliente.metadatos['admin-1'] || {}) } } }, error: null };
                }
                return { data: { user: null }, error: { message: 'JWT expired' } };
            },
            admin: {
                async signOut() { return { error: null }; },
                // Supabase mezcla las claves de primer nivel de user_metadata.
                async updateUserById(id, atributos) {
                    cliente.authOps.push({ op: 'actualizar', id, atributos });
                    cliente.metadatos[id] = { ...(cliente.metadatos[id] || {}), ...(atributos.user_metadata || {}) };
                    return { data: { user: { id, user_metadata: cliente.metadatos[id] } }, error: null };
                }
            }
        },
        limpiar() {
            cliente.consultas.length = 0;
            cliente.rpcs.length = 0;
            cliente.storageOps.length = 0;
            cliente.authOps.length = 0;
            cliente.metadatos = {};
            cliente.manejador = null;
            cliente.manejadorRpc = null;
        }
    };

    // Cliente de autenticación por petición (inicio de sesión y renovación).
    cliente.crearClienteAuth = () => ({
        auth: {
            async signInWithPassword({ email, password }) {
                if (email === 'admin@ecoresiduos.test' && password === 'clave-correcta') {
                    return { data: { user: { id: 'admin-1' }, session: { access_token: 'token-admin', refresh_token: 'refresco-1' } }, error: null };
                }
                return { data: {}, error: { message: 'Invalid login credentials' } };
            },
            async refreshSession({ refresh_token: refresco }) {
                if (refresco === 'refresco-valido') {
                    return { data: { user: { id: 'admin-1' }, session: { access_token: 'token-admin', refresh_token: 'refresco-2' } }, error: null };
                }
                return { data: {}, error: { message: 'Invalid Refresh Token' } };
            }
        }
    });

    return cliente;
}

// Reemplaza src/config/supabase antes de cargar la aplicación.
function instalarSupabaseFalso() {
    // Las URL de Storage de los datos de prueba son de este proyecto.
    process.env.SUPABASE_URL = process.env.SUPABASE_URL || 'https://proyecto.supabase.co';
    const cliente = crearClienteFalso();
    const ruta = require.resolve(path.join(__dirname, '..', '..', 'src', 'config', 'supabase'));
    require.cache[ruta] = { id: ruta, filename: ruta, loaded: true, exports: cliente };
    return cliente;
}

// Respuestas de un administrador válido para requireAuth.
function esConsultaDeRol(consulta) {
    return consulta.tabla === 'usuarios';
}

module.exports = { instalarSupabaseFalso, esConsultaDeRol };
