const ExcelJS = require('exceljs');
const { fechaHora } = require('./formato');

// Colores del tema claro del panel (tokens de input.css), en ARGB.
const COLOR = {
    primario: 'FF1F4A2C',
    sobrePrimario: 'FFFFFFFF',
    contenedorPrimario: 'FFB8E6BE',
    sobreContenedorPrimario: 'FF00210D',
    textoSecundario: 'FF43483E',
    borde: 'FFC3C8BB'
};

const ENTERO = '#,##0';
const DECIMAL = '#,##0.00';
const ANCHO_CIFRA = 16;
// Las notas y los títulos ocupan al menos este número de columnas, aunque la
// tabla tenga menos, para que no queden en una franja angosta.
const COLUMNAS_MINIMAS = 6;

const linea = (color, estilo = 'thin') => ({ style: estilo, color: { argb: color } });
const BORDE_CELDA = {
    top: linea(COLOR.borde), left: linea(COLOR.borde), bottom: linea(COLOR.borde), right: linea(COLOR.borde)
};

/**
 * Texto en varias columnas unidas. Excel no ajusta el alto de una celda unida,
 * así que se calcula por el largo del texto.
 *
 * @param {import('exceljs').Worksheet} hoja
 * @param {number} numeroFila
 * @param {number} columnas Columnas que ocupa el texto, desde la primera.
 * @param {string} texto
 * @param {Partial<import('exceljs').Font>} [fuente]
 */
function escribirTexto(hoja, numeroFila, columnas, texto, fuente = {}) {
    hoja.mergeCells(numeroFila, 1, numeroFila, columnas);
    const celda = hoja.getCell(numeroFila, 1);
    celda.value = texto;
    celda.font = fuente;
    celda.alignment = { vertical: 'top', wrapText: true };
    let caracteresPorLinea = 0;
    for (let i = 1; i <= columnas; i++) caracteresPorLinea += hoja.getColumn(i).width;
    const lineas = Math.max(1, Math.ceil(texto.length / caracteresPorLinea));
    hoja.getRow(numeroFila).height = lineas * 15 * ((fuente.size || 11) / 11);
}

/**
 * Alineación, bordes y formato numérico de una fila de la tabla; la fila de
 * total va además en negrita sobre el color primario.
 *
 * @param {import('exceljs').Row} fila
 * @param {string} formato Formato numérico de Excel para las columnas de cifras.
 * @param {boolean} esTotal
 */
function darFormatoFila(fila, formato, esTotal) {
    fila.height = esTotal ? 22 : 20;
    fila.eachCell((celda, columna) => {
        celda.alignment = { vertical: 'middle', horizontal: columna === 1 ? 'left' : 'right' };
        celda.border = BORDE_CELDA;
        if (columna > 1) celda.numFmt = formato;
        if (esTotal) {
            celda.font = { bold: true, color: { argb: COLOR.sobreContenedorPrimario } };
            celda.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: COLOR.contenedorPrimario } };
            celda.border = { ...BORDE_CELDA, top: linea(COLOR.primario, 'medium') };
        }
    });
}

/**
 * Una hoja con título, filtros, la tabla con su fila de total y las notas para
 * leer las cifras. Se imprime en horizontal, a una página de ancho.
 *
 * @param {import('exceljs').Workbook} libro
 * @param {object} hojaDatos Nombre, título, encabezados, filas, total, formato,
 *     notas y el texto para cuando no hay filas (vacio).
 */
function agregarHoja(libro, hojaDatos) {
    const { nombre, titulo, metadatos, leyenda, encabezados, filas, total, formato, notas, vacio } = hojaDatos;
    const hoja = libro.addWorksheet(nombre, {
        pageSetup: { orientation: 'landscape', fitToPage: true, fitToWidth: 1, fitToHeight: 0, horizontalCentered: true },
        headerFooter: { oddFooter: `&LEcoResiduos · ${titulo}&RPágina &P de &N` }
    });

    const columnas = Math.max(encabezados.length, COLUMNAS_MINIMAS);
    const anchoPrimera = Math.max(14, ...filas.map((f) => String(f[0]).length), String(total[0] || '').length) + 2;
    for (let i = 1; i <= columnas; i++) hoja.getColumn(i).width = i === 1 ? anchoPrimera : ANCHO_CIFRA;

    let n = 1;
    escribirTexto(hoja, n++, columnas, titulo, { size: 16, bold: true, color: { argb: COLOR.primario } });
    metadatos.forEach((texto) => escribirTexto(hoja, n++, columnas, texto, { color: { argb: COLOR.textoSecundario } }));
    n++;
    escribirTexto(hoja, n++, columnas, leyenda, { size: 12, bold: true });

    if (filas.length === 0) {
        escribirTexto(hoja, n++, columnas, vacio);
    } else {
        const encabezado = hoja.getRow(n++);
        encabezado.values = encabezados;
        encabezado.height = 32;
        encabezado.eachCell((celda, columna) => {
            celda.font = { bold: true, color: { argb: COLOR.sobrePrimario } };
            celda.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: COLOR.primario } };
            celda.alignment = { vertical: 'middle', horizontal: columna === 1 ? 'left' : 'right', wrapText: true };
            celda.border = BORDE_CELDA;
        });
        filas.forEach((valores) => {
            const fila = hoja.getRow(n++);
            fila.values = valores;
            darFormatoFila(fila, formato, false);
        });
        const filaTotal = hoja.getRow(n++);
        filaTotal.values = total;
        darFormatoFila(filaTotal, formato, true);
    }

    n++;
    escribirTexto(hoja, n++, columnas, 'Cómo leer estas cifras', { bold: true });
    notas.forEach((nota) => escribirTexto(hoja, n++, columnas, `• ${nota}`));
}

