const crypto = require('crypto');
const supabase = require('../config/supabase');
const geocodificador = require('./geocodificador');
const { municipioParaGuardar, variantesMunicipio, municipioAdmitido } = require('../utils/municipios');
const { rango, textoBusqueda, faltaEnEsquema } = require('../utils/web');
const { errorDeBase } = require('../utils/errores');
const { ESTADOS_GESTOR } = require('../utils/formato');
const { BUCKET: BUCKET_FOTOS, COLUMNAS: COLUMNAS_FOTO } = require('../utils/fotosPerfil');

const ESTADOS_VALIDOS = ESTADOS_GESTOR;
const TAMANO_MAXIMO_PERMISO = 10 * 1024 * 1024;

const SELECT_MATERIALES = `
    gestor_material (
        material_id,
        verificado,
        materiales_residuos (
            id,
            codigo,
            nombre_comun,
            categoria
        )
    )
`;

/**
 * @param {string} mensaje
 * @param {string} codigo Para que el controlador distinga el caso (NO_ENCONTRADO, TIENE_HISTORIA).
 * @returns {Error}
 */
function errorConCodigo(mensaje, codigo) {
    const error = new Error(mensaje);
    error.codigo = codigo;
    return error;
}

/**
 * Convierte la lista de IDs recibida en un arreglo de enteros, sin repetidos.
 *
 * @param {*} valor Un ID, una lista de IDs o nada.
 * @returns {number[]}
 */
function extraerIds(valor) {
    const lista = Array.isArray(valor) ? valor : (valor === undefined || valor === null || valor === '' ? [] : [valor]);
    return [...new Set(lista.map((id) => parseInt(id, 10)).filter((id) => Number.isInteger(id)))];
}

/**
 * Materiales marcados en el formulario, con cualquiera de los nombres de campo
 * que han usado las vistas.
 *
 * @param {object} dto req.body.
 * @returns {number[]}
 */
function extractMaterialIds(dto) {
    return extraerIds(dto.materiales_ids || dto['materiales_ids[]'] || dto.material_ids || dto.residuos);
}

/**
 * @param {*} valor
 * @returns {?string} El texto sin espacios sobrantes, o null si queda vacío.
 */
function textoOpcional(valor) {
    const limpio = valor === undefined || valor === null ? '' : String(valor).trim();
    return limpio || null;
}

/**
 * Fila de perfiles_gestor con sus materiales, en la forma que usan las vistas.
 * Nunca se inventa un valor: si falta el dato, la vista muestra «Sin dato».
 *
 * @param {object} row
 * @returns {object}
 */
function mapearGestor(row) {
    const relaciones = row.gestor_material || [];
    const materiales = relaciones
        .filter((gm) => gm.materiales_residuos)
        .map((gm) => ({ ...gm.materiales_residuos, verificado: gm.verificado !== false }));

    return {
        id: row.id,
        nit: row.nit || '',
        razon_social: row.razon_social || '',
        municipio: row.municipio || null,
        direccion: row.direccion || '',
        representante_legal: row.representante_legal || null,
        telefono_contacto: row.telefono_contacto || '',
        email_contacto: row.email_contacto || '',
        latitud: row.latitud ?? null,
        longitud: row.longitud ?? null,
        estado_verificacion: row.estado_verificacion || null,
        disponible: row.disponible !== false,
        horario: row.horario || '',
        tiene_cuenta: Boolean(row.usuario_id),
        tiene_permiso: Boolean(row.permiso_path),
        foto_perfil_path: row.foto_perfil_path || null,
        portada_path: row.portada_path || null,
        created_at: row.created_at || null,
        material_ids: relaciones.map((gm) => gm.material_id),
        material_ids_por_verificar: relaciones.filter((gm) => gm.verificado === false).map((gm) => gm.material_id),
        materiales,
        materiales_por_verificar: relaciones.filter((gm) => gm.verificado === false).length
    };
}

/**
 * Valida y normaliza los datos del formulario de un gestor.
 *
 * @param {object} dto req.body.
 * @param {{exigirMunicipioAdmitido: boolean}} opciones false al editar un gestor
 *     antiguo cuyo municipio está fuera de la lista.
 * @returns {{nit: string, razonSocial: string, municipio: string, direccion: string,
 *     representante: ?string, telefono: string, email: string}}
 * @throws {Error} Con el mensaje para el formulario si un dato no es válido.
 */
