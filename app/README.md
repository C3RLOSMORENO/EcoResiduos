# EcoResiduos — Aplicación Móvil

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![TensorFlow Lite](https://img.shields.io/badge/TensorFlow_Lite-MobileNetV3-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Flutter_SDK-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Tests](https://img.shields.io/badge/Flutter_Tests-124_Passed-brightgreen?style=for-the-badge)
[![Descargar APK](https://img.shields.io/badge/Descargar-APK%20Android-2ea44f?style=for-the-badge&logo=android&logoColor=white)](https://github.com/C3RLOSMORENO/EcoResiduos/releases/latest)

**App para clasificar residuos con la cámara, sin conexión, y coordinar su recolección con empresas gestoras autorizadas**

*Bucaramanga, Floridablanca, Girón, Piedecuesta, Barrancabermeja y Sabana de Torres (Santander)*

</div>

---

## 1. Qué hace

| Ciudadano o empresa generadora | Empresa gestora autorizada |
|---|---|
| Identifica un residuo con la cámara y ve cómo manejarlo (Resolución 2184 de 2019). | Ve las solicitudes publicadas de los materiales que tiene verificados. |
| Publica una solicitud de recolección con foto, cantidad, dirección y ubicación. | Envía ofertas (cobro por recolección o pago por aprovechamiento). |
| Compara las ofertas, elige una empresa y confirma la entrega. | Marca la recolección y carga el certificado de disposición final o aprovechamiento. |
| Descarga el certificado en PDF. | Mantiene su perfil, horario, logo y materiales. |

Si no hay conexión al publicar, la solicitud queda en una cola en el teléfono y se envía sola al recuperarla ([`cola_publicaciones.dart`](lib/services/cola_publicaciones.dart)).

---

## 2. Organización del código

La app se organiza por funcionalidades: cada una tiene sus pantallas, modelos y repositorios. Las pantallas no hablan con Supabase directamente sino a través de repositorios, y las pruebas los reemplazan por versiones falsas ([`test/fakes.dart`](test/fakes.dart)).

```
app/
├── assets/
│   ├── branding/                 # Ícono y logo
│   └── models/                   # ecoresiduos_model.tflite y labels.txt (8 clases)
├── lib/
│   ├── main.dart                 # Inicio de Supabase, tema y AuthGate (login, autorización de datos, inicio)
│   ├── data/                     # Categorías de la Resolución 2184 de 2019 y guías de manejo
│   ├── features/
│   │   ├── auth/                 # Inicio de sesión, registro, recuperación y autorización de datos
│   │   └── solicitudes/          # Publicar, ofertas, mis publicaciones, detalle y materiales
│   ├── legal/                    # Política de tratamiento de datos (Ley 1581 de 2012)
│   ├── models/                   # Gestor, perfiles, notificaciones, historial de escaneos…
│   ├── repositories/             # Autenticación, gestores y notificaciones
│   ├── screens/                  # Inicio, cámara, resultado de la identificación, guías
│   ├── services/                 # Clasificador, ubicación, fotos, certificados, cola sin conexión
│   ├── theme/                    # Colores, tipografía y espaciados (Material 3)
│   ├── utils/                    # Municipios, formatos y validación de teléfonos y NIT
│   └── widgets/                  # Componentes compartidos
└── test/                         # 124 pruebas de lógica y de pantallas
```

---

## 3. Clasificación con la cámara

La clasificación ocurre en el teléfono, con el modelo **MobileNetV3 Large** entrenado por el equipo ([`model_training/`](model_training/)) y ejecutado con `tflite_flutter`. No necesita internet ([`identificacion_service.dart`](lib/services/identificacion_service.dart)).

1. De la foto se sacan cuatro imágenes de 224 × 224 píxeles: el recorte central, ese recorte en espejo, la foto completa y un recorte al 75 %.
2. El modelo clasifica cada una y se promedian las probabilidades. Así un encuadre desafortunado pesa menos.
3. Si gana la clase `FONDO` (la foto no muestra un residuo) o la confianza es menor al 40 %, la app lo dice y ofrece alternativas en lugar de adivinar. Desde el 85 % el resultado se muestra como «Muy probable».

Clases: `APROVECHABLE`, `ORGANICO`, `ORDINARIO`, `PELIGROSO`, `RAEE`, `RCD`, `RIESGO_BIOLOGICO` y `FONDO`.

La foto se guarda en el historial de escaneos del usuario en Supabase (bucket `escaneos_ia`); el análisis no se envía a ningún servicio externo.

---

## 4. Datos personales y validaciones

- **Autorización (Ley 1581 de 2012):** el registro no avanza sin marcar la autorización del tratamiento de datos, que enlaza la [política completa](lib/legal/politica_datos.dart). Quien ya tenía cuenta la acepta la próxima vez que entra. La versión aceptada y la fecha quedan en `usuarios.autorizacion_datos_version` y `autorizacion_datos_at`.
- **Contraseñas:** mínimo 8 caracteres, con letras y números. Supabase Auth aplica la misma regla aunque alguien no use la app.
- **Teléfonos:** celular o fijo de 10 dígitos, fijo de 7 dígitos (se guarda con el indicativo 607 de Santander) o línea 01 8000, con extensión opcional. Son las mismas reglas del panel ([`validacion.dart`](lib/utils/validacion.dart)).
- **NIT:** 8 a 15 dígitos; si se escribe el dígito de verificación, se comprueba con el algoritmo de la DIAN.

---

## 5. Ejecución

Requisitos: Flutter estable (3.47 o superior, con Dart 3.12) y un teléfono o emulador Android.

```bash
cd app
flutter pub get
flutter run
```

La app usa la llave pública de Supabase, que puede ir en el código: los datos los protegen las políticas de seguridad por fila de la base ([`supabase/migrations`](../supabase/migrations/)), no la llave.

El APK de cada versión se compila en GitHub Actions ([`build-apk.yml`](../.github/workflows/build-apk.yml)) y se publica en [Releases](https://github.com/C3RLOSMORENO/EcoResiduos/releases/latest).

---

## 6. Pruebas

```bash
flutter analyze
flutter test        # 124 pruebas
```

Cubren el registro (incluida la autorización de datos y la validación de NIT y teléfono), la recuperación de contraseña, la publicación y la cola sin conexión, el detalle de una solicitud, las listas, la foto de perfil y el dibujo de cada pantalla en tema claro y oscuro.
