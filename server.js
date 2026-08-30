require('dotenv').config();
const express = require('express');
const path = require('path');
const cookieParser = require('cookie-parser');
const routes = require('./src/routes');

const app = express();
const PORT = process.env.PORT || 3000;

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'src/views'));

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'src/public')));

app.use('/', routes);

app.use((req, res) => {
    res.status(404).render('partials/alert', {
        type: 'error',
        message: 'La página que buscas no existe o fue movida.',
        title: 'Recurso No Encontrado (404)'
    });
});

app.listen(PORT, () => {
    console.log(`\x1b[32m✔ Servidor activo en http://localhost:${PORT}\x1b[0m`);
});