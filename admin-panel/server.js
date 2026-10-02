const { cargarEntorno, revisarEntorno } = require('./src/config/entorno');

cargarEntorno();
const { faltan, avisos } = revisarEntorno();
if (faltan.length > 0) {
    console.error('\x1b[31m✖ El panel no puede arrancar: faltan variables en el archivo .env (copia .env.example):\x1b[0m');
    faltan.forEach((linea) => console.error(`  - ${linea}`));
    process.exit(1);
}
avisos.forEach((aviso) => console.warn(`\x1b[33m! ${aviso}\x1b[0m`));

const crearApp = require('./src/crearApp');

const PORT = process.env.PORT || 3000;

crearApp().listen(PORT, () => {
    console.log(`\x1b[32m✔ Servidor activo en http://localhost:${PORT}\x1b[0m`);
});
