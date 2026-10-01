# PROMPT PARA REDISEÑAR EL PANEL DE ADMINISTRACIÓN — EcoResiduos

Copia todo lo que está debajo de la línea y pégalo en el agente de código (Claude Code, Antigravity u otro) **abierto en la carpeta del repositorio**, porque tiene que leer y modificar archivos. Trabaja en una rama nueva (por ejemplo `feature/panel-sistema-diseno`), nunca sobre `main`.

---

## 0. TU ROL Y EL OBJETIVO

Actúa como ingeniero frontend senior con experiencia en sistemas de diseño y accesibilidad web. Vas a rediseñar el **panel de administración** de EcoResiduos (`admin-panel/`, Node + Express + EJS) para que use **el mismo sistema de diseño que la app móvil**, con buenas prácticas y accesibilidad como requisito, no como extra.

**Regla de oro:** es un cambio de **sistema de diseño y organización**, no una reescritura. **Ninguna función actual se puede perder.** La sección 4 es el inventario completo: al terminar, cada línea debe seguir funcionando y debes entregarla marcada como verificada.

**Antes de escribir código:** lee los archivos que se citan en este documento, compáralos con lo que dice aquí y, si algo no coincide (una ruta, una columna, un campo), **detente y pregunta**. No inventes columnas ni tablas de la base de datos.

## 1. QUÉ ES EL PRODUCTO Y QUIÉN USA EL PANEL

EcoResiduos conecta a **generadores** (hogares y negocios que tienen un residuo) con **gestores** (empresas autorizadas que lo recolectan) en Bucaramanga, Floridablanca, Girón, Piedecuesta, Barrancabermeja y Sabana de Torres (Santander, Colombia).

Flujo de una solicitud (la app lo hace con funciones del servidor):
`PUBLICADO` → el gestor se postula con un valor (**valor cobrado por recolección externa** o **valor pagado por aprovechamiento**) → el generador acepta → `EN_NEGOCIACION` → el gestor marca `RECOLECTADO` → el generador confirma o reporta un problema (si no responde en 72 h se confirma solo) → el gestor carga el **certificado de disposición final o de aprovechamiento** en PDF.

Los gestores nuevos se registran desde la app con su **licencia o permiso ambiental en PDF** y quedan `PENDIENTE` hasta que el administrador los revisa.

**Usuario del panel:** personal administrativo de EcoResiduos, en computador (también debe funcionar en tablet y celular). Sus tareas, en orden de frecuencia:
1. Revisar y aprobar o rechazar gestores nuevos (ver el permiso, verificar materiales).
2. Atender problemas reportados en recolecciones.
3. Consultar solicitudes, su estado, postulaciones, valores y certificados.
4. Ver cuánto se recicla por municipio (reportes para la directora y las autoridades).
5. Mantener catálogos: materiales, autoridades ambientales, gestores.

Idioma: **español de Colombia**, claro y directo, sin tecnicismos. **Nunca uses la palabra "padrón"**: en este proyecto no se usa. Di "gestores registrados" o "no encontramos la empresa".

## 2. SISTEMA DE DISEÑO: MATERIAL DESIGN 3 (EL MISMO DE LA APP)

### 2.1 Por qué este y no otro

