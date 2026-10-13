const materialService = require('../services/MaterialService');
const { leerPagina, paginacion, conAviso } = require('../utils/web');
const { responderErrorCarga, renderLista } = require('../utils/errores');
const { filtrosMateriales } = require('../utils/filtros');

const materialController = {
    /** GET /materiales: catálogo con filtros y paginación. */
    renderMaterialesPage(req, res) {
        const pagina = leerPagina(req.query);
        const filtros = filtrosMateriales(req.query);
        return renderLista(res, 'materiales', {
            comunes: { titulo: 'Materiales', activeTab: 'materiales', filtros },
            cargar: async () => {
                const { materiales, total } = await materialService.listarMateriales({ ...filtros, pagina });
                return { materiales, pag: paginacion({ total, pagina, ruta: '/materiales', query: req.query }) };
            },
            vacio: { materiales: [], pag: null }
        });
    },

    /** GET /materiales/nuevo: formulario vacío. */
    renderNuevoMaterial(req, res) {
        res.render('material-edit', {
            titulo: 'Nuevo material',
            activeTab: 'materiales',
            modo: 'crear',
            material: {},
            dependencias: null
        });
    },

    /** POST /materiales: agrega el material al catálogo. */
    async handleCreateMaterial(req, res) {
        try {
            await materialService.createMaterial(req.body);
            res.redirect(conAviso('/materiales', 'Material añadido al catálogo.'));
        } catch (err) {
            res.redirect(conAviso('/materiales/nuevo', err.message, 'error'));
        }
    },

    /** GET /materiales/edit/:id: formulario con los datos actuales y lo que impide borrarlo. */
    async renderEditMaterial(req, res, next) {
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
            responderErrorCarga(res, next, err, { activeTab: 'materiales', que: 'el material', volver: { href: '/materiales', texto: 'Materiales' } });
        }
    },

    /** POST /materiales/edit/:id: guarda los cambios. */
    async handleUpdateMaterial(req, res) {
        const { id } = req.params;
        try {
            await materialService.updateMaterial(id, req.body);
            res.redirect(conAviso('/materiales', 'Material actualizado.'));
        } catch (err) {
            res.redirect(conAviso(`/materiales/edit/${id}`, err.message, 'error'));
        }
    },

    /** POST /materiales/delete/:id: elimina el material si no tiene solicitudes. */
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
