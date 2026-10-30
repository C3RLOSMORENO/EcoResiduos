const SolicitudService = require('../services/SolicitudService');
const { leerPagina, paginacion, conAviso, rutaInterna } = require('../utils/web');
const { responderErrorCarga, renderLista } = require('../utils/errores');
const { filtrosSolicitudes, describirFiltrosSolicitudes } = require('../utils/filtros');
const { datosRecorrido } = require('../utils/recorridos');

/** GET /solicitudes: lista con filtros y paginación. */
exports.listarSolicitudes = (req, res) => {
    const filtros = filtrosSolicitudes(req.query);
    const pagina = leerPagina(req.query);
    return renderLista(res, 'solicitudes', {
        comunes: {
            titulo: 'Solicitudes',
            activeTab: 'solicitudes',
            recorrido: datosRecorrido('solicitudes', req.user),
            filtros,
            descripcionFiltros: describirFiltrosSolicitudes(filtros),
            estadosCancelables: SolicitudService.ESTADOS_CANCELABLES,
            problemaResoluble: SolicitudService.problemaResoluble
        },
        cargar: async () => {
            const { solicitudes, total } = await SolicitudService.listar(filtros, pagina);
            return { solicitudes, pag: paginacion({ total, pagina, ruta: '/solicitudes', query: req.query }) };
        },
        vacio: { solicitudes: [], pag: null }
    });
};

/** GET /solicitudes/:id: detalle con historial, postulaciones y acciones. */
exports.verSolicitud = async (req, res, next) => {
    try {
        const detalle = await SolicitudService.obtenerDetalle(req.params.id);
        if (!detalle) return next();
        res.render('solicitud-detalle', {
            titulo: `Solicitud ${detalle.solicitud.id}`,
            activeTab: 'solicitudes',
            ...detalle,
            estadosCancelables: SolicitudService.ESTADOS_CANCELABLES,
            problemaResoluble: SolicitudService.problemaResoluble
        });
    } catch (error) {
        responderErrorCarga(res, next, error, { activeTab: 'solicitudes', que: `la solicitud ${req.params.id}`, volver: { href: '/solicitudes', texto: 'Solicitudes' } });
    }
};

/** POST /solicitudes/:id/cancelar */
exports.cancelar = async (req, res) => {
    const { id } = req.params;
    const destino = rutaInterna(req.body.redirectUrl, `/solicitudes/${id}`);
    try {
        const resultado = await SolicitudService.cancelar(id);
        const rechazadas = (resultado && resultado.postulaciones_rechazadas) || 0;
        const detalle = rechazadas > 0 ? ` Se rechazaron ${rechazadas} propuesta(s) abiertas y sus gestores recibieron el aviso.` : '';
        res.redirect(conAviso(destino, `Solicitud cancelada.${detalle}`));
    } catch (error) {
        res.redirect(conAviso(destino, error.message, 'error'));
    }
};

/**
 * POST /solicitudes/:id/estado: ruta anterior del selector libre de estados.
 * Solo se conserva cancelar: los demás cambios se saltaban las reglas de la app.
 */
exports.cambiarEstado = async (req, res) => {
    const estado = String(req.body.estado || '').toUpperCase();
    if (estado === 'CANCELADO') {
        return exports.cancelar(req, res);
    }
    const destino = rutaInterna(req.body.redirectUrl, '/solicitudes');
    return res.redirect(conAviso(destino, 'Desde el panel solo se puede cancelar una solicitud. Los demás estados los cambian el generador y el gestor en la app.', 'error'));
};

/** POST /solicitudes/:id/problema/no-recogido */
exports.resolverNoRecogido = async (req, res) => {
    const { id } = req.params;
    const destino = rutaInterna(req.body.redirectUrl, `/solicitudes/${id}`);
    try {
        await SolicitudService.resolverNoRecogido(id, req.body.nota);
        res.redirect(conAviso(destino, 'Problema resuelto: no se recogió. La solicitud volvió a En negociación y avisamos al generador y al gestor.'));
    } catch (error) {
        res.redirect(conAviso(destino, error.message, 'error'));
    }
};

/** GET /solicitudes/:id/certificado: el PDF del certificado, servido por el panel. */
exports.verCertificado = async (req, res) => {
    const { id } = req.params;
    try {
        const { buffer, url } = await SolicitudService.descargarCertificado(id);
        if (url) {
            res.set('Cache-Control', 'no-store');
            return res.redirect(url);
        }
        res.set({
            'Content-Type': 'application/pdf',
            'Content-Disposition': `inline; filename="certificado-${id}.pdf"`,
            'Content-Length': buffer.length,
            'Cache-Control': 'private, no-cache, no-store, must-revalidate',
            'X-Content-Type-Options': 'nosniff'
        });
        return res.send(buffer);
    } catch (error) {
        return res.redirect(conAviso(`/solicitudes/${encodeURIComponent(id)}`, error.message, 'error'));
    }
};
