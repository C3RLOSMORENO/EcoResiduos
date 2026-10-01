const BOM = '\ufeff';

// Excel ejecuta como fórmula la celda que empieza con estos caracteres
// (inyección CSV, OWASP). Se antepone un apóstrofo para que quede como texto.
const INICIO_FORMULA = /^[=+\-@\t\r]/;

function celdaCsv(valor) {
    let texto = valor === null || valor === undefined ? '' : String(valor);
    if (INICIO_FORMULA.test(texto)) texto = `'${texto}`;
    if (/[";\n\r]/.test(texto)) texto = `"${texto.replace(/"/g, '""')}"`;
    return texto;
}

// Separador «;»: Excel en español de Colombia usa la coma como decimal.
function generarCsv(filas) {
    return BOM + filas.map((fila) => fila.map(celdaCsv).join(';')).join('\r\n') + '\r\n';
}

module.exports = { celdaCsv, generarCsv };
