# EcoResiduos ♻️

Plataforma integral para la clasificación, gestión y disposición adecuada de residuos sólidos y peligrosos en Colombia, conectando a ciudadanos y empresas con gestores ambientales autorizados y entidades reguladoras.

---

## 📌 Componentes del Proyecto

El repositorio está estructurado como un monorepo que contiene tanto la aplicación móvil para usuarios como el panel administrativo web:

```
EcoResiduos/
├── app/                  # 📱 Aplicación móvil (Flutter & Dart)
├── admin-panel/          # 💻 Panel de administración web (Node.js & Express)
└── README.md             # 📄 Documentación general del proyecto
```

---

## 🛠️ Stack Tecnológico

| Componente | Tecnologías |
|---|---|
| **App Móvil** | Flutter, Dart, Material Design 3, Camera, Geolocator |
| **Inteligencia Artificial** | Google Gemini Vision API (Clasificación de residuos) |
| **Panel Web** | Node.js, Express, EJS, Tailwind CSS |
| **Backend & Base de Datos** | Supabase (PostgreSQL, Auth, Storage, Row Level Security) |

---

## ✨ Características Principales

### 📱 Aplicación Móvil (`/app`)
- **Identificación con IA:** Análisis visual mediante cámara para clasificar residuos según la normativa colombiana (*Peligroso, Industrial, RAEE, Biosanitario, Reciclable, Orgánico, Ordinario*).
- **Guías de Manejo Ambiental:** Pasos recomendados de almacenamiento, transporte y disposición final.
- **Directorio de Gestores Autorizados:** Geolocalización y contacto de empresas certificadas cercanas.
- **Directorio de Autoridades Ambientales:** Contacto directo con entidades regulatorias (CAR, Secretarías de Ambiente, etc.).
- **Historial de Escaneos:** Registro personal con sincronización a la nube.

### 💻 Panel Administrativo (`/admin-panel`)
- **Gestión de Materiales y Residuos:** Catálogo de clasificación, peligrosidad y normativas aplicables.
- **Administración de Gestores Ambientales:** Registro y validación de empresas gestoras autorizadas y sus licencias.
- **Gestión de Autoridades:** Directorio de entidades de control territorial.
- **Seguridad y Control de Acceso:** Autenticación de administradores con Supabase Auth.

---

## 🚀 Puesta en Marcha

### Prerrequisitos
- [Git](https://git-scm.com/)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (para la app móvil)
- [Node.js](https://nodejs.org/) v18+ (para el panel administrativo)
- Proyecto en [Supabase](https://supabase.com/)

---

### 1. Clonar el Repositorio

```bash
git clone https://github.com/C3RLOSMORENO/EcoResiduos.git
cd EcoResiduos
```

---

### 2. Configuración de la App Móvil (`/app`)

1. Ingresa a la carpeta de la app:
   ```bash
   cd app
   ```
2. Crea el archivo de variables de entorno `.env` a partir de la plantilla:
   ```bash
   cp .env.example .env
   ```
3. Añade tu API key de Gemini en `.env`:
   ```env
   GEMINI_API_KEY=tu_gemini_api_key
   ```
4. Instala dependencias y corre la aplicación:
   ```bash
   flutter pub get
   flutter run
   ```

---

### 3. Configuración del Panel Administrativo (`/admin-panel`)

1. Ingresa a la carpeta del panel:
   ```bash
   cd ../admin-panel
   ```
2. Crea el archivo de variables de entorno `.env` a partir de la plantilla:
   ```bash
   cp .env.example .env
   ```
3. Configura tus claves de Supabase en `.env`:
   ```env
   PORT=3000
   SUPABASE_URL=https://tu-proyecto.supabase.co
   SUPABASE_ANON_KEY=tu_anon_key
   SUPABASE_SERVICE_ROLE_KEY=tu_service_role_key
   ```
4. Instala dependencias e inicia el servidor:
   ```bash
   npm install
   npm run dev
   ```
5. Abre en tu navegador: `http://localhost:3000`

---

## 🔒 Seguridad y Buenas Prácticas

- Los archivos `.env` con credenciales, tokens y llaves secretas están estrictamente excluidos del control de versiones mediante `.gitignore`.
- Se proporcionan archivos `.env.example` en cada módulo para guiar la configuración local.
- Las consultas a la base de datos están protegidas mediante políticas de seguridad a nivel de fila (RLS) en PostgreSQL.

---

## 👥 Equipo y Contribuciones

Desarrollado como proyecto de impacto ambiental y tecnológico.  
Repositorio oficial: [C3RLOSMORENO/EcoResiduos](https://github.com/C3RLOSMORENO/EcoResiduos)
