// Filtros de las listas: se leen de la URL ya validados (un valor que no
// está en la lista se ignora) y se describen para el título de la tabla.
const { municipioAdmitido } = require('./municipios');
const { ESTADOS_SOLICITUD, ESTADOS_GESTOR, CATEGORIAS, CATEGORIAS_CATALOGO, etiquetaEstado, etiquetaCategoria, fechaCorta } = require('./formato');
const { textoBusqueda } = require('./web');
const { rangoBogota } = require('./fechas');

const texto = (valor) => String(valor || '').trim();
const mayusculas = (valor) => String(valor || '').toUpperCase();
const unoDe = (valor, admitidos, porDefecto = '') => (admitidos.includes(valor) ? valor : porDefecto);

function filtrosSolicitudes(query = {}) {
    const fechas = rangoBogota(query.desde, query.hasta);
    const categoria = mayusculas(query.categoria);
    const generador = parseInt(query.generador, 10);
    return {
        estado: unoDe(mayusculas(query.estado), ESTADOS_SOLICITUD),
        municipio: municipioAdmitido(query.municipio) || '',
        categoria: CATEGORIAS[categoria] ? categoria : '',
        desde: fechas.desde || '',
        hasta: fechas.hasta || '',
        q: textoBusqueda(query.q),
        problema: query.problema === '1' ? '1' : '',
        sinCertificado: query.sin_certificado === '1' ? '1' : '',
        generador: Number.isInteger(generador) && generador > 0 ? generador : '',
        orden: query.orden === 'fecha' ? 'fecha' : '-fecha'
    };
}

// La fecha del filtro es un día (AAAA-MM-DD); al mediodía de Colombia cae
// en ese mismo día en cualquier zona horaria.
const diaDelFiltro = (dia) => fechaCorta(`${dia}T12:00:00-05:00`);

// Los filtros aplicados en una frase corta, para el título de la tabla;
// vacía si no hay ninguno.
function describirFiltrosSolicitudes(filtros) {
    return [
        filtros.problema ? 'con problema reportado' : null,
        filtros.sinCertificado ? 'recolectadas sin certificado hace más de 7 días' : null,
        filtros.estado ? etiquetaEstado(filtros.estado) : null,
        filtros.municipio || null,
        filtros.categoria ? etiquetaCategoria(filtros.categoria) : null,
        filtros.desde ? `desde ${diaDelFiltro(filtros.desde)}` : null,
        filtros.hasta ? `hasta ${diaDelFiltro(filtros.hasta)}` : null,
        filtros.q ? `material «${filtros.q}»` : null,
        filtros.generador ? 'de un generador' : null
    ].filter(Boolean).join(' · ');
}

function filtrosGestores(query = {}) {
    return {
        q: texto(query.q),
        municipio: municipioAdmitido(query.municipio) || '',
        estado: unoDe(mayusculas(query.estado), ESTADOS_GESTOR),
        porVerificar: query.por_verificar === '1' ? '1' : '',
        orden: query.orden === '-razon' ? '-razon' : 'razon'
    };
}

function filtrosMateriales(query = {}) {
    return {
        q: texto(query.q),
        categoria: unoDe(mayusculas(query.categoria), CATEGORIAS_CATALOGO),
        orden: unoDe(query.orden, ['codigo', '-codigo', 'nombre', '-nombre'], 'codigo')
    };
}

function filtrosCiudadanos(query = {}) {
    return {
        q: texto(query.q),
        municipio: municipioAdmitido(query.municipio) || ''
    };
}

function filtrosAutoridades(query = {}) {
    return { q: texto(query.q) };
}

function filtrosReporte(query = {}) {
    const fechas = rangoBogota(query.desde, query.hasta);
    const categoria = mayusculas(query.categoria);
    return {
        desde: fechas.desde || '',
        hasta: fechas.hasta || '',
        categoria: CATEGORIAS[categoria] ? categoria : ''
    };
}

function describirFiltrosReporte(filtros) {
    return [
        filtros.desde ? `Confirmadas desde ${filtros.desde}` : 'Desde el inicio',
        filtros.hasta ? `hasta ${filtros.hasta}` : 'hasta hoy',
        filtros.categoria ? `Categoría: ${etiquetaCategoria(filtros.categoria)}` : 'Todas las categorías'
    ].join(' · ');
}

// Enlace de descarga del CSV con los mismos filtros que se ven en pantalla.
function enlaceCsvReporte(filtros) {
    const params = new URLSearchParams();
    ['desde', 'hasta', 'categoria'].forEach((clave) => {
        if (filtros[clave]) params.set(clave, filtros[clave]);
    });
    const cadena = params.toString();
    return `/reportes/csv${cadena ? `?${cadena}` : ''}`;
}

module.exports = {
    filtrosSolicitudes,
    describirFiltrosSolicitudes,
    filtrosGestores,
    filtrosMateriales,
    filtrosCiudadanos,
    filtrosAutoridades,
    filtrosReporte,
    describirFiltrosReporte,
    enlaceCsvReporte
};
