const gestorService = require('../services/GestorService');
const materialService = require('../services/MaterialService');
const { leerPagina, paginacion, rutaInterna, conAviso } = require('../utils/web');
const { municipioAdmitido, normalizar } = require('../utils/municipios');
const { etiquetaVerificacion, etiquetaCategoria } = require('../utils/formato');
const { responderErrorCarga, renderLista } = require('../utils/errores');
const { filtrosGestores } = require('../utils/filtros');
const { sinUbicar } = require('../services/geocodificador');

const adminDe = (req) => (req.user && (req.user.email || req.user.id)) || null;

// El catálogo completo para elegir materiales (no se pagina: son decenas),
// con el texto en que busca el filtro del formulario: sin tildes ni
// mayúsculas, para que «raee» encuentre «RAEE» y «electronico», «Electrónico».
async function catalogoMateriales() {
    const materiales = await materialService.getAllMateriales();
    return materiales.map((m) => ({
        ...m,
        busqueda: normalizar(`${m.codigo || ''} ${m.nombre_comun || ''} ${etiquetaCategoria(m.categoria)}`)
    }));
}

// Materiales del gestor agrupados por categoría, en el orden en que llegan.
function agruparPorCategoria(materiales) {
    const grupos = {};
    materiales.forEach((m) => {
        const clave = String(m.categoria || 'SIN_CATEGORIA').toUpperCase();
        (grupos[clave] = grupos[clave] || []).push(m);
    });
    return grupos;
}

