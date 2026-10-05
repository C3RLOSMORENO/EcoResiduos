# EcoResiduos — Capa de Base de Datos y Servicios Supabase

<div align="center">

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Database%20%26%20Storage-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Row Level Security](https://img.shields.io/badge/Security-Row_Level_Security_(RLS)-red?style=for-the-badge)
![Transactions](https://img.shields.io/badge/ACID-Pessimistic_Locks_(FOR_UPDATE)-blue?style=for-the-badge)

**Arquitectura de persistencia relacional, control de acceso Zero-Trust y procedimientos transaccionales para EcoResiduos**

*Ámbito Territorial Acotado: Bucaramanga, Floridablanca, Girón, Piedecuesta, Barrancabermeja y Sabana de Torres (Santander)*

</div>

---

## 1. Estructura de la Capa de Datos

La persistencia del sistema está implementada sobre **PostgreSQL 15+** alojado en la infraestructura administrada de **Supabase**, aplicando una separación estricta entre el catálogo público expuesto a la API y las funciones transaccionales seguras del esquema `private`:

```
supabase/
├── migrations/                               # Scripts DDL y reglas de negocio relacionales
│   ├── 20260924000000_reglas_negocio_postulaciones_materiales.sql
│   ├── 20260925000000_seguridad_rls_y_perfiles.sql
│   ├── 20260926000000_storage_fotos.sql
│   ├── 20260927000000_notificaciones_historial_horario.sql
│   ├── 20260928000000_horario_autoridades.sql
│   ├── 20260930000000_certificado_recoleccion.sql
│   ├── 20261001000000_valor_postulacion_y_certificado.sql
│   ├── 20261002000000_registro_gestor_nuevo.sql
│   ├── 20261003000000_cancelar_solicitud_admin.sql
│   ├── 20261003000100_motivo_verificacion_y_avisos_gestor.sql
│   └── 20261003000200_resolucion_problemas_reportados.sql
│
└── functions/                                # Edge Functions del servidor
    └── limpiar-fotos-huerfanas/              # Mantenimiento automatizado de almacenamiento
```

---

## 2. Catálogo de Tablas del Sistema

```
┌───────────────────────────────────────┬───────────────────────────────────────────────────────────────┐
│ Tabla Relacional                      │ Responsabilidad en el Modelo de Dominio                       │
├───────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ `public.usuarios`                     │ Vinculación 1:1 con auth.users y asignación protegida de rol. │
│ `public.perfiles_generador`           │ Información de contacto y municipio del generador de residuo. │
│ `public.perfiles_gestor`              │ Directorio oficial de empresas gestoras y coordenadas GPS.    │
│ `public.materiales_residuos`          │ Catálogo de tipologías bajo Resolución 2184 de 2019.          │
│ `public.gestor_material`              │ Tabla N:M de materiales habilitados por empresa gestora.      │
│ `public.solicitudes_recoleccion`      │ Órdenes de recolección de residuos y ciclo de vida logístico. │
│ `public.postulaciones_recoleccion`    │ Propuestas económicas y cotizaciones de recolección.          │
│ `public.solicitudes_historial_estados`│ Bitácora inmutable de auditoría para trazabilidad de estados. │
│ `public.notificaciones`               │ Bandeja de alertas transaccionales por usuario.               │
│ `public.gestor_decisiones`            │ Registro inmutable de auditoría documental (Aprobado/Rechazo).│
│ `public.historial_escaneos_ia`        │ Registro de inferencias y nivel de confianza en dispositivo.  │
│ `public.autoridades_ambientales`      │ Directorio institucional de corporaciones (CDMB, AMB, CAS).   │
└───────────────────────────────────────┴───────────────────────────────────────────────────────────────┘
```

---

## 3. Modelo de Seguridad (Row Level Security - RLS)

Para implementar una arquitectura *Zero-Trust*, todas las tablas tienen RLS habilitado y sus privilegios públicos (`anon`, `authenticated`) fueron revocados para evitar operaciones masivas o no autorizadas:

1. **Esquema `private` no expuesto:** Las funciones de validación (`mi_generador_id`, `mi_gestor_id`, `mis_materiales_verificados`, `solicitudes_abiertas_para_mi`) se definen con `SECURITY DEFINER` y `SET search_path = ''` para prevenir inyecciones SQL y recursión en políticas.
2. **Aislamiento por Rol:** Los generadores solo pueden consultar sus propias solicitudes. Los gestores ambientales solo pueden ver solicitudes abiertas que correspondan a los materiales que tienen verificados en su licencia.
3. **Acceso Administrativo:** El panel administrativo opera con la clave `service_role` desde el backend Node.js, omitiendo RLS para auditoría centralizada.

---

## 4. Procedimientos Transaccionales ACID

Las mutaciones de estado se realizan mediante funciones RPC almacenadas con bloqueos pesimistas (`FOR UPDATE`), previniendo condiciones de carrera:

- `aceptar_postulacion_recoleccion(solicitud_id, postulacion_id)`: Adjudica la solicitud al gestor elegido, cambia las demás ofertas a `NO_SELECCIONADA` y transiciona el estado a `EN_NEGOCIACION`.
- `marcar_recolectado_gestor(solicitud_id)`: Valida la identidad del gestor asignado y registra la marca temporal de retiro físico.
- `confirmar_recoleccion_generador(solicitud_id)`: Valida la conformidad del generador y cierra el ciclo de servicio.
- `cargar_certificado_gestor(solicitud_id, url, tipo)`: Custodia el PDF probatorio de disposición final o aprovechamiento.
- `vincular_cuenta_gestor()`: Registra y vincula la empresa gestora en estado `PENDIENTE` en su primer inicio de sesión tras confirmar correo.

---

## 5. Configuración de Almacenamiento (Supabase Storage)

| Bucket | Visibilidad | Límite por Archivo | Tipos MIME | Política de Acceso |
|---|---|---|---|---|
| `solicitudes` | Público | 5 MB | JPEG, PNG, WEBP | Subida restringida a la carpeta del usuario autenticado (`auth.uid()`). |
| `certificados`| Público | 10 MB | PDF | Subida exclusiva del gestor asignado tras retiro físico del lote. |
| `permisos` | **Privado** | 10 MB | PDF | Subida anónima durante el onboarding en `registro/`. **Lectura exclusiva de backend**. |

---

## 6. Despliegue de Migraciones

Para aplicar el esquema relacional en una instancia de Supabase:
1. Abrir el **SQL Editor** en la consola del proyecto en Supabase.
2. Ejecutar secuencialmente los 11 archivos ubicados en el directorio `supabase/migrations/`.
