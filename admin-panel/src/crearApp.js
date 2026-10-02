const express = require('express');
const path = require('path');
const cookieParser = require('cookie-parser');
const compression = require('compression');
const routes = require('./routes');
const vistaMiddleware = require('./middlewares/vistaMiddleware');
const seguridadMiddleware = require('./middlewares/seguridadMiddleware');
const csrfMiddleware = require('./middlewares/csrfMiddleware');
const { LIBRERIAS, PUBLICO, cacheSegunVersion } = require('./utils/recursos');

// La aplicación sin escuchar un puerto: server.js la inicia y las pruebas la
// usan con supertest.
function crearApp() {
    const app = express();

    app.disable('x-powered-by');
    // Detrás de un proxy (Render, Railway, Nginx…) la IP real del visitante
    // llega en X-Forwarded-For. TRUST_PROXY dice cuántos proxies hay delante;
    // sin él se usa la IP de la conexión, y el límite de intentos del login
    // contaría a todos los visitantes como si fueran uno.
    if (process.env.TRUST_PROXY) {
        const saltos = Number(process.env.TRUST_PROXY);
        app.set('trust proxy', Number.isInteger(saltos) ? saltos : process.env.TRUST_PROXY);
    }
    app.set('view engine', 'ejs');
    app.set('views', path.join(__dirname, 'views'));

    app.use(seguridadMiddleware);
    // gzip o Brotli para HTML, CSS, JS y JSON (las fotos y PDF ya vienen
    // comprimidos y compression los deja pasar sin tocarlos).
    app.use(compression());

    app.use(express.urlencoded({ extended: true, limit: '200kb' }));
    app.use(express.json({ limit: '200kb' }));
    app.use(cookieParser());
    app.use(express.static(PUBLICO, {
        cacheControl: false,
        setHeaders: (res) => res.set('Cache-Control', cacheSegunVersion(res.req))
    }));
    Object.entries(LIBRERIAS).forEach(([ruta, archivo]) => {
        app.get(ruta, (req, res) => {
            res.set('Cache-Control', cacheSegunVersion(req));
            res.type('application/javascript').sendFile(archivo, { cacheControl: false });
        });
    });
    app.use(vistaMiddleware);
    app.use(csrfMiddleware);

    app.use('/', routes);

    app.use((req, res) => {
        res.status(404).render('404', { titulo: 'Página no encontrada' });
    });

    // Express reconoce el manejador de errores por sus cuatro parámetros.
    app.use((err, req, res, _next) => {
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
