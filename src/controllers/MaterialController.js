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
            res.redirect(`/materiales?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    },

    async renderEditMaterial(req, res) {
        try {
            const { id } = req.params;
            const material = await materialService.getMaterialById(id);
            res.render('material-edit', {
                material,
                activeTab: 'materiales',
                feedback: req.query.msg ? { type: req.query.type || 'error', message: req.query.msg } : null
            });
        } catch (err) {
            res.redirect(`/materiales?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    },

    async handleUpdateMaterial(req, res) {
        const { id } = req.params;
        try {
            await materialService.updateMaterial(id, req.body);
            res.redirect('/materiales?msg=Material+actualizado+exitosamente&type=success');
        } catch (err) {
            res.redirect(`/materiales/edit/${id}?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    },

    async handleDeleteMaterial(req, res) {
        try {
            const { id } = req.params;
            await materialService.deleteMaterial(id);
            res.redirect('/materiales?msg=Material+eliminado+del+catálogo&type=success');
        } catch (err) {
            res.redirect(`/materiales?msg=${encodeURIComponent(err.message)}&type=error`);
        }
    }
};

module.exports = materialController;