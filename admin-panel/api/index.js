const { cargarEntorno, revisarEntorno } = require('../src/config/entorno');

cargarEntorno();
const { faltan } = revisarEntorno();

let handler;

if (faltan.length > 0) {
    // Si faltan variables en el panel de Vercel, respondemos con una pantalla
    // explicativa en lugar de romper la función serverless con FUNCTION_INVOCATION_FAILED
    handler = (req, res) => {
        res.statusCode = 500;
        res.setHeader('Content-Type', 'text/html; charset=utf-8');
        res.end(`<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Configuración de Vercel Requerida · EcoResiduos</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 2rem; display: flex; justify-content: center; align-items: center; min-height: 90vh; }
    .card { background: #1e293b; border: 1px solid #334155; border-radius: 16px; padding: 2.5rem; max-width: 620px; box-shadow: 0 20px 40px rgba(0,0,0,0.5); }
    h1 { color: #34d399; font-size: 1.5rem; margin-top: 0; display: flex; align-items: center; gap: 0.5rem; }
    p { color: #cbd5e1; line-height: 1.6; font-size: 0.95rem; }
    ul { background: #0f172a; border: 1px solid #334155; border-radius: 10px; padding: 1rem 1.5rem; margin: 1.5rem 0; }
    li { color: #fcd34d; font-family: ui-monospace, monospace; font-size: 0.9rem; margin: 0.5rem 0; }
    .footer { font-size: 0.85rem; color: #94a3b8; margin-top: 1.5rem; border-top: 1px solid #334155; pt: 1rem; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🌱 EcoResiduos · Falta Configuración</h1>
    <p>El panel administrativo arrancó en Vercel, pero necesita las variables de conexión a Supabase. Agrégalas en <strong>Vercel &gt; Settings &gt; Environment Variables</strong>:</p>
    <ul>
      ${faltan.map((f) => `<li>${f}</li>`).join('')}
    </ul>
    <p>Una vez agregadas, realiza un <strong>Redeploy</strong> en Vercel para que tomen efecto.</p>
    <div class="footer">EcoResiduos · Sistema de Gestión y Auditoría Ambiental</div>
  </div>
</body>
</html>`);
    };
} else {
    try {
        const crearApp = require('../src/crearApp');
        handler = crearApp();
    } catch (err) {
        console.error('Error al inicializar crearApp:', err);
        handler = (req, res) => {
            res.statusCode = 500;
            res.setHeader('Content-Type', 'text/plain; charset=utf-8');
            res.end(`Error al inicializar el servidor: ${err.message}\n${err.stack}`);
        };
    }
}

module.exports = (req, res) => {
    // Vercel reescribe todas las rutas hacia la función serverless (/api o /api/index.js).
    // La URL real pedida por el navegador viene en x-forwarded-url o x-matched-path.
    // Restauramos req.url y req.originalUrl para que Express sirva los archivos estáticos y reconozca las rutas (/login, /dashboard, etc.).
    const urlOriginal = req.headers['x-forwarded-url'] ||
                        req.headers['x-original-url'] ||
                        req.headers['x-rewrite-url'] ||
                        req.headers['x-matched-path'];

    if (urlOriginal && !urlOriginal.startsWith('/api/index')) {
        req.url = urlOriginal;
        req.originalUrl = urlOriginal;
    }

    return handler(req, res);
};