- La app móvil está construida con **Material Design 3** (Flutter). Usar M3 en el panel da una sola identidad y un solo vocabulario (roles de color, escala tipográfica, formas, estados) entre los dos productos.
- M3 tiene documentación oficial completa, incluida accesibilidad: https://m3.material.io (fundamentos de accesibilidad: https://m3.material.io/foundations/designing/overview).
- **No uses la librería `@material/web`**: su repositorio oficial dice textualmente "MWC is in maintenance mode pending new maintainers" (https://github.com/material-components/material-web). Implementa M3 con **tokens CSS + Tailwind compilado + HTML semántico**.
- M3 no especifica tablas de datos. Para tablas usa los tokens de M3 y el patrón accesible oficial de W3C: https://www.w3.org/WAI/ARIA/apg/patterns/table/.

### 2.2 Tokens: la fuente de verdad es la app

Lee `app/lib/theme/eco_colors.dart` y `app/lib/theme/eco_theme.dart` y conviértelos en variables CSS (claro y oscuro) en `admin-panel/src/public/css/input.css`, con la nomenclatura oficial de M3:

```css
:root {
  --md-sys-color-primary: #1F4A2C;          /* ecoLightColorScheme.primary */
  --md-sys-color-on-primary: #FFFFFF;
  --md-sys-color-surface: #F8F6EE;
  /* …todos los roles de ecoLightColorScheme, sin omitir ninguno… */
}
/* Modo oscuro: ecoDarkColorScheme (primary #9DD3A5, surface #121410, …) */
```

- **Todos los roles** de `ecoLightColorScheme` y `ecoDarkColorScheme`: primary, secondary, tertiary, error con sus `on*` y `*Container`, surface, `surfaceContainerLowest…Highest`, outline, outlineVariant, inverse*. Copia los valores exactos del archivo; no los inventes ni los "mejores".
- **Colores de categoría y de estado** (`ecoColoresLight` y `ecoColoresDark` en el mismo archivo): crea `--eco-cat-<categoria>` y `--eco-estado-<estado>` con `color`, `on`, `container` y `on-container`. Ejemplos del modo claro: Aprovechable `#0A5F7A`, Peligroso `#F2B200`, RAEE `#5B3FA0`, Escombros (RCD) `#6D5A4B`, Riesgo biológico `#B3261E`. Así un chip de "RAEE" se ve igual en la app y en el panel. Elimina la función `getBadgeClasses`/`obtenerClaseResiduo` que adivina colores por el prefijo del código (`Y1`, `Y8`…) y usa la categoría real del material.
- **Tipografía (la misma de la app):** **Barlow Condensed** para títulos y cifras grandes, **Public Sans** para todo lo demás, desde Google Fonts. Escala tipográfica M3 (display, headline, title, body, label) con los tamaños de `eco_theme.dart`. Usa cifras tabulares (`font-variant-numeric: tabular-nums`) en tablas, KPIs y valores en pesos.
- **Formas:** usa solo el subconjunto de la escala M3 que usa la app (revisa `EcoRadius` en `eco_theme.dart`).
- **Elevación:** la jerarquía sale de los tonos `surfaceContainer*`, no de sombras.
- **Íconos:** Material Symbols Outlined (ya está cargado). Un solo estilo y peso en todo el panel.
- **Estados de interacción M3:** hover, focus y pressed con la capa de estado oficial (opacidades 8 %, 10 % y 10 %). El foco siempre visible.
- Modo claro y oscuro: respeta `prefers-color-scheme` y conserva el interruptor manual que ya existe.

### 2.3 Base técnica que hay que corregir primero

1. **Quita `<script src="https://cdn.tailwindcss.com">`** de `src/views/partials/header.ejs`. La documentación oficial de Tailwind dice: "The Play CDN is designed for development purposes only, and is not intended for production" (https://tailwindcss.com/docs/installation/play-cdn).
2. **Repara la compilación de CSS:** `package.json` pide Tailwind 3 (`^3.4.19`), pero en `node_modules` quedó instalada otra versión, y `npm run build:css` falla con "Cannot apply unknown utility class". Alinea la versión con `npm install` según `package.json`, configura en `tailwind.config.js` los colores desde las variables CSS (`primary: 'var(--md-sys-color-primary)'`, etc.) y deja `style.css` compilado y minificado.
3. **Fija las versiones de las dependencias por CDN** (hoy Chart.js se carga sin versión: `cdn.jsdelivr.net/npm/chart.js`).
4. Corrige el texto con codificación dañada ("EstadÃ­sticas", "APROBACIÃ“N"…) en `DashboardService.js` y en las vistas. Todos los archivos en UTF-8.

## 3. ACCESIBILIDAD (OBLIGATORIA: WCAG 2.2 NIVEL AA)

Referencia oficial: https://www.w3.org/TR/WCAG22/. Cada pantalla debe cumplir:

- **Estructura:** `<html lang="es-CO">`; regiones `header`, `nav`, `main` y `footer`; un solo `<h1>` por página y títulos en orden; enlace "Saltar al contenido" como primer elemento enfocable; `<title>` distinto por página ("Gestores · Panel EcoResiduos").
- **Contraste:** 4.5:1 para texto normal y 3:1 para texto grande, íconos y bordes de campos. Compruébalo con los tokens en claro y en oscuro.
- **Teclado:** todo se usa sin mouse, en orden lógico, sin trampas de foco. El foco se ve siempre (anillo de 2 px con `--md-sys-color-primary` más separación).
- **Modales:** usa `<dialog>` nativo con `showModal()`: el foco entra al diálogo, Esc lo cierra y al cerrar el foco vuelve al botón que lo abrió. **Reemplaza todos los `confirm()` del navegador** por un diálogo propio que diga qué va a pasar ("Aprobar a RECICLAJES DEL ORIENTE S.A.S. Podrá ver solicitudes de sus 4 materiales.").
- **Formularios:** cada campo con `<label>` visible; obligatorios marcados en texto ("obligatorio"), no solo con `*`; errores junto al campo con `aria-describedby` y `aria-invalid`; al enviar con errores, el foco va al primer campo con error; `autocomplete` donde aplique.
- **Tablas:** `<table>` real con `<caption>`, `<th scope="col">` y `scope="row"`; orden de columnas anunciado con `aria-sort`; en pantallas pequeñas, desplazamiento horizontal dentro de un contenedor con nombre accesible, o vista en tarjetas. Nunca tablas hechas con `div`.
- **Estados sin depender del color:** cada badge de estado o categoría lleva texto o ícono además del color.
- **Mensajes:** los avisos de éxito o error (el `alert.ejs` actual y el snackbar de `main.js`) en una región `role="status"` o `role="alert"` según su gravedad, para que el lector de pantalla los anuncie.
- **Gráficos:** cada gráfico de Chart.js con descripción textual y la **tabla con los mismos datos** al lado o detrás de un botón "Ver como tabla". Paleta de los tokens, nunca solo color para distinguir series.
- **Tamaño de los objetivos:** mínimo 24×24 px (criterio 2.5.8); en acciones principales, 44×44 px.
- **Zoom y reflujo:** usable al 200 % de zoom y a 320 px de ancho sin scroll horizontal de página.
- **Movimiento:** respeta `prefers-reduced-motion`.
- **Verificación:** pasa **axe DevTools** sin errores y **Lighthouse Accesibilidad ≥ 95** en cada página, y haz un recorrido completo solo con teclado. Entrega el resultado.

## 4. INVENTARIO DE FUNCIONES (NO SE PUEDE PERDER NINGUNA)

Lee `src/routes/*.js`, `src/controllers/*.js`, `src/services/*.js` y `src/views/*.ejs`. **Mantén todas las rutas existentes**, incluidos los alias duplicados (`/edit/:id` y `/editar/:id`, `/delete/:id` y `/eliminar/:id`, `POST /` y `/guardar`, `/estado/:id` y `/:id/estado`), aunque la interfaz use solo una forma.

| Módulo | Funciones actuales |
|---|---|
| **Acceso** | Iniciar sesión (`/login`, `/auth/login`); cerrar sesión (`/logout` GET y POST); restablecer contraseña (`/restablecer-password`); protección `requireAuth` en todo lo demás |
| **Dashboard** (`/dashboard`) | KPIs de solicitudes (total, publicadas, en negociación, recolectadas, canceladas), gestores (total, pendientes, aprobados, rechazados), materiales, autoridades y postulaciones; gráfico de estados (dona); gráfico por municipio (barras); tabla de gestores pendientes con aprobar y rechazar; últimas 8 solicitudes |
| **Gestores** (`/gestores`) | Listado con búsqueda (razón social, NIT, material) y filtro por municipio; ficha de detalle (contacto, dirección con enlace a Google Maps, materiales); crear gestor (NIT, razón social, municipio, dirección, representante, teléfono, correo, materiales) con geocodificación; editar (lo anterior más horario, estado de verificación, disponible y materiales, con búsqueda, "Todos" y "Ninguno"); eliminar; cambiar estado (PENDIENTE, APROBADO, RECHAZADO, SUSPENDIDO); **ver permiso ambiental** (`/gestores/:id/permiso`, enlace firmado de 10 minutos); aviso de materiales "por verificar"; al aprobar se verifican los materiales declarados y se ubica la dirección |
| **Materiales** (`/materiales`) | Listar, buscar, crear, editar y eliminar: código, nombre común, categoría, subcategoría, descripción, guía de manejo, advertencia de manejo |
| **Autoridades** (`/autoridades`) | Listar, crear, editar y eliminar: nombre, sigla, jurisdicción, dirección, teléfono, correo, sitio web, horario |
| **Solicitudes** (`/solicitudes`) | Listado (material, municipio, estado, fecha); ver certificado PDF o "Pendiente"; cambiar estado |
| **Ciudadanos** (`/ciudadanos`) | Listado de generadores (nombre, documento, contacto, municipio, fecha de registro) |
| **General** | Modo claro y oscuro; mensajes de éxito y error por `?msg=`, `?type=`, `?success=` y `?error=`; formateo de NIT y teléfono en campos con `data-format` (`main.js`) |

## 5. LIMPIEZA: QUÉ QUITAR O CAMBIAR Y POR QUÉ

Aplica estos cambios. Cada uno conserva la función útil y quita lo que confunde o es riesgoso:

1. **Solicitudes, cambio de estado libre:** el `<select>` ofrece `ASIGNADO`, un estado que no existe en la app, y deja poner cualquier estado saltándose las reglas (por ejemplo, `RECOLECTADO` sin fecha de recolección, que deja la solicitud inconsistente en la app). **Quita `ASIGNADO`** y cambia el selector por una acción explícita **"Cancelar solicitud"** (solo si está `PUBLICADO` o `EN_NEGOCIACION`, con diálogo de confirmación). Si el dueño del producto necesita otro cambio administrativo, **pregunta antes** en lugar de dejar el selector libre.
2. **Dashboard, aprobar o rechazar con un clic:** hoy se aprueba sin ver el permiso ni los materiales. Cámbialo por **"Revisar"**, que lleva a la revisión del gestor (permiso, datos y materiales) donde se aprueba o rechaza. La función de aprobar sigue existiendo; solo se hace con la información a la vista.
3. **Ficha en modal más página de edición duplicadas:** unifica en una **página de detalle del gestor** (`/gestores/:id`, ruta nueva de solo lectura) con secciones: datos, permiso, materiales (verificados y por verificar), estado y acciones (Editar, Aprobar, Rechazar, Suspender, Eliminar). Conserva `/gestores/edit/:id` para el formulario.
4. **Filtro de municipios escrito a mano** (le falta Sabana de Torres): usa la lista de la app, `app/lib/utils/municipios.dart` (6 municipios), en un solo módulo compartido del panel.
5. **KPIs de catálogo** (total de materiales y de autoridades) como protagonistas del dashboard: bájalos a una línea secundaria. Lo principal es lo que exige acción (sección 6.1).
6. **Valores por defecto engañosos en `GestorService.js`**: si falta `estado_verificacion` se muestra `APROBADO`, y si falta el municipio, `BUCARAMANGA`. Muestra "Sin dato" en lugar de inventar un valor.
7. **Clases duplicadas y estilos en línea:** extrae los patrones repetidos (botones, chips, campos, tarjetas, tablas, diálogos) a componentes, sea en parciales EJS (`partials/componentes/*.ejs`) o en clases `@layer components` de Tailwind. Nada de copiar 40 clases en cada botón.

## 6. CONTENIDO QUE FALTA (TODO LO DE LA APP DEBE VERSE EN EL PANEL)

Solo lectura con la llave `service_role` desde el servidor (servicios en `src/services/`). **No cambies la base de datos.** Si algo exige una columna o tabla nueva, entrégalo como archivo SQL en `supabase/migrations/` y explícalo; no lo ejecutes.

### 6.1 Dashboard: "Pendientes de acción" primero

Arriba, tarjetas con conteo y enlace directo a la lista filtrada:
- Gestores por revisar (`perfiles_gestor.estado_verificacion = 'PENDIENTE'`).
- Materiales por verificar (`gestor_material.verificado = false` de gestores aprobados).
- **Problemas reportados** sin resolver (`solicitudes_recoleccion.problema_reportado = true`). Hoy la app le dice al generador "lo estamos revisando" y **el panel no los muestra en ningún lado**: es la falta más grave.
- Recolecciones sin certificado (`estado = 'RECOLECTADO'` y `certificado_url` vacío) con más de 7 días.

Debajo, los KPIs y los gráficos actuales (con su tabla accesible) y las últimas solicitudes.

### 6.2 Reporte "Reciclaje por municipio" (página nueva `/reportes`, con resumen en el dashboard)

Tabla con una fila por cada uno de los 6 municipios, más una fila de total:

| Municipio | Recolecciones confirmadas | Aprovechable | Peligroso | RAEE | RCD | Riesgo biológico | Total (kg) |
|---|---|---|---|---|---|---|---|

Reglas de cálculo (son importantes, no las simplifiques):
- Cuenta solo solicitudes con `confirmado_at` no nulo (confirmadas por el generador o confirmadas solas a las 72 h). Excluye las que tienen `problema_reportado = true` y no están confirmadas.
- La cantidad es la que **estimó el generador** (`cantidad_estimada`); dilo en el `<caption>`: "Cantidades estimadas por los generadores".
- **No sumes unidades distintas.** Convierte solo `KG` y `TON` (1 t = 1000 kg) a kilogramos. Las demás unidades (`UNIDADES`, `LITROS`, `GALONES`, `CANECAS`, `M3`) van en una tabla aparte por unidad, o en una nota con su total por unidad. Nunca mezcles kilos con unidades en una misma cifra.
- Normaliza el municipio (mayúsculas, tildes, espacios) contra la lista de 6 municipios; lo que no coincida va en una fila "Otro / sin dato".
- Filtros: rango de fechas (por `confirmado_at`) y categoría. Botón **"Descargar CSV"** con los mismos datos filtrados (UTF-8 con BOM para que Excel muestre bien las tildes).
- Junto a la tabla, un gráfico de barras por municipio que **no reemplaza** la tabla.

### 6.3 Solicitudes: filtros y detalle

- Filtros por estado, municipio, categoría y rango de fechas, más búsqueda por material. Los filtros van en la URL (`?estado=…`) para que se puedan compartir y volver atrás.
- Página de detalle `/solicitudes/:id` con:
  - Datos del residuo: foto, material, categoría, cantidad, dirección y municipio.
  - Generador.
  - **Línea de tiempo** (`solicitudes_historial_estados`).
  - **Postulaciones** con gestor, estado, propuesta y **valor** (`tipo_valor` y `valor`, con las etiquetas "Valor cobrado por recolección externa" y "Valor pagado por aprovechamiento", en pesos con punto de miles: `$ 1.250.000`).
  - Gestor asignado.
  - **Certificado** (tipo, fecha y "Ver PDF").
  - **Problema reportado** (detalle).

### 6.4 Gestores

- Filtro por estado de verificación, además del de municipio.
- En la página de detalle (5.3), materiales agrupados por categoría con su chip de color y el estado "Verificado" o "Por verificar".
- Indicador "Registrado desde la app" mientras el gestor está `PENDIENTE` (hoy existe como "Registro nuevo · ver permiso"; desaparece cuando se aprueba).

### 6.5 Ciudadanos

- Búsqueda y filtro por municipio; número de publicaciones de cada generador con enlace a sus solicitudes filtradas.

## 7. ESTRUCTURA Y PANTALLAS

**Navegación (M3):**
- En escritorio, **navigation drawer** fijo.
- En tablet, **navigation rail**.
- En celular, drawer modal con botón de menú.
- Orden: **Inicio · Solicitudes · Gestores · Reportes · Ciudadanos · Materiales · Autoridades**.
- La página actual marcada con `aria-current="page"`.
- Arriba, a la derecha: modo claro/oscuro y cerrar sesión.

Para **cada pantalla** define y aplica:
- Propósito en una frase.
- **Una sola acción principal** (botón filled). Las demás, tonal, outlined o text, según su importancia.
- Orden del contenido: primero lo que exige acción y al final lo de consulta.
- Estado vacío con texto útil y acción ("Aún no hay gestores por revisar").
- Estado de error con salida ("No pudimos cargar las solicitudes. Reintentar").
- Feedback de carga en acciones que tardan, como la geocodificación al guardar un gestor (botón deshabilitado con "Guardando…").

Pantallas: Login, Restablecer contraseña, Inicio (dashboard), Solicitudes (lista y detalle), Gestores (lista, detalle, crear y editar), Reportes, Ciudadanos, Materiales (lista y editar), Autoridades (lista y editar) y Error 404.

Valores en pesos con `$` y punto de miles; fechas en formato `es-CO` ("12 sep 2026"); cantidades con su unidad ("120 kg"). Igual que en la app (`app/lib/utils/formato.dart`).

## 8. RESTRICCIONES

- Sigue con **Express + EJS renderizado en el servidor**, JavaScript sin framework y mejora progresiva (lo básico funciona aunque falle el JavaScript). Nada de React, Vue ni frameworks nuevos.
- **No toques `.env` ni las llaves.** La llave `service_role` solo se usa en el servidor; nunca llega al navegador.
- No modifiques la app Flutter ni `app/assets/models/`.
- Cambios de base de datos solo como archivo SQL nuevo en `supabase/migrations/`, sin ejecutarlo.
- Código limpio y en español, como el resto del proyecto. Comentarios solo donde expliquen el porqué, sin comentarios obvios ni de relleno.
- Commits pequeños por etapa con mensajes `tipo(alcance): descripción`. **No hagas push ni merge**: eso lo hace el dueño del repositorio.

## 9. ORDEN DE TRABAJO Y ENTREGABLES

1. **Plan:** lista de archivos que vas a crear y cambiar, y dudas encontradas al contrastar este documento con el código. Espera mi aprobación.
2. **Base:** tokens M3 en CSS (claro y oscuro), Tailwind compilado sin CDN de desarrollo, tipografías y layout con navegación accesible.
3. **Componentes:** botones, campos, chips de categoría y estado, tablas, diálogos, avisos, tarjetas de KPI y estados vacío y error. Una página `/componentes` (solo con sesión iniciada) que los muestre todos, en claro y oscuro.
4. **Pantallas existentes,** una por una, verificando su línea del inventario (sección 4).
5. **Contenido nuevo:** sección 6 (pendientes de acción, reportes, detalle de solicitud y de gestor, filtros).
6. **Entrega final:**
   - La tabla de la sección 4 con una columna "Verificado ✔" y cómo lo probaste.
   - Resultados de axe y Lighthouse por página.
   - Capturas en escritorio y celular, en claro y oscuro.
   - Lista de lo que quedó pendiente o necesita decisión.

## 10. CRITERIOS DE ACEPTACIÓN

- Las funciones del inventario siguen funcionando y todas las rutas responden.
- El panel y la app comparten colores (los mismos valores de `eco_colors.dart`), tipografías y colores por categoría.
- No queda `cdn.tailwindcss.com`; `npm run build:css` funciona.
- axe sin errores; Lighthouse Accesibilidad ≥ 95 en cada página; recorrido completo solo con teclado.
- Los problemas reportados, los valores de las postulaciones, los certificados y los permisos se ven en el panel.
- El reporte por municipio no mezcla unidades y se puede descargar en CSV.
- La palabra "padrón" no aparece en ninguna parte.
