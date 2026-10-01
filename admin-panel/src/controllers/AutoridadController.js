const autoridadService = require('../services/AutoridadService');
const { leerPagina, paginacion, conAviso } = require('../utils/web');

const autoridadController = {
    async renderAutoridadesPage(req, res) {
        const pagina = leerPagina(req.query);
        const filtros = { q: String(req.query.q || '').trim() };
        try {
            const { autoridades, total } = await autoridadService.listarAutoridades({ ...filtros, pagina });
            res.render('autoridades', {
                titulo: 'Autoridades ambientales',
                activeTab: 'autoridades',
                autoridades,
                filtros,
                pag: paginacion({ total, pagina, ruta: '/autoridades', query: req.query }),
                errorCarga: null
            });
        } catch (err) {
            res.status(500).render('autoridades', {
                titulo: 'Autoridades ambientales',
                activeTab: 'autoridades',
                autoridades: [],
                filtros,
                pag: null,
                errorCarga: err.message
            });
        }
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

    async renderEditAutoridad(req, res) {
        try {
            const autoridad = await autoridadService.getAutoridadById(req.params.id);
            res.render('autoridad-edit', {
                titulo: `Editar ${autoridad.sigla || autoridad.nombre || 'autoridad'}`,
                activeTab: 'autoridades',
                modo: 'editar',
                autoridad
            });
        } catch (err) {
            res.redirect(conAviso('/autoridades', err.message, 'error'));
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