function validarDatos(dto, { exigirMunicipioAdmitido }) {
    const nit = String(dto.nit || '').replace(/[\s.]/g, '').split('-')[0].trim();
    const razonSocial = String(dto.razon_social || '').trim().toUpperCase();
    const municipioTexto = String(dto.municipio || '').trim();
    const direccion = String(dto.direccion || '').trim();
    const representante = textoOpcional(dto.representante_legal || dto.contacto);
    const telefono = String(dto.telefono_contacto || dto.telefono || '').trim();
    const email = String(dto.email_contacto || dto.email || '').trim().toLowerCase();

    if (!/^\d{8,15}$/.test(nit)) {
        throw new Error('El NIT es obligatorio y debe tener entre 8 y 15 dígitos (sin dígito de verificación, puntos ni guiones).');
    }
    if (razonSocial.length < 3) {
        throw new Error('La razón social es obligatoria y debe tener al menos 3 caracteres.');
    }
    let municipio = municipioParaGuardar(municipioTexto);
    if (!municipio) {
        if (exigirMunicipioAdmitido || !municipioTexto) {
            throw new Error('Elige uno de los 6 municipios donde opera EcoResiduos.');
        }
        // Gestores antiguos con un municipio fuera de la lista: se conserva tal cual.
        municipio = municipioTexto.toUpperCase();
    }
    if (direccion.length < 5) {
        throw new Error('La dirección es obligatoria y debe tener al menos 5 caracteres.');
    }
    if (!telefono) {
        throw new Error('El teléfono de contacto es obligatorio.');
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        throw new Error('El correo de contacto no tiene un formato válido (ejemplo: contacto@empresa.com).');
    }
    return { nit, razonSocial, municipio, direccion, representante, telefono, email };
}

/**
 * Una casilla con un campo oculto del mismo nombre llega como lista: cuenta
 * el último valor.
 *
 * @param {object} dto req.body.
 * @param {string} nombre
 * @returns {boolean}
 */
function leerCasilla(dto, nombre) {
    const valor = Array.isArray(dto[nombre]) ? dto[nombre][dto[nombre].length - 1] : dto[nombre];
    return valor === true || valor === 'true' || valor === 'on' || valor === '1';
}

