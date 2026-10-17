const { cargarEntorno, revisarEntorno } = require('../src/config/entorno');

cargarEntorno();
const { faltan, avisos } = revisarEntorno();
if (faltan.length > 0) {
    console.error('✖ El panel no puede arrancar: faltan variables en el entorno de Vercel:');
    faltan.forEach((linea) => console.error(`  - ${linea}`));
}
avisos.forEach((aviso) => console.warn(`! ${aviso}`));

const crearApp = require('../src/crearApp');
const app = crearApp();

module.exports = app;