/**
 * Reporte de reciclaje por municipio con los filtros de la pantalla. Lleva
 * solo cifras agregadas, sin datos personales. Los textos se escriben como
 * valores, nunca como fórmulas, así que un nombre que empiece con «=» no se
 * ejecuta al abrir el archivo.
 *
 * @param {object} reporte Resultado de ReporteService.reciclajePorMunicipio.
 * @param {string} descripcionFiltros Los filtros en una línea (describirFiltrosReporte).
 * @returns {Promise<Buffer>} El archivo .xlsx.
 */
async function generarExcelReporte(reporte, descripcionFiltros) {
    const libro = new ExcelJS.Workbook();
    libro.creator = 'Panel EcoResiduos';
    libro.title = 'Reciclaje por municipio';
    libro.created = new Date();

    const metadatos = [
        `Filtros: ${descripcionFiltros}.`,
        `Generado el ${fechaHora(new Date())} (hora de Colombia) desde el panel de EcoResiduos.`
    ];

    agregarHoja(libro, {
        nombre: 'Recolecciones',
        titulo: 'Reciclaje por municipio',
        metadatos,
        leyenda: 'Número de recolecciones confirmadas por municipio y categoría',
        encabezados: ['Municipio', ...reporte.categorias.map((c) => c.etiqueta), 'Total confirmadas', 'Recolectadas sin confirmar'],
        filas: reporte.filas.map((fila) => [
            fila.municipio,
            ...reporte.categorias.map((c) => fila.porCategoria[c.clave]),
            fila.confirmadas,
            fila.sinConfirmar
        ]),
        total: [
            'Total',
            ...reporte.categorias.map((c) => reporte.total.porCategoria[c.clave]),
            reporte.total.confirmadas,
            reporte.total.sinConfirmar
        ],
        formato: ENTERO,
        vacio: 'No hay recolecciones con estos filtros.',
        notas: [
            'Se cuentan las recolecciones confirmadas por el generador o confirmadas solas a las 72 horas. Las que tienen un problema reportado sin confirmar no se cuentan.',
            '«Recolectadas sin confirmar» son las que el gestor marcó como recolectadas y aún no se confirman. No suman en las demás columnas.',
            ...(reporte.hayOtro ? ['«Otro / sin dato» agrupa las solicitudes cuyo municipio no es uno de los 6 donde opera EcoResiduos.'] : []),
            'El archivo solo tiene cifras agregadas: no incluye datos de generadores ni de gestores.'
        ]
    });

    const hayUnidades = reporte.unidades.length > 0;
    agregarHoja(libro, {
        nombre: 'Cantidades por unidad',
        titulo: 'Cantidades declaradas por unidad',
        metadatos,
        leyenda: 'Cantidades estimadas por los generadores, en la unidad que cada uno declaró',
        encabezados: hayUnidades ? ['Municipio', ...reporte.unidades.map((u) => u.etiqueta)] : [],
        filas: hayUnidades
            ? reporte.filas.map((fila) => [fila.municipio, ...reporte.unidades.map((u) => Number(fila.porUnidad[u.clave]) || 0)])
            : [],
        total: ['Total', ...reporte.unidades.map((u) => Number(reporte.total.porUnidad[u.clave]) || 0)],
        formato: DECIMAL,
        vacio: 'No hay recolecciones confirmadas con estos filtros.',
        notas: [
            'Solo se suman las recolecciones confirmadas.',
            'Cada columna suma solo las cantidades declaradas en esa unidad: no se convierten ni se mezclan unidades.',
            'Son estimaciones de los generadores, no pesajes.'
        ]
    });

    return libro.xlsx.writeBuffer();
}

module.exports = { generarExcelReporte };
