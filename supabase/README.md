# EcoResiduos: base de datos (Supabase)

<div align="center">

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Supabase-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)
![Row Level Security](https://img.shields.io/badge/Seguridad-RLS-red?style=for-the-badge)

**Tablas, reglas de acceso, funciones y almacenamiento de EcoResiduos**

</div>

---

## 1. Archivos

```
supabase/
├── migrations/
│   └── 00000000000000_schema_completo.sql   # Toda la base: tablas, RLS, funciones, triggers y buckets
└── functions/
    └── limpiar-fotos-huerfanas/             # Borra fotos que ya no usa ninguna fila (ver su README)
```

Hay una sola migración. Crea la base desde cero y también pone al día una base que ya existe: usa `IF NOT EXISTS`, `CREATE OR REPLACE` y `DROP … IF EXISTS`, y agrega con `ADD COLUMN IF NOT EXISTS` las columnas que se sumaron después de crear cada tabla.

### Cómo aplicarla

1. En Supabase, abre **SQL Editor** y pega el archivo completo.
2. Para probar sin guardar nada, agrega `BEGIN;` como primera línea y `ROLLBACK;` como última, y ejecútalo.
3. Si no hay errores, quita esas dos líneas y ejecútalo de nuevo.

El SQL Editor lo ejecuta todo o nada: si un paso falla, la base queda como estaba. Al aplicarlo sobre una base existente, el único dato que modifica es el de los teléfonos fijos de 7 dígitos, que pasan a 10 con el indicativo 607 de Santander.

Para que las recolecciones se confirmen solas a las 72 horas, activa antes la extensión `pg_cron` (Database → Extensions); la migración programa la tarea si la encuentra.

---

## 2. Tablas

| Tabla | Qué guarda |
|---|---|
| `usuarios` | Una fila por cuenta de `auth.users`: correo, rol y la autorización de datos aceptada (versión y fecha). La crea un trigger; la app no escribe aquí. |
| `perfiles_generador` | Nombre o empresa, documento, teléfono, municipio y correo de quien publica residuos. |
| `perfiles_gestor` | Empresas gestoras: NIT, razón social, contacto, ubicación, horario, estado de verificación, permiso ambiental, logo y portada. |
| `materiales_residuos` | Catálogo de materiales con su categoría según la Resolución 2184 de 2019. |
| `gestor_material` | Qué materiales recibe cada gestor y si el administrador ya los verificó. |
| `solicitudes_recoleccion` | Cada publicación: material, cantidad, dirección, estado, gestor asignado, problemas reportados y certificado. |
| `postulaciones_recoleccion` | Ofertas de los gestores: valor, tipo de valor y modalidad de entrega. |
| `solicitudes_historial_estados` | Cada cambio de estado de una solicitud. Lo escribe un trigger; la app solo lo lee. |
| `notificaciones` | Avisos por usuario que generan los triggers (oferta nueva, recolección marcada…). |
| `gestor_decisiones` | Historial de aprobaciones, rechazos y suspensiones de gestores, con el motivo. Solo lo lee el panel. |
| `historial_escaneos_ia` | Cada residuo identificado con la cámara: categoría, confianza y foto. |
| `autoridades_ambientales` | CDMB, AMB, CAS y otras autoridades, con su contacto y horario. |

---

## 3. Seguridad por fila (RLS)

Todas las tablas tienen RLS activo. La llave pública de la app solo deja leer y cambiar lo que las políticas permiten:

- Un generador ve sus propias solicitudes y edita las que siguen publicadas.
- Un gestor ve las solicitudes publicadas de los materiales que tiene verificados, las que ya ofertó y las que le asignaron.
- Los cambios de estado críticos no se hacen con `UPDATE` directo: pasan por las funciones de la sección 4.
- El panel de administración usa la llave `service_role` desde el servidor y no está limitado por RLS.

Las funciones auxiliares de las políticas (`mi_generador_id`, `mi_gestor_id`, `mis_materiales_verificados`, `mis_solicitudes_postuladas`…) viven en el esquema `private`, que la API no expone, y usan `SECURITY DEFINER` con `SET search_path = ''`.

---

## 4. Funciones (RPC)

Las que cambian el estado de una solicitud bloquean la fila (`FOR UPDATE`) para que dos acciones al mismo tiempo no la dejen en un estado inválido.

| Función | Quién la llama | Qué hace |
|---|---|---|
| `aceptar_postulacion_recoleccion` | Generador | Elige una oferta: la marca aceptada, las demás como no seleccionadas y pasa la solicitud a `EN_NEGOCIACION`. |
| `rechazar_postulacion_recoleccion` | Generador | Descarta una oferta. |
| `cancelar_solicitud_generador` | Generador | Cancela su publicación si está publicada o en negociación. |
| `confirmar_recoleccion_generador` | Generador | Confirma que recogieron el residuo. |
| `reportar_problema_recoleccion` | Generador | Reporta que la recolección no se hizo bien. |
| `actualizar_perfil_generador` | Generador | Cambia su nombre, documento y teléfono, validados en la base. |
| `marcar_recolectado_gestor` | Gestor | Marca la recolección hecha. |
| `cargar_certificado_gestor` | Gestor | Guarda el certificado de disposición final o aprovechamiento. |
| `actualizar_contacto_gestor` | Gestor | Cambia su correo de contacto, teléfono y dirección, validados en la base. |
| `renovar_permiso_gestor` | Gestor | Reemplaza su permiso ambiental por un PDF que subió a `renovacion/<gestor_id>/`. |
| `actualizar_materiales_gestor` | Gestor | Cambia los materiales que recibe; los nuevos quedan por verificar. |
| `vincular_cuenta_gestor` | Gestor | Vincula la cuenta con su empresa al primer inicio de sesión. |
| `registrar_autorizacion_datos` | Cualquier usuario | Guarda que aceptó la política de datos (Ley 1581 de 2012). |
| `cancelar_solicitud_admin` | Panel | Cancela una solicitud. |
| `cambiar_verificacion_gestor_admin` | Panel | Aprueba, rechaza o suspende un gestor y guarda el motivo en `gestor_decisiones`. |
| `resolver_problema_no_recogido` | Panel | Resuelve un problema reportado: la solicitud vuelve a `EN_NEGOCIACION`. |
| `auto_confirmar_recolecciones_vencidas` | `pg_cron`, cada hora | Confirma las recolecciones sin respuesta del generador después de 72 horas. |

Además, un trigger copia a `usuarios` y a `perfiles_generador` el correo de acceso cuando el usuario confirma un cambio de correo.

---

## 5. Almacenamiento (Storage)

| Bucket | Visibilidad | Límite | Tipos | Quién sube |
|---|---|---|---|---|
| `escaneos_ia` | Público | 5 MB | JPEG, PNG, WEBP | Cada usuario, en su carpeta (`<uid>/…`). Fotos de escaneos y publicaciones. |
| `fotos_perfil` | Público | 2 MB | JPEG, PNG, WEBP | Cada usuario, en su carpeta. Logo y portada de los gestores, foto de los generadores. |
| `certificados` | Público | 10 MB | PDF | El gestor, en su carpeta. |
| `permisos` | Privado | 10 MB | PDF | La empresa al registrarse (`registro/`) o al renovarlo (`renovacion/`), y el panel (`admin/`). Solo el servidor lo lee. |

Los buckets públicos sirven sus archivos a quien tenga la URL exacta; las rutas llevan el identificador aleatorio del usuario, así que no se pueden adivinar, pero no exigen sesión. Está anotado como limitación en el README del panel.
