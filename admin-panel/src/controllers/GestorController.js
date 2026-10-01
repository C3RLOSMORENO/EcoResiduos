const gestorService = require('../services/GestorService');
const materialService = require('../services/MaterialService');
const { leerPagina, paginacion, rutaInterna, conAviso } = require('../utils/web');
const { municipioAdmitido } = require('../utils/municipios');
const { etiquetaVerificacion } = require('../utils/formato');

const adminDe = (req) => (req.user && (req.user.email || req.user.id)) || null;

// El catálogo completo para elegir materiales (no se pagina: son decenas).
async function catalogoMateriales() {
    return materialService.getAllMateriales();
}

const gestorController = {
    async renderGestoresPage(req, res) {
        const pagina = leerPagina(req.query);
        const filtros = {
            q: String(req.query.q || '').trim(),
            municipio: municipioAdmitido(req.query.municipio) || '',
            estado: ['PENDIENTE', 'APROBADO', 'RECHAZADO', 'SUSPENDIDO'].includes(String(req.query.estado || '').toUpperCase())
                ? String(req.query.estado).toUpperCase() : '',
            porVerificar: req.query.por_verificar === '1' ? '1' : '',
            orden: req.query.orden === '-razon' ? '-razon' : 'razon'
        };
        try {
            const { gestores, total } = await gestorService.listarGestores({ ...filtros, pagina });
            res.render('gestores', {
                titulo: 'Gestores',
                activeTab: 'gestores',
                gestores,
                filtros,
                pag: paginacion({ total, pagina, ruta: '/gestores', query: req.query }),
                errorCarga: null
            });
        } catch (err) {
            res.status(500).render('gestores', {
                titulo: 'Gestores',
                activeTab: 'gestores',
                gestores: [],
                filtros,
                pag: null,
                errorCarga: err.message
            });
        }
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
                decisiones
            });
        } catch (err) {
            if (err.codigo === 'NO_ENCONTRADO') return next();
            res.redirect(conAviso('/gestores', err.message, 'error'));
        }
    },

    async renderNuevoGestor(req, res) {
        try {
            res.render('gestor-edit', {
                titulo: 'Nuevo gestor',
                activeTab: 'gestores',
                modo: 'crear',
                gestor: { material_ids: [], material_ids_por_verificar: [], disponible: true },
                materialesDisponibles: await catalogoMateriales()
            });
        } catch (err) {
            res.redirect(conAviso('/gestores', err.message, 'error'));
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

    async renderEditGestor(req, res) {
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
                materialesDisponibles
            });
        } catch (err) {
            res.redirect(conAviso('/gestores', err.message, 'error'));
        }
    },

    async handleUpdateGestor(req, res) {
        const { id } = req.params;
        try {
            const { motivoGuardado } = await gestorService.updateGestor(id, req.body, adminDe(req));
            const mensaje = 'Cambios del gestor guardados.';
            res.redirect(conAviso(`/gestores/${id}`, mensaje));
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