const gestorController = {
    renderGestoresPage(req, res) {
        const pagina = leerPagina(req.query);
        const filtros = filtrosGestores(req.query);
        return renderLista(res, 'gestores', {
            comunes: { titulo: 'Gestores', activeTab: 'gestores', filtros },
            cargar: async () => {
                const { gestores, total } = await gestorService.listarGestores({ ...filtros, pagina });
                return { gestores, pag: paginacion({ total, pagina, ruta: '/gestores', query: req.query }) };
            },
            vacio: { gestores: [], pag: null }
        });
    },

    async renderDetalleGestor(req, res, next) {
        try {
            const [gestor, dependencias, decisiones] = await Promise.all([
                gestorService.getGestorById(req.params.id),
                gestorService.getDependencias(req.params.id),
                gestorService.getDecisiones(req.params.id)
            ]);
            res.render('gestor-detalle', {
                titulo: gestor.razon_social || 'Gestor',
                activeTab: 'gestores',
                gestor,
                dependencias,
                decisiones,
                gruposMateriales: agruparPorCategoria(gestor.materiales),
                // El mapa solo se muestra si la dirección se pudo ubicar: el
                // centro de Bucaramanga es el valor que se guarda cuando no.
                ubicado: gestor.latitud !== null && gestor.longitud !== null
                    && !sinUbicar(gestor.latitud, gestor.longitud)
            });
        } catch (err) {
            responderErrorCarga(res, next, err, { activeTab: 'gestores', que: 'el gestor', volver: { href: '/gestores', texto: 'Gestores' } });
        }
    },

    async renderNuevoGestor(req, res, next) {
        try {
            res.render('gestor-edit', {
                titulo: 'Nuevo gestor',
                activeTab: 'gestores',
                modo: 'crear',
                gestor: { material_ids: [], material_ids_por_verificar: [], disponible: true },
                municipioEnLista: null,
                materialesDisponibles: await catalogoMateriales()
            });
        } catch (err) {
            responderErrorCarga(res, next, err, { activeTab: 'gestores', que: 'el formulario de nuevo gestor', volver: { href: '/gestores', texto: 'Gestores' } });
        }
    },

    async handleCreateGestor(req, res) {
        try {
            const nuevo = await gestorService.createGestor(req.body);
            const destino = nuevo && nuevo.id ? `/gestores/${nuevo.id}` : '/gestores';
            res.redirect(conAviso(destino, 'Gestor registrado. Ya puedes adjuntar su permiso ambiental desde «Editar».'));
        } catch (err) {
            res.redirect(conAviso('/gestores/nuevo', err.message, 'error'));
        }
    },

    async renderEditGestor(req, res, next) {
        try {
            const { id } = req.params;
            const [gestor, materialesDisponibles] = await Promise.all([
                gestorService.getGestorById(id),
                catalogoMateriales()
            ]);

            res.render('gestor-edit', {
                titulo: `Editar ${gestor.razon_social || 'gestor'}`,
                activeTab: 'gestores',
                modo: 'editar',
                gestor,
                municipioEnLista: municipioAdmitido(gestor.municipio),
                materialesDisponibles
            });
        } catch (err) {
            responderErrorCarga(res, next, err, { activeTab: 'gestores', que: 'el gestor', volver: { href: '/gestores', texto: 'Gestores' } });
        }
    },

    async handleUpdateGestor(req, res) {
        const { id } = req.params;
        try {
            await gestorService.updateGestor(id, req.body, adminDe(req));
            res.redirect(conAviso(`/gestores/${id}`, 'Cambios del gestor guardados.'));
        } catch (err) {
            res.redirect(conAviso(`/gestores/edit/${id}`, err.message, 'error'));
        }
    },

    async handleDeleteGestor(req, res) {
        const { id } = req.params;
        try {
            await gestorService.deleteGestor(id);
            res.redirect(conAviso('/gestores', 'Gestor eliminado.'));
        } catch (err) {
            const destino = err.codigo === 'TIENE_HISTORIA' ? `/gestores/${id}` : '/gestores';
            res.redirect(conAviso(destino, err.message, 'error'));
        }
    },

    async handleVerPermiso(req, res) {
        try {
            const url = await gestorService.getUrlPermiso(req.params.id);
            res.redirect(url);
        } catch (err) {
            res.redirect(conAviso(`/gestores/${encodeURIComponent(req.params.id)}`, err.message, 'error'));
        }
    },

    // Recibe el PDF como cuerpo application/pdf (lo envía main.js).
    async handleSubirPermiso(req, res) {
        const { id } = req.params;
        const responder = (status, mensaje, ok) => {
            if (req.get('X-Requested-With') === 'fetch') {
                return res.status(status).json(ok
                    ? { ok: true, redirigir: conAviso(`/gestores/${id}`, mensaje) }
                    : { ok: false, mensaje });
            }
            return res.redirect(conAviso(ok ? `/gestores/${id}` : `/gestores/edit/${id}`, mensaje, ok ? 'success' : 'error'));
        };

        if (req.errorPdf) {
            return responder(413, req.errorPdf, false);
        }
        if (!req.is('application/pdf')) {
            return responder(400, 'Para subir el permiso, el navegador debe tener JavaScript activo.', false);
        }
        try {
            await gestorService.subirPermiso(id, req.body);
            return responder(200, 'Permiso ambiental guardado.', true);
        } catch (err) {
            return responder(400, err.message, false);
        }
    },

    async handleUpdateEstado(req, res) {
        const { id } = req.params;
        const { estado, motivo } = req.body;
        const destino = rutaInterna(req.body.redirectUrl, `/gestores/${id}`);
        try {
            await gestorService.updateEstadoVerificacion(id, estado, motivo, adminDe(req));
            let mensaje = `Estado del gestor: ${etiquetaVerificacion(estado)}.`;
            if (String(estado).toUpperCase() === 'APROBADO') mensaje += ' Sus materiales declarados quedaron verificados.';
            res.redirect(conAviso(destino, mensaje));
        } catch (err) {
            res.redirect(conAviso(destino, err.message, 'error'));
        }
    },

    async handleVerificarMaterial(req, res) {
        const { id, materialId } = req.params;
        try {
            await gestorService.verificarMaterial(id, materialId);
            res.redirect(conAviso(`/gestores/${id}`, 'Material verificado.'));
        } catch (err) {
            res.redirect(conAviso(`/gestores/${id}`, err.message, 'error'));
        }
    },

    async handleQuitarMaterial(req, res) {
        const { id, materialId } = req.params;
        try {
            await gestorService.quitarMaterial(id, materialId);
            res.redirect(conAviso(`/gestores/${id}`, 'Material quitado del gestor.'));
        } catch (err) {
            res.redirect(conAviso(`/gestores/${id}`, err.message, 'error'));
        }
    },

    async handleQuitarImagen(req, res) {
        const { id } = req.params;
        const tipo = req.body && req.body.imagen;
        try {
            await gestorService.quitarImagen(id, tipo);
            res.redirect(conAviso(`/gestores/${id}`, tipo === 'perfil' ? 'Logo quitado. El gestor verá sus iniciales hasta que suba otro.' : 'Portada quitada.'));
        } catch (err) {
            res.redirect(conAviso(`/gestores/${id}`, err.message, 'error'));
        }
    },

    async handleVerificarTodos(req, res) {
        const { id } = req.params;
        try {
            const cantidad = await gestorService.verificarTodos(id);
            res.redirect(conAviso(`/gestores/${id}`, cantidad === 1 ? '1 material verificado.' : `${cantidad} materiales verificados.`));
        } catch (err) {
            res.redirect(conAviso(`/gestores/${id}`, err.message, 'error'));
        }
    }
};

module.exports = gestorController;
