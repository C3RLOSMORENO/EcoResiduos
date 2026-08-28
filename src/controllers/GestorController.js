const gestorService = require('../services/GestorService');

const gestorController = {
    async renderGestoresPage(req, res) {
        try {
            const gestores = await gestorService.getAllGestores();
            res.render('gestores', {
                gestores,
                activeTab: 'gestores',
                feedback: req.query.msg ? { type: req.query.type || 'success', message: req.query.msg } : null
            });
        } catch (err) {
            console.error(err);
            res.render('gestores', {
                gestores: [],
                activeTab: 'gestores',
                feedback: { type: 'error', message: err.message }
            });
        }
    },

    async handleCreateGestor(req, res) {
        try {
            await gestorService.createGestor(req.body);
            res.redirect('/gestores?msg=Gestor+registrado+exitosamente&type=success');
        } catch (err) {
            console.error(err);
            res.redirect(`/gestores?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    },

    async handleDeleteGestor(req, res) {
        try {
            const { id } = req.params;
            await gestorService.deleteGestor(id);
            res.redirect('/gestores?msg=Gestor+eliminado+del+sistema&type=success');
        } catch (err) {
            console.error(err);
            res.redirect(`/gestores?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    }
};

module.exports = gestorController;