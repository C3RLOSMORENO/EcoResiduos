const express = require('express');
const path = require('path');
const cookieParser = require('cookie-parser');
const routes = require('./routes');
const vistaMiddleware = require('./middlewares/vistaMiddleware');

// La aplicación sin escuchar un puerto: server.js la inicia y las pruebas la
// usan con supertest.
function crearApp() {
    const app = express();

    app.disable('x-powered-by');
    app.set('view engine', 'ejs');
    app.set('views', path.join(__dirname, 'views'));

    app.use((req, res, next) => {
        res.set({
            'X-Content-Type-Options': 'nosniff',
            'X-Frame-Options': 'DENY',
            'Referrer-Policy': 'same-origin'
        });
        next();
    });

    app.use(express.urlencoded({ extended: true, limit: '200kb' }));
    app.use(express.json({ limit: '200kb' }));
    app.use(cookieParser());
    app.use(express.static(path.join(__dirname, 'public')));
    app.use(vistaMiddleware);

    app.use('/', routes);

    app.use((req, res) => {
        res.status(404).render('404', { titulo: 'Página no encontrada' });
    });

    // Express reconoce el manejador de errores por sus cuatro parámetros.
    app.use((err, req, res, next) => {
        console.error('Error no controlado:', err);
        res.status(500).render('404', {
            titulo: 'Algo salió mal',
            mensaje: 'No pudimos completar la acción. Vuelve a intentarlo en unos minutos.',
            icono: 'error'
        });
    });

    return app;
}

module.exports = crearApp;
