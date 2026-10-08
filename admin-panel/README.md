# EcoResiduos — Panel Administrativo y de Auditoría Ambiental

<div align="center">

![Node.js](https://img.shields.io/badge/Node.js-18.x+-339933?style=for-the-badge&logo=node.js&logoColor=white)
![Express](https://img.shields.io/badge/Express-4.x-000000?style=for-the-badge&logo=express&logoColor=white)
![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-3.x-38B2AC?style=for-the-badge&logo=tailwind-css&logoColor=white)
![EJS](https://img.shields.io/badge/Templates-EJS-B4CA65?style=for-the-badge)
![WCAG](https://img.shields.io/badge/Accessibility-WCAG_2.1_AA-blue?style=for-the-badge)
![Tests](https://img.shields.io/badge/Tests-99_Passed-brightgreen?style=for-the-badge)

**Sistema web de fiscalización documental, trazabilidad regional y mediación para autoridades ambientales y administradores**

*Jurisdicción: 6 Municipios de Santander (AMB / CDMB / CAS)*

</div>

---

## 1. Descripción del Subsistema

El **Panel Administrativo** de EcoResiduos es una plataforma web desarrollada en **Node.js y Express**, diseñada para que las autoridades ambientales (**CDMB**, **AMB**, **CAS**) y los administradores del sistema auditen la operación de recolección en los seis (6) municipios priorizados de Santander: **Bucaramanga, Floridablanca, Girón, Piedecuesta, Barrancabermeja y Sabana de Torres**.

### Funcionalidades Principales
- **Auditoría Documental de Gestores:** Revisión de licencias ambientales en PDF, validación de NIT, verificación de materiales autorizados por empresa y registro inmutable de decisiones administrativas (Aprobado, Rechazado, Suspendido).
- **Catálogo de Materiales y Peligrosidad:** Administración de la matriz de residuos bajo la **Resolución 2184 de 2019**, definiendo códigos de color oficiales, peligrosidad (RESPEL) y directrices técnicas de manejo.
- **Trazabilidad y Mediación de Novedades:** Panel de mediación de incidentes reportados por generadores o gestores durante la recolección física.
- **Consolidación Estadística y Reportes:** Generación de métricas de recolección por municipio y descarga del reporte en Excel (.xlsx), con los filtros aplicados, las notas para leer las cifras y solo datos agregados.

---

## 2. Arquitectura de Software y Pipeline de Mediación

El panel web implementa el patrón de diseño **Model-View-Controller (MVC)** con renderizado en el servidor (*Server-Side Rendering - SSR*) a través de EJS y una **tubería de seguridad en capas (*Middleware Pipeline*)**:

```mermaid
flowchart TD
    REQ["Petición HTTP Entrante<br/>(Browser del Auditor)"] --> SEC_HEADERS["1. Cabeceras de Seguridad Perimetral<br/>(CSP L3 + Nonce Criptográfico + HSTS)"]
    SEC_HEADERS --> RATE_LIMIT["2. Rate Limiting por IP<br/>(Mitigación de Fuerza Bruta)"]
    RATE_LIMIT --> AUTH_MID["3. Middleware de Sesión y Autenticación<br/>(JWT en Cookies HttpOnly / SameSite=Strict)"]
    AUTH_MID --> CSRF_MID["4. Validación Anti-CSRF<br/>(Tokens firmados en Peticiones POST)"]
    CSRF_MID --> CONTROLLER["5. Capa de Controladores (MVC)<br/>(Solicitudes, Gestores, Materiales, Reportes)"]
    
    CONTROLLER --> SERVICE["6. Capa de Servicios y Adaptadores<br/>(Geocodificación, Reporte Excel, Supabase Client)"]
    SERVICE --> DB[(PostgreSQL 15+ / Supabase<br/>Operaciones con service_role)]
    
    CONTROLLER --> EJS_VIEW["7. Renderizado EJS con Sanitización XSS<br/>(HTML Semántico + WCAG 2.1 AA)"]
    EJS_VIEW --> RESP["Respuesta HTTP Segura<br/>(Renderizado en Servidor)"]
```

### Desglose de Capas Arquitectónicas

| Capa del Panel | Componentes Principales | Responsabilidad de Ingeniería |
|---|---|---|
| **Seguridad Perimetral** | `src/middlewares/` | Generación de nonces dinámicos para CSP L3, validación de firmas CSRF y control estricto de sesiones. |
| **Enrutamiento y Control** | `src/routes/`, `src/controllers/` | Mapeo RESTful de endpoints, validación de parámetros de entrada y mediación de transacciones administrativas. |
| **Servicios e Integración** | `src/services/`, `src/config/` | Clientes de persistencia Supabase (`service_role`), geocodificación de coordenadas y cálculo de métricas regionales. |
| **Presentación Accesible** | `src/views/`, `src/views/partials/` | Renderizado accesible conforme a WCAG 2.1 AA, navegación por teclado y contraste de color calibrado. |

---

### Estructura de Directorios del Código Fuente

```
admin-panel/
├── src/
│   ├── config/                   # Configuración del cliente Supabase (service_role) y entorno
│   ├── controllers/              # Controladores de solicitudes, gestores, materiales y reportes
│   ├── middlewares/              # Cadena de seguridad (Auth, CSRF, Nonces CSP, Rate Limit)
│   ├── routes/                   # Definición modular de rutas del servidor
│   ├── services/                 # Capa de integración con base de datos y geocodificación
│   ├── utils/                    # Generador del Excel, formateadores de fecha y helpers
│   ├── views/                    # Plantillas EJS estructuradas con protección contra XSS
│   ├── app.js                    # Configuración de Express, middlewares globales y rutas
│   └── server.js                 # Punto de entrada y arranque del servidor HTTP
│
├── pruebas/                      # Suite de 99 pruebas de integración, seguridad y WCAG
├── tailwind.config.js            # Configuración de diseño accesible conforme a WCAG 2.1 AA
└── package.json                  # Dependencias y scripts de construcción
```

---

El logo y la portada que cada gestor pone desde la app están en el bucket público `fotos_perfil` (migración `20261006000000_foto_perfil_y_portada.sql`). El panel los muestra en la lista, la ficha, el inicio y las solicitudes, y desde la ficha se pueden quitar si son inapropiados. Sin esa migración el panel funciona igual, con las iniciales de cada empresa. Las fotos de los ciudadanos no se muestran: el panel no las necesita para su trabajo (Ley 1581 de 2012, principios de finalidad y necesidad).

Los permisos ambientales se guardan en el bucket privado `permisos`, bajo la ruta `admin/<id>/<aleatorio>.pdf`. Solo se aceptan PDF reales de hasta 10 MB, y se abren con un enlace firmado que dura 10 minutos.

```
┌───────────────────────────────────────────────┬───────────────────────────────────────────────────────────────┐
│ Vector de Vulnerabilidad                      │ Mecanismo de Mitigación Implementado                          │
├───────────────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ Cross-Site Scripting (XSS)                    │ Content Security Policy (CSP) L3 con nonces criptográficos    │
│                                               │ únicos por petición. Sin directivas unsafe-inline.            │
├───────────────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ Cross-Site Request Forgery (CSRF)             │ Tokens anti-CSRF criptográficamente firmados y validados      │
│                                               │ en toda petición POST, almacenados en cookies HttpOnly.      │
├───────────────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ Inyección de Fórmulas en el Excel             │ Cada celda se escribe como valor, nunca como fórmula: un      │
│                                               │ texto que empiece con =, +, - o @ no se ejecuta al abrirlo.   │
├───────────────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ Ataques de Fuerza Bruta en Autenticación      │ Middleware de limitación de tasa (Rate Limiting) por IP       │
│                                               │ y bloqueo temporal tras 5 intentos consecutivos fallidos.     │
├───────────────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ Clickjacking y Sniffing de Tipos MIME         │ Cabeceras X-Frame-Options: DENY, X-Content-Type-Options:      │
│                                               │ nosniff y Strict-Transport-Security (HSTS en producción).     │
└───────────────────────────────────────────────┴───────────────────────────────────────────────────────────────┘
```

1. Instala con `npm ci --omit=dev`. Chart.js, Driver.js y supabase-js se sirven desde `node_modules`, así que no van a un CDN.
2. Define `NODE_ENV=production`, `SECRETO_PANEL` y, si hay un proxy delante, `TRUST_PROXY`. Al arrancar, el panel avisa si falta alguna de las dos últimas.
3. Publica el panel solo por HTTPS. En producción, las cookies son `Secure` y se envía HSTS.
4. Arranca con `npm start`.

## 4. Instalación y Despliegue Local

### Prerrequisitos
- [Node.js](https://nodejs.org/) versión 18.x o superior.
- Gestor de paquetes `npm`.

### Configuración del Entorno

1. Navegar al directorio del panel:
   ```bash
   cd admin-panel
   ```

2. Crear el archivo de configuración `.env` a partir de la plantilla:
   ```bash
   cp .env.example .env
   ```

3. Configurar las variables requeridas:
   ```env
   PORT=3000
   NODE_ENV=development
   SUPABASE_URL=https://<tu-proyecto>.supabase.co
   SUPABASE_ANON_KEY=<tu_anon_key>
   SUPABASE_SERVICE_ROLE_KEY=<tu_service_role_key>
   COOKIE_SECRET=<clave_aleatoria_para_firmado_de_cookies>
   ```

4. Instalar dependencias del proyecto:
   ```bash
   npm install
   ```

5. Compilar los estilos de Tailwind CSS:
   ```bash
   npm run build:css
   ```

```bash
npm test             # 120 pruebas, unos segundos
npm run lint
npm run test:e2e     # recorridos en navegador
```

---

## 5. Suite de Pruebas Automatizadas (99 Tests)

`npm run test:e2e` levanta el panel con datos simulados en el puerto 3998. Allí inicia sesión, recorre y salta el recorrido guiado del inicio, aprueba un gestor, quita su logo, comprueba el esqueleto de carga y amplía la foto de una solicitud, en escritorio y en celular. Si aparece cualquier error en la consola del navegador, la prueba falla. La primera vez hay que descargar el navegador:

```bash
npm test
```

## Al hacer cambios

- **Íconos.** La fuente de Material Symbols se pide solo con los íconos de la lista en [`src/utils/iconos.js`](src/utils/iconos.js). Si usas uno nuevo, agrégalo ahí en orden alfabético; `npm test` avisa si falta alguno.
- **Colores, radios y tamaños.** Salen de los tokens (`--md-sys-color-*`, `--eco-*`) definidos en `input.css`. Tailwind no genera la paleta por defecto, así que una clase como `bg-white` no existe.
- **Esqueletos de carga.** Cada pantalla tiene el suyo en [`partials/componentes/esqueletos.ejs`](src/views/partials/componentes/esqueletos.ejs), con su título, sus filtros y sus columnas reales; `main.js` elige cuál mostrar según la ruta. Si cambias una pantalla, cambia su esqueleto: [`pruebas/esqueletos.test.js`](pruebas/esqueletos.test.js) compara ambos.
- **Recorrido guiado.** Los pasos de cada pantalla, su texto y su versión están en [`src/utils/recorridos.js`](src/utils/recorridos.js); cada paso apunta a un atributo `data-recorrido` de la vista. Para mostrar pasos nuevos a quien ya vio el recorrido, sube `version` y marca esos pasos con `desde` igual a la versión nueva: solo verán lo nuevo. Lo visto se guarda en la cuenta (`user_metadata.recorrido_panel_<pantalla>` de Supabase Auth) y el botón de ayuda del encabezado lo repite. `npm test` revisa el largo de los textos y que cada paso apunte a algo que exista en la página.
- **Textos de la interfaz.** Se escriben en español de Colombia, sin tecnicismos.
