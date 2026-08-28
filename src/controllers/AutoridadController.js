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
            console.error(err);
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
            console.error(err);
            res.redirect(`/autoridades?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    },

    async handleDeleteAutoridad(req, res) {
        try {
            const { id } = req.params;
            await autoridadService.deleteAutoridad(id);
            res.redirect('/autoridades?msg=Autoridad+eliminada+del+directorio&type=success');
        } catch (err) {
            console.error(err);
            res.redirect(`/autoridades?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    }
};

module.exports = autoridadController;