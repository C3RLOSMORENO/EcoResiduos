const autoridadService = require('../services/AutoridadService');
const { leerPagina, paginacion, conAviso } = require('../utils/web');
const { responderErrorCarga, renderLista } = require('../utils/errores');
const { filtrosAutoridades } = require('../utils/filtros');

const autoridadController = {
    renderAutoridadesPage(req, res) {
        const pagina = leerPagina(req.query);
        const filtros = filtrosAutoridades(req.query);
        return renderLista(res, 'autoridades', {
            comunes: { titulo: 'Autoridades ambientales', activeTab: 'autoridades', filtros },
            cargar: async () => {
                const { autoridades, total } = await autoridadService.listarAutoridades({ ...filtros, pagina });
                return { autoridades, pag: paginacion({ total, pagina, ruta: '/autoridades', query: req.query }) };
            },
            vacio: { autoridades: [], pag: null }
        });
    },

    renderNuevaAutoridad(req, res) {
        res.render('autoridad-edit', {
            titulo: 'Nueva autoridad ambiental',
            activeTab: 'autoridades',
            modo: 'crear',
            autoridad: {}
        });
    },

    async handleCreateAutoridad(req, res) {
        try {
            await autoridadService.createAutoridad(req.body);
            res.redirect(conAviso('/autoridades', 'Autoridad ambiental registrada.'));
        } catch (err) {
            res.redirect(conAviso('/autoridades/nuevo', err.message, 'error'));
        }
    },

    async renderEditAutoridad(req, res, next) {
        try {
            const autoridad = await autoridadService.getAutoridadById(req.params.id);
            res.render('autoridad-edit', {
                titulo: `Editar ${autoridad.sigla || autoridad.nombre || 'autoridad'}`,
                activeTab: 'autoridades',
                modo: 'editar',
                autoridad
            });
        } catch (err) {
            responderErrorCarga(res, next, err, { activeTab: 'autoridades', que: 'la autoridad ambiental', volver: { href: '/autoridades', texto: 'Autoridades' } });
        }
    },

    async handleUpdateAutoridad(req, res) {
        const { id } = req.params;
        try {
            await autoridadService.updateAutoridad(id, req.body);
            res.redirect(conAviso('/autoridades', 'Autoridad actualizada.'));
        } catch (err) {
            res.redirect(conAviso(`/autoridades/edit/${id}`, err.message, 'error'));
        }
    },

    async handleDeleteAutoridad(req, res) {
        try {
            await autoridadService.deleteAutoridad(req.params.id);
            res.redirect(conAviso('/autoridades', 'Autoridad eliminada del directorio.'));
        } catch (err) {
            res.redirect(conAviso('/autoridades', err.message, 'error'));
        }
    }
};

module.exports = autoridadController;
