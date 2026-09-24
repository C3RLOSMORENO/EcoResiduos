const gestorService = require('../services/GestorService');
const materialService = require('../services/MaterialService');

const gestorController = {
    async renderGestoresPage(req, res) {
        try {
            const [gestores, materialesDisponibles] = await Promise.all([
                gestorService.getAllGestores(),
                materialService.getAllMateriales()
            ]);

            res.render('gestores', {
                gestores,
                materialesDisponibles,
                activeTab: 'gestores',
                feedback: req.query.msg ? { type: req.query.type || 'success', message: req.query.msg } : null
            });
        } catch (err) {
            res.render('gestores', {
                gestores: [],
                materialesDisponibles: [],
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
            res.redirect(`/gestores?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    },

    async renderEditGestor(req, res) {
        try {
            const { id } = req.params;
            const [gestor, materialesDisponibles] = await Promise.all([
                gestorService.getGestorById(id),
                materialService.getAllMateriales()
            ]);

            res.render('gestor-edit', {
                gestor,
                materialesDisponibles,
                activeTab: 'gestores',
                feedback: req.query.msg ? { type: req.query.type || 'error', message: req.query.msg } : null
            });
        } catch (err) {
            res.redirect(`/gestores?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    },

    async handleUpdateGestor(req, res) {
        const { id } = req.params;
        try {
            await gestorService.updateGestor(id, req.body);
            res.redirect('/gestores?msg=Gestor+actualizado+exitosamente&type=success');
        } catch (err) {
            res.redirect(`/gestores/edit/${id}?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    },

    async handleDeleteGestor(req, res) {
        try {
            const { id } = req.params;
            await gestorService.deleteGestor(id);
            res.redirect('/gestores?msg=Gestor+eliminado+del+sistema&type=success');
        } catch (err) {
            res.redirect(`/gestores?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    },

    async handleUpdateEstado(req, res) {
        const { id } = req.params;
        const { estado, redirectUrl } = req.body;
        const target = redirectUrl || '/gestores';
        try {
            await gestorService.updateEstadoVerificacion(id, estado);
            res.redirect(`${target}?msg=Estado+del+gestor+actualizado+a+${encodeURIComponent(estado)}&type=success`);
        } catch (err) {
            res.redirect(`${target}?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    }
};

module.exports = gestorController;