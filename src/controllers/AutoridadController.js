const autoridadService = require('../services/AutoridadService');

const autoridadController = {
    async renderAutoridadesPage(req, res) {
        try {
            const autoridades = await autoridadService.getAllAutoridades();
            res.render('autoridades', {
                autoridades,
                activeTab: 'autoridades',
                feedback: req.query.msg ? { type: req.query.type || 'success', message: req.query.msg } : null
            });
        } catch (err) {
            res.render('autoridades', {
                autoridades: [],
                activeTab: 'autoridades',
                feedback: { type: 'error', message: err.message }
            });
        }
    },

    async handleCreateAutoridad(req, res) {
        try {
            await autoridadService.createAutoridad(req.body);
            res.redirect('/autoridades?msg=Autoridad+ambiental+registrada&type=success');
        } catch (err) {
            res.redirect(`/autoridades?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    },

    async renderEditAutoridad(req, res) {
        try {
            const { id } = req.params;
            const autoridad = await autoridadService.getAutoridadById(id);
            res.render('autoridad-edit', {
                autoridad,
                activeTab: 'autoridades',
                feedback: req.query.msg ? { type: req.query.type || 'error', message: req.query.msg } : null
            });
        } catch (err) {
            res.redirect(`/autoridades?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    },

    async handleUpdateAutoridad(req, res) {
        const { id } = req.params;
        try {
            await autoridadService.updateAutoridad(id, req.body);
            res.redirect('/autoridades?msg=Autoridad+actualizada+exitosamente&type=success');
        } catch (err) {
            res.redirect(`/autoridades/edit/${id}?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    },

    async handleDeleteAutoridad(req, res) {
        try {
            const { id } = req.params;
            await autoridadService.deleteAutoridad(id);
            res.redirect('/autoridades?msg=Autoridad+eliminada+del+directorio&type=success');
        } catch (err) {
            res.redirect(`/autoridades?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    }
};

module.exports = autoridadController;