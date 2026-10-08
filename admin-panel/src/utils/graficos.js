// Datos de los gráficos del panel, listos para las vistas y para main.js.
//
// Reglas (las mismas en todos los gráficos):
// - El color sigue a la entidad, no a su posición: Aprovechable es siempre la
//   ranura 1 aunque un filtro deje solo esa categoría. Las ranuras son las
//   variables --eco-graf-N de input.css, validadas para daltonismo en ese
//   orden.
// - Nunca una novena tonalidad: lo que no cabe, o no tiene dato, va en gris.
// - Barras ordenadas de mayor a menor; «Otro / sin dato» siempre al final.
// - Cada gráfico lleva una frase con la conclusión y sus cifras, para quien
//   no ve el gráfico (y para quien lo ve con prisa).
const { CATEGORIAS_CATALOGO, formatoNumero, formatoPorcentaje } = require('./formato');

const RANURAS = 8;
const OTRO = 'Otro / sin dato';

const variable = (ranura) => `--eco-graf-${ranura}`;

// Las categorías del catálogo ocupan las primeras ranuras en su orden; las
// demás (orgánico, ordinario…) siguen en orden de aparición. «Sin categoría»
// es gris: no es una categoría más.
function ranurasCategorias(categorias) {
    let siguiente = CATEGORIAS_CATALOGO.length + 1;
    return Object.fromEntries(categorias.map(({ clave }) => {
        if (clave === 'SIN_CATEGORIA') return [clave, 'neutro'];
        const i = CATEGORIAS_CATALOGO.indexOf(clave);
        if (i >= 0) return [clave, String(i + 1)];
        const ranura = siguiente <= RANURAS ? String(siguiente) : 'neutro';
        siguiente += 1;
        return [clave, ranura];
    }));
}

function ordenarFilas(filas, valor) {
    return [...filas].sort((a, b) => {
        if ((a.municipio === OTRO) !== (b.municipio === OTRO)) return a.municipio === OTRO ? 1 : -1;
        return valor(b) - valor(a) || a.municipio.localeCompare(b.municipio, 'es');
    });
}

// El municipio con más registros; «Otro / sin dato» no cuenta como uno.
const municipioLider = (filas, valor) => filas.find((f) => f.municipio !== OTRO && valor(f) > 0) || null;

const conCifra = (n, singular, varios) => `${formatoNumero(n)} ${Number(n) === 1 ? singular : varios}`;

// Reporte: municipios × categorías, barras apiladas horizontales.
function graficoReporte(reporte) {
    const ranuras = ranurasCategorias(reporte.categorias);
    const filas = ordenarFilas(reporte.filas, (f) => f.confirmadas);
    const total = reporte.total.confirmadas;

    const series = reporte.categorias
        .filter((c) => reporte.total.porCategoria[c.clave] > 0)
        .map((c) => ({
            clave: c.clave,
            nombre: c.etiqueta,
            ranura: ranuras[c.clave],
            total: reporte.total.porCategoria[c.clave],
            proporcion: formatoPorcentaje(reporte.total.porCategoria[c.clave], total),
            valores: filas.map((f) => f.porCategoria[c.clave])
        }));

    const lider = municipioLider(filas, (f) => f.confirmadas);
    const conDatos = filas.filter((f) => f.municipio !== OTRO && f.confirmadas > 0).length;
    let resumen = 'No hay recolecciones confirmadas con estos filtros.';
    if (lider) {
        resumen = `${lider.municipio} encabeza con ${conCifra(lider.confirmadas, 'recolección', 'recolecciones')} `
          + `(${formatoPorcentaje(lider.confirmadas, total)} de ${formatoNumero(total)}); `
          + `${conCifra(conDatos, 'municipio registra', 'municipios registran')} recolecciones confirmadas.`;
    } else if (total > 0) {
        resumen = total === 1
            ? '1 recolección confirmada, de un municipio fuera de la zona de operación.'
            : `${formatoNumero(total)} recolecciones confirmadas, todas de municipios fuera de la zona de operación.`;
    }

    return {
        resumen,
        series,
        datos: {
            tipo: series.length > 1 ? 'apiladas' : 'barras',
            unidad: ['recolección', 'recolecciones'],
            etiquetas: filas.map((f) => f.municipio),
            series: series.map((s) => ({ nombre: s.nombre, valores: s.valores, color: variable(s.ranura) }))
        }
    };
}

