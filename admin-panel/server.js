require('dotenv').config();
const crearApp = require('./src/crearApp');

const PORT = process.env.PORT || 3000;

crearApp().listen(PORT, () => {
    console.log(`\x1b[32m✔ Servidor activo en http://localhost:${PORT}\x1b[0m`);
});
