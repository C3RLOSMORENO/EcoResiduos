const materialService = require('../services/MaterialService');

const materialController = {
    async renderMaterialesPage(req, res) {
        try {
            const materiales = await materialService.getAllMateriales();
            res.render('materiales', {
                materiales,
                activeTab: 'materiales',
                feedback: req.query.msg ? { type: req.query.type || 'success', message: req.query.msg } : null
            });
        } catch (err) {
            console.error(err);
            res.render('materiales', {
                materiales: [],
                activeTab: 'materiales',
                feedback: { type: 'error', message: err.message }
            });
        }
    },

    async handleCreateMaterial(req, res) {
        try {
            await materialService.createMaterial(req.body);
            res.redirect('/materiales?msg=Material+añadido+al+catálogo&type=success');
        } catch (err) {
            console.error(err);
            res.redirect(`/materiales?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    },

    async handleDeleteMaterial(req, res) {
        try {
            const { id } = req.params;
            await materialService.deleteMaterial(id);
            res.redirect('/materiales?msg=Material+eliminado+del+catálogo&type=success');
        } catch (err) {
            console.error(err);
            res.redirect(`/materiales?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    }
};

module.exports = materialController;