// Cifras destacadas del reporte: total, pendientes, municipio y categoría
// principales.
function cifrasReporte(reporte) {
    const total = reporte.total.confirmadas;
    const lider = municipioLider(ordenarFilas(reporte.filas, (f) => f.confirmadas), (f) => f.confirmadas);
    const categoria = [...reporte.categorias]
        .sort((a, b) => reporte.total.porCategoria[b.clave] - reporte.total.porCategoria[a.clave])[0];
    const totalCategoria = categoria ? reporte.total.porCategoria[categoria.clave] : 0;
    return {
        confirmadas: total,
        sinConfirmar: reporte.total.sinConfirmar,
        municipios: reporte.filas.filter((f) => f.municipio !== OTRO && f.confirmadas > 0).length,
        municipiosTotal: reporte.filas.filter((f) => f.municipio !== OTRO).length,
        lider: lider ? { nombre: lider.municipio, valor: lider.confirmadas, proporcion: formatoPorcentaje(lider.confirmadas, total) } : null,
        categoria: totalCategoria > 0 ? { nombre: categoria.etiqueta, valor: totalCategoria, proporcion: formatoPorcentaje(totalCategoria, total) } : null
    };
}

// Inicio: estado de las solicitudes como una barra de proporción (parte de
// un todo con 4 partes). Las ranuras 1, 2, 3 y 7 se validaron como vecinas.
const ESTADOS = [
    { clave: 'solicitudesPublicadas', nombre: 'Publicadas', ranura: '1' },
    { clave: 'solicitudesEnProceso', nombre: 'En negociación', ranura: '2' },
    { clave: 'solicitudesRecolectadas', nombre: 'Recolectadas', ranura: '3' },
    { clave: 'solicitudesCanceladas', nombre: 'Canceladas', ranura: '7' }
];

function graficoEstados(kpis) {
    const series = ESTADOS.map((e) => ({ ...e, valor: Number(kpis[e.clave]) || 0 }));
    const total = series.reduce((suma, s) => suma + s.valor, 0);
    series.forEach((s) => { s.proporcion = formatoPorcentaje(s.valor, total); });
    const mayor = [...series].sort((a, b) => b.valor - a.valor)[0];
    return {
        total,
        series,
        resumen: total === 0
            ? 'Aún no hay solicitudes.'
            : `${formatoNumero(total)} ${total === 1 ? 'solicitud' : 'solicitudes'} en total; ${mayor.proporcion} están ${mayor.nombre.toLowerCase()}.`,
        datos: {
            tipo: 'proporcion',
            unidad: ['solicitud', 'solicitudes'],
            etiquetas: ['Solicitudes'],
            series: series.map((s) => ({ nombre: s.nombre, valores: [s.valor], color: variable(s.ranura) }))
        }
    };
}

// Inicio: solicitudes por municipio, una sola serie en el color de la marca.
function graficoMunicipios(chartData) {
    const filas = ordenarFilas(
        chartData.municipiosLabels.map((municipio, i) => ({ municipio, valor: Number(chartData.municipiosData[i]) || 0 })),
        (f) => f.valor
    );
    const total = filas.reduce((suma, f) => suma + f.valor, 0);
    const lider = municipioLider(filas, (f) => f.valor);
    let resumen = total === 0 ? 'Aún no hay solicitudes.' : `${formatoNumero(total)} solicitudes, todas de municipios fuera de la zona de operación.`;
    if (lider) resumen = `${lider.municipio} concentra ${formatoNumero(lider.valor)} de las ${formatoNumero(total)} solicitudes (${formatoPorcentaje(lider.valor, total)}).`;
    return {
        total,
        filas: filas.map((f) => ({ ...f, proporcion: formatoPorcentaje(f.valor, total) })),
        resumen,
        datos: {
            tipo: 'barras',
            unidad: ['solicitud', 'solicitudes'],
            etiquetas: filas.map((f) => f.municipio),
            series: [{ nombre: 'Solicitudes', valores: filas.map((f) => f.valor), color: '--eco-graf-unica' }]
        }
    };
}

module.exports = { ranurasCategorias, graficoReporte, cifrasReporte, graficoEstados, graficoMunicipios };