const gestorService = {
    mapearGestor,
    extractMaterialIds,

    /**
     * Página de gestores. La búsqueda encuentra por razón social, NIT o por
     * código o nombre de un material que manejan.
     *
     * @param {{q?: string, municipio?: string, estado?: string, porVerificar?: string,
     *     orden?: string, pagina?: number}} [opciones]
     * @returns {Promise<{gestores: object[], total: number}>}
     * @throws {Error} Si falla la consulta.
     */
    async listarGestores({ q, municipio, estado, porVerificar, orden, pagina = 1 } = {}) {
        let consulta = supabase
            .from('perfiles_gestor')
            .select(`*, ${SELECT_MATERIALES}`, { count: 'exact' });

        const termino = textoBusqueda(q);
        if (termino) {
            const { data: materiales } = await supabase
                .from('materiales_residuos')
                .select('id')
                .or(`codigo.ilike.%${termino}%,nombre_comun.ilike.%${termino}%`);
            const idsMateriales = (materiales || []).map((m) => m.id);
            let idsGestores = [];
            if (idsMateriales.length > 0) {
                const { data: relaciones } = await supabase
                    .from('gestor_material')
                    .select('gestor_id')
                    .in('material_id', idsMateriales);
                idsGestores = [...new Set((relaciones || []).map((r) => r.gestor_id))];
            }
            const condiciones = [`razon_social.ilike.%${termino}%`, `nit.ilike.%${termino}%`];
            if (idsGestores.length > 0) condiciones.push(`id.in.(${idsGestores.join(',')})`);
            consulta = consulta.or(condiciones.join(','));
        }

        const municipioFiltro = municipioAdmitido(municipio);
        if (municipioFiltro) consulta = consulta.in('municipio', variantesMunicipio(municipioFiltro));

        const estadoFiltro = String(estado || '').toUpperCase();
        if (ESTADOS_VALIDOS.includes(estadoFiltro)) consulta = consulta.eq('estado_verificacion', estadoFiltro);

        if (porVerificar) {
            const { data: relaciones, error: errorRelaciones } = await supabase
                .from('gestor_material')
                .select('gestor_id')
                .eq('verificado', false);
            if (errorRelaciones) throw errorDeBase('No pudimos cargar los materiales por verificar.', errorRelaciones);
            const ids = [...new Set((relaciones || []).map((r) => r.gestor_id))];
            if (ids.length === 0) return { gestores: [], total: 0 };
            consulta = consulta.in('id', ids);
        }

        const { desde, hasta } = rango(pagina);
        const ascendente = orden !== '-razon';
        const { data, error, count } = await consulta
            .order('razon_social', { ascending: ascendente })
            .range(desde, hasta);

        if (error) {
            throw errorDeBase('No pudimos cargar los gestores.', error);
        }
        return { gestores: (data || []).map(mapearGestor), total: count || 0 };
    },

    /**
     * @param {number|string} id
     * @returns {Promise<object>} El gestor con mapearGestor.
     * @throws {Error} Con codigo NO_ENCONTRADO si no existe.
     */
    async getGestorById(id) {
        if (!id) {
            throw new Error('El identificador del gestor es obligatorio.');
        }

        const { data, error } = await supabase
            .from('perfiles_gestor')
            .select(`*, ${SELECT_MATERIALES}`)
            .eq('id', id)
            .maybeSingle();

        if (error || !data) {
            if (error) throw errorDeBase('No pudimos cargar el gestor.', error);
            throw errorConCodigo('No encontramos el gestor.', 'NO_ENCONTRADO');
        }
        return mapearGestor(data);
    },

    /**
     * Registros que dan historia al gestor: con cualquiera de ellos no se borra.
     *
     * @param {number|string} id
     * @returns {Promise<{postulaciones: number, solicitudesAsignadas: number,
     *     tieneCuenta: boolean, tieneHistoria: boolean}>}
     */
    async getDependencias(id) {
        const [postulaciones, asignadas, perfil] = await Promise.all([
            supabase.from('postulaciones_recoleccion').select('id', { count: 'exact', head: true }).eq('gestor_id', id),
            supabase.from('solicitudes_recoleccion').select('id', { count: 'exact', head: true }).eq('gestor_asignado_id', id),
            supabase.from('perfiles_gestor').select('usuario_id').eq('id', id).maybeSingle()
        ]);
        const resultado = {
            postulaciones: postulaciones.count || 0,
            solicitudesAsignadas: asignadas.count || 0,
            tieneCuenta: Boolean(perfil.data && perfil.data.usuario_id)
        };
        resultado.tieneHistoria = resultado.postulaciones > 0 || resultado.solicitudesAsignadas > 0 || resultado.tieneCuenta;
        return resultado;
    },

    /**
     * Registra una empresa desde el panel. Queda aprobada, ubicada en el mapa si
     * la dirección se encuentra, y con los materiales elegidos ya verificados.
     *
     * @param {object} [dto] req.body.
     * @returns {Promise<object>} La fila creada.
     * @throws {Error} Con el mensaje para el formulario si un dato no es válido.
     */
    async createGestor(dto = {}) {
        const datos = validarDatos(dto, { exigirMunicipioAdmitido: true });
        const materialIds = extractMaterialIds(dto);
        const horario = String(dto.horario || '').trim();
        if (horario.length > 120) {
            throw new Error('El horario de atención no puede superar los 120 caracteres.');
        }
        const coordenadas = await geocodificador.geocodificar(datos.direccion, datos.municipio);

        const { data: creados, error } = await supabase
            .from('perfiles_gestor')
            .insert([{
                nit: datos.nit,
                razon_social: datos.razonSocial,
                municipio: datos.municipio,
                direccion: datos.direccion,
                representante_legal: datos.representante,
                telefono_contacto: datos.telefono,
                email_contacto: datos.email,
                horario: horario || null,
                latitud: coordenadas ? coordenadas.latitud : geocodificador.LATITUD_DEFECTO,
                longitud: coordenadas ? coordenadas.longitud : geocodificador.LONGITUD_DEFECTO,
                estado_verificacion: 'APROBADO',
                disponible: true
            }])
            .select();

        if (error) {
            throw errorDeBase('No pudimos registrar el gestor.', error);
        }

        const nuevo = creados && creados[0];
        // El administrador elige los materiales al crear la empresa: quedan verificados.
        if (nuevo && materialIds.length > 0) {
            const { error: errorMateriales } = await supabase
                .from('gestor_material')
                .insert(materialIds.map((materialId) => ({ gestor_id: nuevo.id, material_id: materialId, verificado: true })));
            if (errorMateriales) {
                throw errorDeBase('El gestor quedó registrado, pero no se guardaron sus materiales.', errorMateriales);
            }
        }
        return nuevo;
    },

    /**
     * Guarda los datos del formulario de edición. El estado de verificación de
     * cada material se conserva: los que ya tenía siguen como estaban, los que
     * el administrador marca nuevos quedan verificados (él los eligió) y los
     * desmarcados se quitan.
     *
     * @param {number|string} id
     * @param {object} [dto] req.body.
     * @param {?string} [admin] Correo (o id) del administrador, para el historial de decisiones.
     * @returns {Promise<{motivoGuardado: boolean}>}
     * @throws {Error} Con el mensaje para el formulario si un dato no es válido.
     */
    async updateGestor(id, dto = {}, admin = null) {
        if (!id) {
            throw new Error('El identificador del gestor es obligatorio para la actualización.');
        }

        const { data: actual, error: errorActual } = await supabase
            .from('perfiles_gestor')
            .select('id, direccion, municipio, latitud, longitud, estado_verificacion, gestor_material ( material_id, verificado )')
            .eq('id', id)
            .maybeSingle();

        if (errorActual || !actual) {
            throw errorActual ? errorDeBase('No pudimos cargar el gestor.', errorActual) : new Error('No encontramos el gestor.');
        }

        const datos = validarDatos(dto, { exigirMunicipioAdmitido: false });
        const horario = String(dto.horario || '').trim();
        if (horario.length > 120) {
            throw new Error('El horario de atención no puede superar los 120 caracteres.');
        }

        const cambios = {
            nit: datos.nit,
            razon_social: datos.razonSocial,
            municipio: datos.municipio,
            direccion: datos.direccion,
            representante_legal: datos.representante,
            telefono_contacto: datos.telefono,
            email_contacto: datos.email,
            horario: horario || null
        };

        if (dto.disponible_enviado !== undefined || dto.disponible !== undefined) {
            cambios.disponible = leerCasilla(dto, 'disponible');
        }

        // Solo se consulta Nominatim si cambió la ubicación.
        const cambioUbicacion = datos.direccion !== (actual.direccion || '') || datos.municipio !== (actual.municipio || '');
        if (cambioUbicacion) {
            const coordenadas = await geocodificador.geocodificar(datos.direccion, datos.municipio);
            cambios.latitud = coordenadas ? coordenadas.latitud : geocodificador.LATITUD_DEFECTO;
            cambios.longitud = coordenadas ? coordenadas.longitud : geocodificador.LONGITUD_DEFECTO;
        }

        const { error } = await supabase
            .from('perfiles_gestor')
            .update(cambios)
            .eq('id', id);

        if (error) {
            throw errorDeBase('No pudimos guardar los cambios del gestor.', error);
        }

        await this.sincronizarMateriales(id, actual.gestor_material || [], dto);

        const estadoNuevo = String(dto.estado_verificacion || '').trim().toUpperCase();
        if (estadoNuevo && estadoNuevo !== String(actual.estado_verificacion || '').toUpperCase()) {
            return this.updateEstadoVerificacion(id, estadoNuevo, dto.motivo, admin);
        }
        return { motivoGuardado: true };
    },

    /**
     * Aplica a gestor_material los materiales marcados en el formulario.
     *
     * @param {number|string} id
     * @param {{material_id: number}[]} relacionesActuales
     * @param {object} dto req.body.
     * @returns {Promise<{quitados: number, agregados: number}>}
     */
    async sincronizarMateriales(id, relacionesActuales, dto) {
        const marcados = new Set(extractMaterialIds(dto));
        const existentes = new Set(relacionesActuales.map((gm) => gm.material_id));
        // Solo se quitan los que el formulario mostró desmarcados: si el gestor
        // agregó uno desde la app mientras se editaba, no se pierde.
        const mostrados = dto.materiales_presentes !== undefined
            ? new Set(extraerIds(dto.materiales_presentes))
            : existentes;

        const quitar = [...existentes].filter((m) => mostrados.has(m) && !marcados.has(m));
        const agregar = [...marcados].filter((m) => !existentes.has(m));

        if (quitar.length > 0) {
            const { error } = await supabase
                .from('gestor_material')
                .delete()
                .eq('gestor_id', id)
                .in('material_id', quitar);
            if (error) throw errorDeBase('No pudimos quitar los materiales desmarcados.', error);
        }

        if (agregar.length > 0) {
            const { error } = await supabase
                .from('gestor_material')
                .insert(agregar.map((materialId) => ({ gestor_id: parseInt(id, 10), material_id: materialId, verificado: true })));
            if (error) throw errorDeBase('No pudimos agregar los materiales nuevos.', error);
        }
        return { quitados: quitar.length, agregados: agregar.length };
    },

    /**
     * Cambia el estado de verificación. Aprobar verifica los materiales que el
     * gestor declaró y lo ubica en el mapa con su dirección. El estado y el
     * motivo se guardan con cambiar_verificacion_gestor_admin (migración
     * 20261003000100), que deja la decisión en gestor_decisiones: el motivo no
     * va en perfiles_gestor porque esa tabla es de lectura pública.
     *
     * @param {number|string} id
     * @param {string} estado PENDIENTE, APROBADO, RECHAZADO o SUSPENDIDO.
     * @param {?string} motivo Se guardan hasta 300 caracteres.
     * @param {?string} admin Correo (o id) del administrador.
     * @returns {Promise<{motivoGuardado: boolean}>} false si la migración no está y
     *     el motivo no se pudo guardar.
     */
    async updateEstadoVerificacion(id, estado, motivo, admin) {
        if (!id) throw new Error('El identificador del gestor es obligatorio');
        const estadoUpper = String(estado || '').trim().toUpperCase();
        if (!ESTADOS_VALIDOS.includes(estadoUpper)) {
            throw new Error(`Estado inválido. Debe ser uno de: ${ESTADOS_VALIDOS.join(', ')}`);
        }

        if (estadoUpper === 'APROBADO') {
            const { data: actual } = await supabase
                .from('perfiles_gestor')
                .select('direccion, municipio, latitud, longitud')
                .eq('id', id)
                .maybeSingle();
            if (actual && actual.direccion && geocodificador.sinUbicar(actual.latitud, actual.longitud)) {
                const coordenadas = await geocodificador.geocodificar(actual.direccion, actual.municipio || 'Bucaramanga');
                if (coordenadas) {
                    const { error: errorUbicacion } = await supabase.from('perfiles_gestor').update(coordenadas).eq('id', id);
                    if (errorUbicacion) throw errorDeBase('No pudimos ubicar al gestor.', errorUbicacion);
                }
            }

            // Se verifican antes de aprobar: así el aviso de materiales
            // verificados (migración 20261003000100) no se suma al de aprobación.
            const { error: errorMateriales } = await supabase
                .from('gestor_material')
                .update({ verificado: true })
                .eq('gestor_id', id)
                .eq('verificado', false);
            if (errorMateriales) {
                throw errorDeBase('No pudimos verificar los materiales del gestor.', errorMateriales);
            }
        }

        const observacion = textoOpcional(String(motivo || '').slice(0, 300));
        const { error } = await supabase.rpc('cambiar_verificacion_gestor_admin', {
            p_gestor_id: parseInt(id, 10),
            p_estado: estadoUpper,
            p_observacion: observacion,
            p_admin: admin || null
        });

        if (!error) return { motivoGuardado: true };

        if (!faltaEnEsquema(error)) {
            throw errorDeBase('No pudimos cambiar el estado del gestor.', error);
        }

        // Sin la migración el estado igual se guarda, sin motivo ni historial.
        const { error: errorDirecto } = await supabase
            .from('perfiles_gestor')
            .update({ estado_verificacion: estadoUpper })
            .eq('id', id);
        if (errorDirecto) {
            throw errorDeBase('No pudimos cambiar el estado del gestor.', errorDirecto);
        }
        return { motivoGuardado: observacion === null };
    },

    /**
     * Últimas 50 decisiones del administrador sobre el gestor.
     *
     * @param {number|string} id
     * @returns {Promise<?object[]>} null si falta la migración o falla la consulta.
     */
    async getDecisiones(id) {
        const { data, error } = await supabase
            .from('gestor_decisiones')
            .select('id, estado, observacion, creado_por, created_at')
            .eq('gestor_id', id)
            .order('created_at', { ascending: false })
            .limit(50);
        if (error) return null;
        return data || [];
    },

    /**
     * @param {number|string} id
     * @param {number|string} materialId
     * @returns {Promise<true>}
     * @throws {Error} Si el gestor ya no tiene ese material.
     */
    async verificarMaterial(id, materialId) {
        const { data, error } = await supabase
            .from('gestor_material')
            .update({ verificado: true })
            .eq('gestor_id', id)
            .eq('material_id', materialId)
            .select('material_id');
        if (error) throw errorDeBase('No pudimos verificar el material.', error);
        if (!data || data.length === 0) throw new Error('El gestor ya no tiene ese material.');
        return true;
    },

    /**
     * @param {number|string} id
     * @param {number|string} materialId
     * @returns {Promise<true>}
     */
    async quitarMaterial(id, materialId) {
        const { error } = await supabase
            .from('gestor_material')
            .delete()
            .eq('gestor_id', id)
            .eq('material_id', materialId);
        if (error) throw errorDeBase('No pudimos quitar el material.', error);
        return true;
    },

    /**
     * @param {number|string} id
     * @returns {Promise<number>} Cuántos materiales quedaron verificados.
     */
    async verificarTodos(id) {
        const { data, error } = await supabase
            .from('gestor_material')
            .update({ verificado: true })
            .eq('gestor_id', id)
            .eq('verificado', false)
            .select('material_id');
        if (error) throw errorDeBase('No pudimos verificar los materiales.', error);
        return (data || []).length;
    },

    /**
     * Quita el logo («perfil») o la portada que el gestor puso en la app, por
     * ejemplo si es inapropiada. Se borra el archivo y también la copia en los
     * metadatos de su cuenta, que la app usa para la barra superior.
     *
     * @param {number|string} id
     * @param {'perfil'|'portada'} tipo
     * @throws {Error} Si el tipo no existe o el gestor no tiene esa imagen.
     */
    async quitarImagen(id, tipo) {
        const columna = Object.prototype.hasOwnProperty.call(COLUMNAS_FOTO, tipo) ? COLUMNAS_FOTO[tipo] : null;
        if (!columna) throw new Error('Esa imagen no existe.');

        const { data: actual, error: errorActual } = await supabase
            .from('perfiles_gestor')
            .select(`id, usuario_id, ${columna}`)
            .eq('id', id)
            .maybeSingle();
        if (errorActual) throw errorDeBase('No pudimos cargar el gestor.', errorActual);
        if (!actual) throw new Error('No encontramos el gestor.');
        const ruta = actual[columna];
        if (!ruta) throw new Error(tipo === 'perfil' ? 'El gestor no tiene logo.' : 'El gestor no tiene portada.');

        const { error } = await supabase.from('perfiles_gestor').update({ [columna]: null }).eq('id', id);
        if (error) throw errorDeBase('No pudimos quitar la imagen.', error);

        // Lo que sigue no cambia lo que ve la gente: si falla, solo queda un
        // archivo huérfano o una copia vieja que la app ignora al no cargar.
        const { error: errorArchivo } = await supabase.storage.from(BUCKET_FOTOS).remove([ruta]);
        if (errorArchivo) console.error(`No se borró la imagen ${ruta}: ${errorArchivo.message}`);
        if (actual.usuario_id) {
            const { error: errorCuenta } = await supabase.auth.admin.updateUserById(actual.usuario_id, {
                user_metadata: { [columna]: null }
            });
            if (errorCuenta) console.error(`No se actualizó la cuenta del gestor ${id}: ${errorCuenta.message}`);
        }
    },

    /**
     * PDF del permiso ambiental, leído del bucket privado con la llave del
     * servidor: el navegador no recibe ninguna URL de Supabase.
     *
     * @param {number|string} id Identificador del gestor.
     * @returns {Promise<{buffer: Buffer, razonSocial: string}>}
     * @throws {Error} Si el gestor no tiene permiso o Storage no entrega el archivo.
     */
    async descargarPermiso(id) {
        const { data, error } = await supabase
            .from('perfiles_gestor')
            .select('permiso_path, razon_social')
            .eq('id', id)
            .maybeSingle();

        if (error) throw errorDeBase('No pudimos cargar el permiso.', error);
        if (!data || !data.permiso_path) {
            throw new Error('Este gestor no tiene un permiso ambiental adjunto.');
        }

        const { data: archivo, error: errorDescarga } = await supabase.storage
            .from('permisos')
            .download(String(data.permiso_path).trim());

        if (errorDescarga || !archivo) {
            throw errorDescarga
                ? errorDeBase('No pudimos abrir el permiso.', errorDescarga)
                : new Error('No encontramos el archivo del permiso.');
        }

        return {
            buffer: Buffer.from(await archivo.arrayBuffer()),
            razonSocial: data.razon_social
        };
    },

    /**
     * Sube o reemplaza el permiso desde el panel. Se valida en el servidor que
     * sea un PDF real de máximo 10 MB.
     *
     * @param {number|string} id
     * @param {Buffer} contenido Cuerpo de la petición.
     * @returns {Promise<string>} La ruta del archivo en el bucket.
     * @throws {Error} Si no es un PDF válido o falla la subida.
     */
    async subirPermiso(id, contenido) {
        if (!Buffer.isBuffer(contenido) || contenido.length === 0) {
            throw new Error('Adjunta el permiso ambiental en PDF.');
        }
        if (contenido.length > TAMANO_MAXIMO_PERMISO) {
            throw new Error('El PDF supera los 10 MB.');
        }
        if (contenido.subarray(0, 5).toString('latin1') !== '%PDF-') {
            throw new Error('El archivo no es un PDF válido.');
        }

        const { data: actual, error: errorActual } = await supabase
            .from('perfiles_gestor')
            .select('id, permiso_path')
            .eq('id', id)
            .maybeSingle();
        if (errorActual || !actual) {
            throw new Error('No encontramos el gestor.');
        }

        const ruta = `admin/${actual.id}/${crypto.randomUUID()}.pdf`;
        const { error: errorSubida } = await supabase.storage
            .from('permisos')
            .upload(ruta, contenido, { contentType: 'application/pdf', upsert: false });
        if (errorSubida) {
            throw errorDeBase('No pudimos subir el permiso.', errorSubida);
        }

        const { error } = await supabase
            .from('perfiles_gestor')
            .update({ permiso_path: ruta })
            .eq('id', id);
        if (error) {
            await supabase.storage.from('permisos').remove([ruta]);
            throw errorDeBase('No pudimos guardar el permiso.', error);
        }

        // Solo se borra el reemplazado si lo subió el panel: el que adjuntó la
        // empresa al registrarse queda como soporte de su solicitud.
        if (actual.permiso_path && actual.permiso_path.startsWith('admin/')) {
            await supabase.storage.from('permisos').remove([actual.permiso_path]);
        }
        return ruta;
    },

    /**
     * Solo se borra una empresa sin historia. Con cuenta en la app,
     * postulaciones o recolecciones asignadas, se suspende.
     *
     * @param {number|string} id
     * @returns {Promise<true>}
     * @throws {Error} Con codigo TIENE_HISTORIA si el gestor tiene historia.
     */
    async deleteGestor(id) {
        if (!id) {
            throw new Error('El identificador del gestor es obligatorio para la eliminación.');
        }

        const dependencias = await this.getDependencias(id);
        if (dependencias.tieneHistoria) {
            throw errorConCodigo(
                'No se puede eliminar: el gestor tiene cuenta en la app, postulaciones o recolecciones. Suspéndelo en su lugar.',
                'TIENE_HISTORIA'
            );
        }

        const { error: errorMateriales } = await supabase
            .from('gestor_material')
            .delete()
            .eq('gestor_id', id);
        if (errorMateriales) {
            throw errorDeBase('No pudimos eliminar los materiales del gestor.', errorMateriales);
        }

        const { error } = await supabase
            .from('perfiles_gestor')
            .delete()
            .eq('id', id);

        if (error) {
            throw errorDeBase('No pudimos eliminar el gestor.', error);
        }
        return true;
    }
};

module.exports = gestorService;
