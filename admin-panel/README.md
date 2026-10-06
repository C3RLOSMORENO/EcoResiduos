# Panel de administración de EcoResiduos

Desde este panel, el equipo de EcoResiduos revisa y aprueba gestores, sigue las solicitudes de recolección, atiende los problemas que reportan los generadores y descarga el reporte de reciclaje por municipio. También administra el catálogo de materiales y el directorio de autoridades ambientales.

Está hecho con Node.js, Express y vistas EJS. Los estilos usan Tailwind con los tokens de Material Design 3, y los datos vienen del mismo proyecto de Supabase que usa la app. Las páginas se arman en el servidor y todo funciona sin JavaScript. `main.js` solo agrega mejoras, como el visor de fotos, los diálogos de confirmación y la carga de permisos.

## Requisitos

- Node.js 20.3 o superior. El panel usa `AbortSignal.any` para cortar las consultas que tardan demasiado.
- El proyecto de Supabase con todas las migraciones de [`supabase/migrations/`](../supabase/migrations) aplicadas (ver [Migraciones que usa el panel](#migraciones-que-usa-el-panel)).
- Una cuenta de administrador: un usuario de Supabase Auth cuya fila en la tabla `usuarios` tenga `rol = 'ADMIN'`. Las cuentas de la app (generadores y gestores) no pueden entrar.

## Instalación

```bash
cd admin-panel
npm install
cp .env.example .env      # y llena los valores
npm run build:css
npm run dev               # http://localhost:3000
```

Si falta una variable obligatoria, el panel no arranca y dice cuál es y para qué sirve.

## Variables de entorno

Se leen de `admin-panel/.env`. El archivo [`.env.example`](.env.example) tiene la plantilla.

| Variable | Obligatoria | Para qué sirve |
|---|---|---|
| `SUPABASE_URL` | Sí | Dirección del proyecto (`https://<proyecto>.supabase.co`). También se agrega a la CSP para las fotos. |
| `SUPABASE_ANON_KEY` | Sí | Llave pública. Solo la usa la página de restablecer contraseña, en el navegador. |
| `SUPABASE_SERVICE_ROLE_KEY` | Sí | Llave `service_role`. Se usa únicamente en el servidor y **nunca** se envía al navegador. |
| `PORT` | No | Puerto del servidor. Por defecto, 3000. |
| `NODE_ENV` | En producción | Con `production` se activan HSTS, las cookies `Secure` y el prefijo `__Host-` del token CSRF. |
| `SECRETO_PANEL` | En producción | Firma los avisos que viajan en la URL (`?msg=`). Si se deja vacía, se genera uno al azar en cada reinicio. Para crear uno: `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"` |
| `TRUST_PROXY` | Detrás de un proxy | Número de proxies delante del panel (por ejemplo, `1` en Render, Railway o detrás de Nginx). Sin este valor, el límite de intentos de inicio de sesión ve a todos con la misma IP. |

## Scripts

| Comando | Qué hace |
|---|---|
| `npm start` | Arranca el panel (`node server.js`). Es el comando de producción. |
| `npm run dev` | Arranca con `nodemon` y reinicia el servidor al guardar cambios. |
| `npm run dev:css` | Recompila `style.css` cada vez que cambian las vistas o `input.css`. |
| `npm run build:css` | Compila y minifica `src/public/css/style.css`. |
| `npm test` | Ejecuta las pruebas automáticas (`node --test`). |
| `npm run test:e2e` | Ejecuta las pruebas de extremo a extremo en un navegador real (Playwright). |
| `npm run lint` | Revisa el código con ESLint. |

`style.css` está en el repositorio. Si cambias clases en las vistas o en `input.css`, corre `npm run build:css` y sube también el CSS compilado.

## Estructura

```
admin-panel/
├── server.js               revisa el entorno y arranca
├── src/
│   ├── crearApp.js         Express: seguridad, compresión, estáticos y rutas
│   ├── config/             entorno y cliente de Supabase (con tiempo límite)
│   ├── middlewares/        sesión, CSRF, cabeceras, validación de ids
│   ├── routes/             una ruta por módulo
│   ├── controllers/        leen la petición y eligen la vista
│   ├── services/           consultas a Supabase y reglas de negocio
│   ├── utils/              filtros, formato, fechas, CSV, íconos
│   ├── views/              EJS; componentes en partials/componentes/
│   └── public/             CSS, JS e imágenes
└── pruebas/                pruebas automáticas y de extremo a extremo
```

Los controladores no consultan Supabase directamente; para eso están los servicios. Una prueba de arquitectura revisa que se cumpla.

## Migraciones que usa el panel

Algunas acciones llaman funciones SQL que se ejecutan con `service_role`:

| Acción | Función | Migración |
|---|---|---|
| Cancelar una solicitud (y rechazar sus postulaciones abiertas) | `cancelar_solicitud_admin` | `20261003000000_cancelar_solicitud_admin.sql` |
| Aprobar, rechazar o suspender un gestor con motivo y aviso | `cambiar_verificacion_gestor_admin` | `20261003000100_motivo_verificacion_y_avisos_gestor.sql` |
| Resolver un problema reportado como «no se recogió» | `resolver_problema_no_recogido` | `20261003000200_resolucion_problemas_reportados.sql` |

Si alguna falta, el panel no falla: explica en pantalla qué migración hay que aplicar. Al cambiar el estado de un gestor sin la segunda migración, el estado se guarda, pero el motivo no, y se avisa.

El logo y la portada que cada gestor pone desde la app están en el bucket público `fotos_perfil` (migración `20261006000000_foto_perfil_y_portada.sql`). El panel los muestra en la lista, la ficha, el inicio y las solicitudes, y desde la ficha se pueden quitar si son inapropiados. Sin esa migración el panel funciona igual, con las iniciales de cada empresa. Las fotos de los ciudadanos no se muestran: el panel no las necesita para su trabajo (Ley 1581 de 2012, principios de finalidad y necesidad).

Los permisos ambientales se guardan en el bucket privado `permisos`, bajo la ruta `admin/<id>/<aleatorio>.pdf`. Solo se aceptan PDF reales de hasta 10 MB, y se abren con un enlace firmado que dura 10 minutos.

## Despliegue

1. Instala con `npm ci --omit=dev`. Chart.js, Driver.js y supabase-js se sirven desde `node_modules`, así que no van a un CDN.
2. Define `NODE_ENV=production`, `SECRETO_PANEL` y, si hay un proxy delante, `TRUST_PROXY`. Al arrancar, el panel avisa si falta alguna de las dos últimas.
3. Publica el panel solo por HTTPS. En producción, las cookies son `Secure` y se envía HSTS.
4. Arranca con `npm start`.

Ten en cuenta:

- **Límite de intentos del inicio de sesión:** vive en memoria. Funciona bien con una instancia; con varias, cada una lleva su propia cuenta.
- **Archivos estáticos:** CSS, JS e imágenes se piden con `?v=<huella>` y se guardan en caché un año. Cada despliegue cambia la huella de lo que cambió, así que no hace falta vaciar cachés.
- **Compresión:** las respuestas viajan con Brotli o gzip.
- **Tiempo límite:** si Supabase no responde en 10 s (60 s para subir un PDF), la página muestra el error con «Reintentar» en lugar de quedarse cargando. Si Supabase Auth se cae, la sesión no se cierra; se muestra «El servicio no respondió» (código 503).

## Seguridad

Cabeceras que lleva cada respuesta:

| Cabecera | Valor |
|---|---|
| `Content-Security-Policy` | `default-src 'self'`; `script-src 'self' 'nonce-…'` (un nonce nuevo por respuesta); `style-src 'self' https://fonts.googleapis.com`; `font-src https://fonts.gstatic.com`; `img-src 'self' data: <Supabase>`; `connect-src 'self' <Supabase>`; `object-src 'none'`; `base-uri 'self'`; `form-action 'self'`; `frame-ancestors 'none'`; en producción, `upgrade-insecure-requests` |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` (solo en producción) |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Referrer-Policy` | `same-origin` |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=(), payment=(), usb=()` |
| `Cross-Origin-Opener-Policy` | `same-origin` |
| `Cross-Origin-Resource-Policy` | `same-origin` |

Además:

- **Sin código en línea.** Ninguna vista tiene JavaScript ni estilos escritos dentro del HTML (`onclick`, `style="…"`). Lo que necesita script está en `main.js`.
- **CSRF.** Cada formulario POST lleva un token que debe coincidir con la cookie `csrf` (`__Host-csrf` en producción, `httpOnly`, `SameSite=Strict`). Además, se rechaza todo POST que venga de otro sitio según `Origin` o `Sec-Fetch-Site`.
- **Sesión.** Las cookies `sb_access_token` y `sb_refresh_token` son `httpOnly` y `SameSite=Lax`, y vencen tras 15 minutos sin actividad. Cerrar sesión solo funciona por POST.
- **Inicio de sesión.** Se permiten 5 intentos fallidos por correo y 20 por IP cada 15 minutos. Si una cuenta de la app usa la contraseña correcta, recibe el mismo mensaje que con una contraseña errada.
- **Avisos.** Los mensajes de la URL van firmados con HMAC. Un `?msg=` escrito a mano no aparece en pantalla.
- **Identificadores.** Un id que no sea un entero positivo responde 404 sin consultar la base.
- **Errores.** El texto de PostgreSQL nunca llega a la pantalla. Solo se muestran los mensajes propios de las funciones del panel.
- **CSV del reporte.** Va protegido contra inyección de fórmulas y solo trae cifras agregadas, sin datos personales.

## Pruebas

```bash
npm test             # 120 pruebas, unos segundos
npm run lint
npm run test:e2e     # recorridos en navegador
```

`npm test` usa un Supabase simulado ([`pruebas/apoyo/`](pruebas/apoyo)) y nunca toca la base real. Cubre:

- **Rutas del inventario.** [`pruebas/inventario.test.js`](pruebas/inventario.test.js) compara la lista con las rutas del código y revisa cada una sin sesión, sin token CSRF y con sesión. También prueba crear, editar y eliminar por todos los alias, y las validaciones de cada formulario.
- **Seguridad.** Cabeceras, CSRF, límite de intentos, avisos firmados, ids inválidos y errores de la base ([`seguridad.test.js`](pruebas/seguridad.test.js)).
- **Reglas de negocio.** Aprobar, rechazar y suspender gestores, verificar materiales, cancelar solicitudes y no eliminar registros con historia ([`reglas.test.js`](pruebas/reglas.test.js)).
- **Accesibilidad, diseño, rendimiento y arquitectura.** Están en sus archivos con el mismo nombre.

`npm run test:e2e` levanta el panel con datos simulados en el puerto 3998. Allí inicia sesión, recorre y salta el recorrido guiado del inicio, aprueba un gestor, quita su logo, comprueba el esqueleto de carga y amplía la foto de una solicitud, en escritorio y en celular. Si aparece cualquier error en la consola del navegador, la prueba falla. La primera vez hay que descargar el navegador:

```bash
npx playwright install chromium
# o, para usar el Chrome ya instalado:
E2E_CANAL=chrome npm run test:e2e
```

## Al hacer cambios

- **Íconos.** La fuente de Material Symbols se pide solo con los íconos de la lista en [`src/utils/iconos.js`](src/utils/iconos.js). Si usas uno nuevo, agrégalo ahí en orden alfabético; `npm test` avisa si falta alguno.
- **Colores, radios y tamaños.** Salen de los tokens (`--md-sys-color-*`, `--eco-*`) definidos en `input.css`. Tailwind no genera la paleta por defecto, así que una clase como `bg-white` no existe.
- **Esqueletos de carga.** Cada pantalla tiene el suyo en [`partials/componentes/esqueletos.ejs`](src/views/partials/componentes/esqueletos.ejs), con su título, sus filtros y sus columnas reales; `main.js` elige cuál mostrar según la ruta. Si cambias una pantalla, cambia su esqueleto: [`pruebas/esqueletos.test.js`](pruebas/esqueletos.test.js) compara ambos.
- **Recorrido guiado.** Los pasos de cada pantalla, su texto y su versión están en [`src/utils/recorridos.js`](src/utils/recorridos.js); cada paso apunta a un atributo `data-recorrido` de la vista. Para mostrar pasos nuevos a quien ya vio el recorrido, sube `version` y marca esos pasos con `desde` igual a la versión nueva: solo verán lo nuevo. Lo visto se guarda en la cuenta (`user_metadata.recorrido_panel_<pantalla>` de Supabase Auth) y el botón de ayuda del encabezado lo repite. `npm test` revisa el largo de los textos y que cada paso apunte a algo que exista en la página.
- **Textos de la interfaz.** Se escriben en español de Colombia, sin tecnicismos.
