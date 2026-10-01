const materialService = require('../services/MaterialService');
const { leerPagina, paginacion, conAviso } = require('../utils/web');
const { CATEGORIAS_CATALOGO } = require('../utils/formato');

const materialController = {
    async renderMaterialesPage(req, res) {
        const pagina = leerPagina(req.query);
        const categoria = String(req.query.categoria || '').toUpperCase();
        const filtros = {
            q: String(req.query.q || '').trim(),
            categoria: CATEGORIAS_CATALOGO.includes(categoria) ? categoria : '',
            orden: ['codigo', '-codigo', 'nombre', '-nombre'].includes(req.query.orden) ? req.query.orden : 'codigo'
        };
        try {
            const { materiales, total } = await materialService.listarMateriales({ ...filtros, pagina });
            res.render('materiales', {
                titulo: 'Materiales',
                activeTab: 'materiales',
                materiales,
                filtros,
                pag: paginacion({ total, pagina, ruta: '/materiales', query: req.query }),
                errorCarga: null
            });
        } catch (err) {
            res.status(500).render('materiales', {
                titulo: 'Materiales',
                activeTab: 'materiales',
                materiales: [],
                filtros,
                pag: null,
                errorCarga: err.message
            });
        }
    },

    renderNuevoMaterial(req, res) {
        res.render('material-edit', {
            titulo: 'Nuevo material',
            activeTab: 'materiales',
            modo: 'crear',
            material: {},
            dependencias: null
        });
    },

    async handleCreateMaterial(req, res) {
        try {
            await materialService.createMaterial(req.body);
            res.redirect(conAviso('/materiales', 'Material añadido al catálogo.'));
        } catch (err) {
            res.redirect(conAviso('/materiales/nuevo', err.message, 'error'));
        }
    },

    async renderEditMaterial(req, res) {
        try {
            const { id } = req.params;
            const [material, dependencias] = await Promise.all([
                materialService.getMaterialById(id),
                materialService.getDependencias(id)
            ]);
            res.render('material-edit', {
                titulo: `Editar ${material.nombre_comun || 'material'}`,
                activeTab: 'materiales',
                modo: 'editar',
                material,
                dependencias
            });
        } catch (err) {
            res.redirect(conAviso('/materiales', err.message, 'error'));
        }
    },

    async handleUpdateMaterial(req, res) {
        const { id } = req.params;
        try {
            await materialService.updateMaterial(id, req.body);
            res.redirect(conAviso('/materiales', 'Material actualizado.'));
        } catch (err) {
            res.redirect(conAviso(`/materiales/edit/${id}`, err.message, 'error'));
        }
    },

    async handleDeleteMaterial(req, res) {
        const { id } = req.params;
        try {
            await materialService.deleteMaterial(id);
            res.redirect(conAviso('/materiales', 'Material eliminado del catálogo.'));
        } catch (err) {
            const destino = err.codigo === 'TIENE_HISTORIA' ? `/materiales/edit/${id}` : '/materiales';
            res.redirect(conAviso(destino, err.message, 'error'));
        }
    }
};

module.exports = materialController;
