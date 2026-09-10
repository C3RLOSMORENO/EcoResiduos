# EcoResiduos ♻️

EcoResiduos es una aplicación móvil desarrollada en Flutter diseñada para facilitar la correcta gestión, clasificación y disposición de residuos sólidos, promoviendo el reciclaje y el cuidado del medio ambiente.

## Características Principales ✨

- **Identificación con IA:** Usa la cámara de tu dispositivo para identificar automáticamente el tipo de residuo y recibir instrucciones claras sobre cómo manejarlo.
- **Búsqueda Inteligente:** Un directorio de residuos con información sobre categorías (PELIGROSO, INDUSTRIAL, RAEE, BIOSANITARIO) y guías de manejo conectadas en tiempo real.
- **Directorio de Gestores:** Encuentra empresas y gestores certificados cercanos a tu ubicación para la disposición adecuada de materiales especiales.
- **Autoridades Ambientales:** Acceso rápido al contacto y ubicación de entidades oficiales encargadas del control ambiental.

## Stack Tecnológico 🛠️

- **Frontend:** Flutter & Dart
- **Backend / Base de Datos:** Supabase (PostgreSQL, Realtime, Storage)
- **Diseño Visual:** Material Design 3

## Estructura del Proyecto 📂

El código está organizado siguiendo un patrón limpio y modular:
- `lib/screens/` - Pantallas de la aplicación organizadas por flujos (Inicio, Cámara, Resultados, Directorios).
- `lib/widgets/` - Componentes reutilizables de UI (Tarjetas, Botones, Estados de carga Shimmer, Empty States).
- `lib/services/` - Servicios de conexión a Supabase e integraciones externas.
- `lib/models/` - Modelos de datos para serialización JSON (WasteItem, Gestor, AutoridadAmbiental).
- `lib/theme/` - Configuración global de colores (`EcoColors`) y tipografías (Material 3).

## Requisitos Previos 📋

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Una cuenta en [Supabase](https://supabase.com/) (si deseas utilizar tu propio entorno).

## Configuración Inicial 🚀

1. Clona este repositorio:
   ```bash
   git clone https://github.com/JanerBus/Ecoresiduos_App.git
   ```
2. Instala las dependencias:
   ```bash
   flutter pub get
   ```
3. Ejecuta el proyecto en tu dispositivo o emulador:
   ```bash
   flutter run
   ```
