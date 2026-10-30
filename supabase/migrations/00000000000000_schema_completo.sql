-- ==============================================================================
-- EcoResiduos · Esquema completo de la base de datos
-- Fecha: 2026-10-22
--
-- Archivo único que crea toda la base de datos desde cero. Reemplaza los 13
-- archivos de migración incremental anteriores.
--
-- Idempotente: se puede ejecutar sobre una base vacía o sobre una existente
-- (IF NOT EXISTS / CREATE OR REPLACE / DROP … IF EXISTS).
-- ==============================================================================


-- ─── Extensiones ──────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS moddatetime SCHEMA extensions;


-- ─── Tipos ────────────────────────────────────────────────────────────────────

DO $$ BEGIN
    CREATE TYPE public.rol_usuario AS ENUM ('GENERADOR', 'GESTOR', 'ADMIN');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE public.unidad_medida_residuo AS ENUM ('KG', 'TON', 'L', 'M3');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    ALTER TYPE public.unidad_medida_residuo ADD VALUE IF NOT EXISTS 'KG';
    ALTER TYPE public.unidad_medida_residuo ADD VALUE IF NOT EXISTS 'TON';
    ALTER TYPE public.unidad_medida_residuo ADD VALUE IF NOT EXISTS 'L';
    ALTER TYPE public.unidad_medida_residuo ADD VALUE IF NOT EXISTS 'M3';
EXCEPTION WHEN others THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE public.estado_verificacion_gestor AS ENUM (
        'PENDIENTE', 'APROBADO', 'RECHAZADO', 'SUSPENDIDO'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    ALTER TYPE public.estado_verificacion_gestor ADD VALUE IF NOT EXISTS 'PENDIENTE';
    ALTER TYPE public.estado_verificacion_gestor ADD VALUE IF NOT EXISTS 'APROBADO';
    ALTER TYPE public.estado_verificacion_gestor ADD VALUE IF NOT EXISTS 'RECHAZADO';
    ALTER TYPE public.estado_verificacion_gestor ADD VALUE IF NOT EXISTS 'SUSPENDIDO';
EXCEPTION WHEN others THEN NULL; END $$;


-- ─── Esquema privado (funciones internas, no expuesto por la API) ──────────────

CREATE SCHEMA IF NOT EXISTS private;
GRANT USAGE ON SCHEMA private TO authenticated;


-- ─── Tablas ───────────────────────────────────────────────────────────────────

-- usuarios: una fila por cuenta de auth.users.
-- Las crea el trigger ecoresiduos_crear_perfil; los clientes no escriben aquí.
CREATE TABLE IF NOT EXISTS public.usuarios (
    id         UUID        PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
    email      TEXT        NOT NULL,
    rol        public.rol_usuario NOT NULL DEFAULT 'GENERADOR',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Autorización del tratamiento de datos personales (Ley 1581 de 2012): qué
-- versión de la política aceptó y cuándo. La guarda el trigger al registrarse
-- o registrar_autorizacion_datos en las cuentas anteriores.
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS autorizacion_datos_version TEXT;
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS autorizacion_datos_at TIMESTAMPTZ;

-- materiales_residuos: catálogo de tipos de residuo que gestiona la app.
CREATE TABLE IF NOT EXISTS public.materiales_residuos (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo             TEXT,
    nombre_comun       TEXT NOT NULL,
    descripcion        TEXT,
    categoria          TEXT NOT NULL,
    guia_manejo        TEXT,
    subcategoria       TEXT,
    advertencia_manejo TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- autoridades_ambientales: CDMB, AMB, CAS y cualquier otra de Santander.
CREATE TABLE IF NOT EXISTS public.autoridades_ambientales (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sigla       TEXT,
    nombre      TEXT NOT NULL,
    jurisdiccion TEXT NOT NULL DEFAULT '',
    telefono    TEXT NOT NULL DEFAULT '',
    email       TEXT NOT NULL DEFAULT '',
    sitio_web   TEXT NOT NULL DEFAULT '',
    direccion   TEXT NOT NULL DEFAULT '',
    horario     TEXT CHECK (char_length(horario) <= 120),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- perfiles_generador: empresa o persona que publica solicitudes de recolección.
-- El trigger crear_perfil_nuevo_usuario la crea automáticamente al registrarse.
CREATE TABLE IF NOT EXISTS public.perfiles_generador (
    id                         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id                 UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    nombre_completo_o_empresa  TEXT NOT NULL DEFAULT '',
    documento_nit              TEXT NOT NULL DEFAULT '',
    telefono                   TEXT NOT NULL DEFAULT '',
    municipio                  TEXT NOT NULL DEFAULT '',
    email                      TEXT NOT NULL DEFAULT '',
    foto_perfil_path           TEXT,
    created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- perfiles_gestor: empresa autorizada para recoger y gestionar residuos.
-- La crea el admin-panel o la función vincular_cuenta_gestor.
CREATE TABLE IF NOT EXISTS public.perfiles_gestor (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id          UUID REFERENCES auth.users (id) ON DELETE SET NULL,
    nit                 TEXT NOT NULL,
    razon_social        TEXT NOT NULL,
    representante_legal TEXT,
    email_contacto      TEXT NOT NULL DEFAULT '',
    telefono_contacto   TEXT NOT NULL DEFAULT '',
    direccion           TEXT NOT NULL DEFAULT '',
    municipio           TEXT NOT NULL DEFAULT '',
    latitud             DOUBLE PRECISION,
    longitud            DOUBLE PRECISION,
    estado_verificacion public.estado_verificacion_gestor NOT NULL DEFAULT 'PENDIENTE',
    disponible          BOOLEAN NOT NULL DEFAULT TRUE,
    horario             TEXT CHECK (char_length(horario) <= 120),
    permiso_path        TEXT,
    foto_perfil_path    TEXT,
    portada_path        TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON COLUMN public.perfiles_gestor.permiso_path IS
    'Ruta en el bucket privado «permisos» de la licencia o permiso ambiental adjuntado al registrarse.';
COMMENT ON COLUMN public.perfiles_gestor.foto_perfil_path IS
    'Ruta de la foto de perfil o logo en el bucket «fotos_perfil» (<uid>/perfil/<marca>.<ext>). NULL: sin foto.';
COMMENT ON COLUMN public.perfiles_gestor.portada_path IS
    'Ruta de la portada en el bucket «fotos_perfil» (<uid>/portada/<marca>.<ext>). NULL: sin portada.';

-- gestor_material: qué materiales recibe cada empresa gestora.
-- verificado = TRUE cuando el admin-panel lo aprueba.
CREATE TABLE IF NOT EXISTS public.gestor_material (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gestor_id   BIGINT NOT NULL REFERENCES public.perfiles_gestor   (id) ON DELETE CASCADE,
    material_id BIGINT NOT NULL REFERENCES public.materiales_residuos (id) ON DELETE CASCADE,
    verificado  BOOLEAN NOT NULL DEFAULT FALSE
);

-- solicitudes_recoleccion: cada publicación de un generador.
CREATE TABLE IF NOT EXISTS public.solicitudes_recoleccion (
    id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    generador_id          BIGINT  NOT NULL REFERENCES public.perfiles_generador (id),
    material_id           BIGINT  NOT NULL REFERENCES public.materiales_residuos (id),
    cantidad_estimada     NUMERIC(12,3) NOT NULL,
    unidad_medida         public.unidad_medida_residuo NOT NULL DEFAULT 'KG',
    descripcion           TEXT,
    direccion_recoleccion TEXT    NOT NULL,
    municipio             TEXT    NOT NULL,
    telefono              TEXT    NOT NULL,
    estado                TEXT    NOT NULL DEFAULT 'PUBLICADO',
    foto_url              TEXT,
    latitud               DOUBLE PRECISION,
    longitud              DOUBLE PRECISION,
    -- Ciclo de vida de la recolección
    gestor_asignado_id    BIGINT,
    recolectado_at        TIMESTAMPTZ,
    confirmado_at         TIMESTAMPTZ,
    -- Problema reportado por el generador
    problema_reportado    BOOLEAN NOT NULL DEFAULT FALSE,
    problema_detalle      TEXT,
    problema_resuelto_at  TIMESTAMPTZ,
    problema_resolucion   TEXT CHECK (problema_resolucion IN ('NO_RECOGIDO')),
    problema_nota         TEXT    CHECK (char_length(problema_nota) <= 300),
    -- Certificado de recolección cargado por el gestor
    certificado_url       TEXT,
    certificado_tipo      TEXT    CHECK (certificado_tipo IN ('DISPOSICION_FINAL', 'APROVECHAMIENTO')),
    certificado_at        TIMESTAMPTZ,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ          DEFAULT NOW()
);

COMMENT ON COLUMN public.solicitudes_recoleccion.certificado_tipo IS
    'DISPOSICION_FINAL o APROVECHAMIENTO, según el certificado que cargó el gestor.';
COMMENT ON COLUMN public.solicitudes_recoleccion.problema_resolucion IS
    'NO_RECOGIDO: el residuo no se recogió y la solicitud volvió a EN_NEGOCIACION.';

-- postulaciones_recoleccion: propuestas de gestores a una solicitud.
CREATE TABLE IF NOT EXISTS public.postulaciones_recoleccion (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    solicitud_id      BIGINT  NOT NULL REFERENCES public.solicitudes_recoleccion (id) ON DELETE CASCADE,
    gestor_id         BIGINT  NOT NULL REFERENCES public.perfiles_gestor          (id) ON DELETE CASCADE,
    estado            TEXT    NOT NULL DEFAULT 'PROPUESTA',
    propuesta         TEXT    CHECK (char_length(propuesta) <= 500),
    tipo_valor        TEXT,
    valor             BIGINT,
    modalidad_entrega TEXT    NOT NULL DEFAULT 'RECOLECCION_DOMICILIO',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON COLUMN public.postulaciones_recoleccion.tipo_valor IS
    'COBRO_RECOLECCION: valor cobrado por recolección externa. PAGO_APROVECHAMIENTO: valor pagado por aprovechamiento.';
COMMENT ON COLUMN public.postulaciones_recoleccion.valor IS
    'Valor en pesos colombianos (COP), sin decimales.';
COMMENT ON COLUMN public.postulaciones_recoleccion.modalidad_entrega IS
    'RECOLECCION_DOMICILIO: el gestor recoge en la dirección del generador. ENTREGA_EN_GESTOR: el generador lleva el material al punto del gestor.';

-- historial_escaneos_ia: cada residuo identificado por la IA en la app.
CREATE TABLE IF NOT EXISTS public.historial_escaneos_ia (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id           UUID   NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    nombre_detectado     TEXT   NOT NULL,
    categoria_detectada  TEXT   NOT NULL,
    nivel_confianza      NUMERIC(5,4) NOT NULL,
    imagen_path          TEXT   NOT NULL,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- solicitudes_historial_estados: log de cambios de estado de cada solicitud.
-- Lo escribe el trigger al_cambiar_solicitud.
CREATE TABLE IF NOT EXISTS public.solicitudes_historial_estados (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    solicitud_id BIGINT NOT NULL REFERENCES public.solicitudes_recoleccion (id) ON DELETE CASCADE,
    estado       TEXT   NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- notificaciones: avisos por usuario que generan los triggers del servidor.
CREATE TABLE IF NOT EXISTS public.notificaciones (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id   UUID   NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    tipo         TEXT   NOT NULL,
    titulo       TEXT   NOT NULL,
    solicitud_id BIGINT REFERENCES public.solicitudes_recoleccion (id) ON DELETE CASCADE,
    leida_at     TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- gestor_decisiones: historial de decisiones del admin sobre verificación.
-- Solo lo lee service_role (el admin-panel); las apps no tienen acceso.
CREATE TABLE IF NOT EXISTS public.gestor_decisiones (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gestor_id   BIGINT NOT NULL REFERENCES public.perfiles_gestor (id) ON DELETE CASCADE,
    estado      TEXT   NOT NULL CHECK (estado IN ('PENDIENTE', 'APROBADO', 'RECHAZADO', 'SUSPENDIDO')),
    observacion TEXT   CHECK (char_length(observacion) <= 300),
    creado_por  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.gestor_decisiones IS
    'Cambios de estado de verificación hechos por el administrador, con su motivo. Solo la lee el panel (service_role).';


-- ─── Restricciones (CHECK) ────────────────────────────────────────────────────

ALTER TABLE public.perfiles_generador
    DROP CONSTRAINT IF EXISTS perfiles_generador_foto_perfil_propia;
ALTER TABLE public.perfiles_generador
    ADD CONSTRAINT perfiles_generador_foto_perfil_propia CHECK (
        foto_perfil_path IS NULL
        OR foto_perfil_path ~ ('^' || usuario_id::text || '/perfil/[0-9]+\.(jpg|jpeg|png|webp)$')
    );

ALTER TABLE public.perfiles_gestor
    DROP CONSTRAINT IF EXISTS perfiles_gestor_foto_perfil_propia;
ALTER TABLE public.perfiles_gestor
    ADD CONSTRAINT perfiles_gestor_foto_perfil_propia CHECK (
        foto_perfil_path IS NULL
        OR foto_perfil_path ~ ('^' || usuario_id::text || '/perfil/[0-9]+\.(jpg|jpeg|png|webp)$')
    );

ALTER TABLE public.perfiles_gestor
    DROP CONSTRAINT IF EXISTS perfiles_gestor_portada_propia;
ALTER TABLE public.perfiles_gestor
    ADD CONSTRAINT perfiles_gestor_portada_propia CHECK (
        portada_path IS NULL
        OR portada_path ~ ('^' || usuario_id::text || '/portada/[0-9]+\.(jpg|jpeg|png|webp)$')
    );

ALTER TABLE public.solicitudes_recoleccion
    DROP CONSTRAINT IF EXISTS solicitudes_estado_check;
ALTER TABLE public.solicitudes_recoleccion
    ADD CONSTRAINT solicitudes_estado_check
    CHECK (estado IN ('PUBLICADO', 'EN_NEGOCIACION', 'RECOLECTADO', 'CANCELADO'));

-- La app ya lo valida, pero con la llave pública se puede insertar sin pasar
-- por ella: una cantidad en cero o negativa descuadraría los reportes.
ALTER TABLE public.solicitudes_recoleccion
    DROP CONSTRAINT IF EXISTS solicitudes_cantidad_positiva;
ALTER TABLE public.solicitudes_recoleccion
    ADD CONSTRAINT solicitudes_cantidad_positiva CHECK (cantidad_estimada > 0);

ALTER TABLE public.postulaciones_recoleccion
    DROP CONSTRAINT IF EXISTS postulaciones_recoleccion_estado_check;
ALTER TABLE public.postulaciones_recoleccion
    ADD CONSTRAINT postulaciones_recoleccion_estado_check
    CHECK (estado IN ('PROPUESTA', 'ACEPTADA', 'RECHAZADA', 'NO_SELECCIONADA'));

ALTER TABLE public.postulaciones_recoleccion
    DROP CONSTRAINT IF EXISTS postulaciones_tipo_valor_check;
ALTER TABLE public.postulaciones_recoleccion
    ADD CONSTRAINT postulaciones_tipo_valor_check
    CHECK (tipo_valor IN ('COBRO_RECOLECCION', 'PAGO_APROVECHAMIENTO'));

ALTER TABLE public.postulaciones_recoleccion
    DROP CONSTRAINT IF EXISTS postulaciones_valor_check;
ALTER TABLE public.postulaciones_recoleccion
    ADD CONSTRAINT postulaciones_valor_check
    CHECK (
        (tipo_valor IS NULL AND valor IS NULL)
        OR (tipo_valor IS NOT NULL AND valor BETWEEN 0 AND 1000000000)
    );

ALTER TABLE public.postulaciones_recoleccion
    DROP CONSTRAINT IF EXISTS postulaciones_modalidad_entrega_check;
ALTER TABLE public.postulaciones_recoleccion
    ADD CONSTRAINT postulaciones_modalidad_entrega_check
    CHECK (modalidad_entrega IN ('RECOLECCION_DOMICILIO', 'ENTREGA_EN_GESTOR'));


-- ─── Índices ──────────────────────────────────────────────────────────────────

-- Una empresa gestora por NIT (sin dígito de verificación, como lo guardan la
-- app y el panel).
CREATE UNIQUE INDEX IF NOT EXISTS uq_perfiles_gestor_nit ON public.perfiles_gestor (nit);

CREATE INDEX IF NOT EXISTS idx_perfiles_generador_usuario       ON public.perfiles_generador      (usuario_id);
CREATE INDEX IF NOT EXISTS idx_perfiles_gestor_usuario          ON public.perfiles_gestor          (usuario_id);
CREATE INDEX IF NOT EXISTS idx_solicitudes_generador            ON public.solicitudes_recoleccion  (generador_id);
CREATE INDEX IF NOT EXISTS idx_solicitudes_estado_material      ON public.solicitudes_recoleccion  (estado, material_id);
CREATE INDEX IF NOT EXISTS idx_solicitudes_gestor_asignado      ON public.solicitudes_recoleccion  (gestor_asignado_id);
CREATE INDEX IF NOT EXISTS idx_postulaciones_solicitud          ON public.postulaciones_recoleccion (solicitud_id);
CREATE INDEX IF NOT EXISTS idx_postulaciones_gestor             ON public.postulaciones_recoleccion (gestor_id);
CREATE INDEX IF NOT EXISTS idx_historial_usuario                ON public.historial_escaneos_ia     (usuario_id);
CREATE INDEX IF NOT EXISTS idx_historial_estados_solicitud      ON public.solicitudes_historial_estados (solicitud_id, created_at);
CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario           ON public.notificaciones            (usuario_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notificaciones_no_leidas         ON public.notificaciones            (usuario_id) WHERE leida_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_gestor_decisiones_gestor         ON public.gestor_decisiones         (gestor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gestor_material_verificado       ON public.gestor_material           (gestor_id, material_id) WHERE verificado;
CREATE INDEX IF NOT EXISTS idx_solicitudes_problemas            ON public.solicitudes_recoleccion   (created_at DESC) WHERE problema_reportado;

-- Una sola postulación por gestor y solicitud.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.postulaciones_recoleccion
        GROUP BY solicitud_id, gestor_id HAVING count(*) > 1
    ) THEN
        RAISE NOTICE 'Hay postulaciones duplicadas: no se creó uq_postulacion_solicitud_gestor.';
    ELSE
        CREATE UNIQUE INDEX IF NOT EXISTS uq_postulacion_solicitud_gestor
        ON public.postulaciones_recoleccion (solicitud_id, gestor_id);
    END IF;
END $$;


-- ─── Datos iniciales (horarios de autoridades ambientales) ────────────────────

UPDATE public.autoridades_ambientales
SET horario = 'Lun-Vie 7:30 a.m. - 11:45 a.m. y 2:00 - 5:45 p.m.'
WHERE (sigla = 'CDMB' OR id = 1) AND horario IS NULL;

UPDATE public.autoridades_ambientales
SET horario = 'Lun-Jue 8:00 a.m. - 5:00 p.m. | Vie 8:00 a.m. - 4:00 p.m.'
WHERE (sigla = 'AMB'  OR id = 2) AND horario IS NULL;

UPDATE public.autoridades_ambientales
SET horario = 'Lun-Jue 8:00 a.m. - 12:00 m. y 2:00 - 6:00 p.m. | Vie 7:00 a.m. - 3:00 p.m.'
WHERE (sigla = 'CAS'  OR id = 3) AND horario IS NULL;


-- Teléfonos fijos de 7 dígitos, anteriores al plan de numeración de 2021: se
-- completan con el indicativo 607 de Santander, igual que en la app y el panel.
-- Las solicitudes no se tocan: son el registro de lo que se publicó.
UPDATE public.perfiles_gestor
SET telefono_contacto = '607' || regexp_replace(telefono_contacto, '[[:space:]().-]', '', 'g')
WHERE regexp_replace(telefono_contacto, '[[:space:]().-]', '', 'g') ~ '^[0-9]{7}$';

UPDATE public.perfiles_generador
SET telefono = '607' || regexp_replace(telefono, '[[:space:]().-]', '', 'g')
WHERE regexp_replace(telefono, '[[:space:]().-]', '', 'g') ~ '^[0-9]{7}$';

UPDATE public.autoridades_ambientales
SET telefono = '607' || regexp_replace(telefono, '[[:space:]().-]', '', 'g')
WHERE regexp_replace(telefono, '[[:space:]().-]', '', 'g') ~ '^[0-9]{7}$';


-- ─── Funciones privadas de ayuda (políticas y triggers) ───────────────────────

CREATE OR REPLACE FUNCTION private.mi_generador_id()
RETURNS BIGINT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT id::BIGINT FROM public.perfiles_generador
    WHERE usuario_id = (SELECT auth.uid()) ORDER BY id LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION private.mi_gestor_id()
RETURNS BIGINT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT id::BIGINT FROM public.perfiles_gestor
    WHERE usuario_id = (SELECT auth.uid()) ORDER BY id LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION private.mis_materiales_verificados()
RETURNS SETOF BIGINT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT gm.material_id::BIGINT
    FROM public.gestor_material gm
    JOIN public.perfiles_gestor pg ON pg.id = gm.gestor_id
    WHERE pg.usuario_id = (SELECT auth.uid())
      AND pg.estado_verificacion = 'APROBADO'
      AND gm.verificado;
$$;

CREATE OR REPLACE FUNCTION private.mis_solicitudes()
RETURNS SETOF BIGINT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT s.id::BIGINT
    FROM public.solicitudes_recoleccion s
    JOIN public.perfiles_generador pg ON pg.id = s.generador_id
    WHERE pg.usuario_id = (SELECT auth.uid());
$$;

CREATE OR REPLACE FUNCTION private.mis_solicitudes_postuladas()
RETURNS SETOF BIGINT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT pr.solicitud_id::BIGINT
    FROM public.postulaciones_recoleccion pr
    JOIN public.perfiles_gestor pg ON pg.id = pr.gestor_id
    WHERE pg.usuario_id = (SELECT auth.uid());
$$;

CREATE OR REPLACE FUNCTION private.solicitudes_abiertas_para_mi()
RETURNS SETOF BIGINT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT s.id::BIGINT
    FROM public.solicitudes_recoleccion s
    WHERE s.estado = 'PUBLICADO'
      AND s.material_id IN (SELECT private.mis_materiales_verificados());
$$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA private FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION
    private.mi_generador_id(),
    private.mi_gestor_id(),
    private.mis_materiales_verificados(),
    private.mis_solicitudes(),
    private.mis_solicitudes_postuladas(),
    private.solicitudes_abiertas_para_mi()
TO authenticated;

-- Trigger: crear perfil al registrar un usuario nuevo.
CREATE OR REPLACE FUNCTION private.crear_perfil_nuevo_usuario()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    v_meta JSONB := coalesce(NEW.raw_user_meta_data, '{}'::jsonb);
    v_rol  TEXT  := upper(coalesce(v_meta->>'rol', 'GENERADOR'));
BEGIN
    IF v_rol NOT IN ('GENERADOR', 'GESTOR') THEN v_rol := 'GENERADOR'; END IF;

    -- La app no deja registrarse sin aceptar la política de datos y manda la
    -- versión aceptada en los metadatos.
    INSERT INTO public.usuarios (id, email, rol, autorizacion_datos_version, autorizacion_datos_at)
    VALUES (
        NEW.id, NEW.email, v_rol::public.rol_usuario,
        nullif(v_meta->>'autorizacion_datos_version', ''),
        CASE WHEN nullif(v_meta->>'autorizacion_datos_version', '') IS NOT NULL THEN NOW() END
    )
    ON CONFLICT (id) DO NOTHING;

    IF v_rol = 'GENERADOR'
       AND NOT EXISTS (SELECT 1 FROM public.perfiles_generador WHERE usuario_id = NEW.id) THEN
        INSERT INTO public.perfiles_generador
            (usuario_id, nombre_completo_o_empresa, documento_nit, telefono, municipio, email)
        VALUES (
            NEW.id,
            coalesce(v_meta->>'nombre_completo_o_empresa', ''),
            coalesce(v_meta->>'documento_nit', ''),
            coalesce(v_meta->>'telefono', ''),
            coalesce(v_meta->>'municipio', ''),
            coalesce(NEW.email, '')
        );
    END IF;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.crear_perfil_nuevo_usuario() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS ecoresiduos_crear_perfil ON auth.users;
CREATE TRIGGER ecoresiduos_crear_perfil
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION private.crear_perfil_nuevo_usuario();

-- Notificaciones.
CREATE OR REPLACE FUNCTION private.notificar(
    p_usuario_id UUID, p_tipo TEXT, p_titulo TEXT, p_solicitud_id BIGINT
) RETURNS VOID LANGUAGE sql SECURITY DEFINER SET search_path = ''
AS $$
    INSERT INTO public.notificaciones (usuario_id, tipo, titulo, solicitud_id)
    SELECT p_usuario_id, p_tipo, p_titulo, p_solicitud_id
    WHERE p_usuario_id IS NOT NULL;
$$;

CREATE OR REPLACE FUNCTION private.nombre_material(p_material_id BIGINT)
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT coalesce(
        (SELECT lower(left(m.nombre_comun,1)) || substr(m.nombre_comun,2)
         FROM public.materiales_residuos m WHERE m.id = p_material_id),
        'residuo'
    );
$$;

CREATE OR REPLACE FUNCTION private.usuario_generador(p_generador_id BIGINT)
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT usuario_id FROM public.perfiles_generador WHERE id = p_generador_id;
$$;

CREATE OR REPLACE FUNCTION private.usuario_gestor(p_gestor_id BIGINT)
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
    SELECT usuario_id FROM public.perfiles_gestor WHERE id = p_gestor_id;
$$;

-- Trigger de solicitudes: historial + notificaciones.
-- ecoresiduos.origen = 'ADMIN' (set_config) → los mensajes dicen «EcoResiduos canceló…».
CREATE OR REPLACE FUNCTION private.al_cambiar_solicitud()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    v_material    TEXT := private.nombre_material(NEW.material_id);
    v_generador   UUID := private.usuario_generador(NEW.generador_id);
    v_gestor      UUID := private.usuario_gestor(NEW.gestor_asignado_id);
    v_razon_social TEXT;
BEGIN
    IF TG_OP = 'INSERT' OR NEW.estado IS DISTINCT FROM OLD.estado THEN
        INSERT INTO public.solicitudes_historial_estados (solicitud_id, estado)
        VALUES (NEW.id, NEW.estado::TEXT);
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF NEW.estado::TEXT = 'PUBLICADO' THEN
            INSERT INTO public.notificaciones (usuario_id, tipo, titulo, solicitud_id)
            SELECT DISTINCT pg.usuario_id,
                   'SOLICITUD_NUEVA',
                   format('Nueva solicitud de %s en %s', v_material, initcap(lower(NEW.municipio))),
                   NEW.id
            FROM public.gestor_material gm
            JOIN public.perfiles_gestor pg ON pg.id = gm.gestor_id
            WHERE gm.material_id = NEW.material_id
              AND gm.verificado
              AND pg.estado_verificacion = 'APROBADO'
              AND pg.usuario_id IS NOT NULL;
        END IF;
        RETURN NEW;
    END IF;

    IF NEW.estado IS DISTINCT FROM OLD.estado AND NEW.estado::TEXT = 'RECOLECTADO' THEN
        SELECT razon_social INTO v_razon_social
        FROM public.perfiles_gestor WHERE id = NEW.gestor_asignado_id;
        PERFORM private.notificar(v_generador, 'RECOLECCION_MARCADA',
            format('%s marcó como recolectado tu %s. Confírmalo o reporta un problema.',
                   coalesce(v_razon_social, 'El gestor'), v_material),
            NEW.id);
    END IF;

    IF NEW.estado IS DISTINCT FROM OLD.estado AND NEW.estado::TEXT = 'CANCELADO' THEN
        PERFORM private.notificar(v_gestor, 'SOLICITUD_CANCELADA',
            CASE WHEN current_setting('ecoresiduos.origen', true) = 'ADMIN'
                THEN format('EcoResiduos canceló la solicitud de %s', v_material)
                ELSE format('El generador canceló la recolección de %s', v_material)
            END, NEW.id);
    END IF;

    IF OLD.confirmado_at IS NULL AND NEW.confirmado_at IS NOT NULL THEN
        PERFORM private.notificar(v_gestor, 'RECOLECCION_CONFIRMADA',
            format('Se confirmó la recolección de %s', v_material), NEW.id);
    END IF;

    IF NOT OLD.problema_reportado AND NEW.problema_reportado THEN
        PERFORM private.notificar(v_gestor, 'PROBLEMA_REPORTADO',
            format('El generador reportó un problema con la recolección de %s', v_material), NEW.id);
    END IF;

    IF NEW.certificado_url IS NOT DISTINCT FROM OLD.certificado_url THEN
        RETURN NEW;
    END IF;
    IF NEW.certificado_url IS NOT NULL THEN
        SELECT razon_social INTO v_razon_social
        FROM public.perfiles_gestor WHERE id = NEW.gestor_asignado_id;
        PERFORM private.notificar(
            private.usuario_generador(NEW.generador_id),
            'CERTIFICADO_CARGADO',
            format('%s cargó %s de tu %s',
                coalesce(v_razon_social, 'El gestor'),
                CASE NEW.certificado_tipo
                    WHEN 'APROVECHAMIENTO' THEN 'el certificado de aprovechamiento'
                    ELSE 'el certificado de disposición final'
                END,
                v_material),
            NEW.id);
    END IF;

    RETURN NEW;
END;
$$;

-- Trigger de postulaciones: notificaciones.
CREATE OR REPLACE FUNCTION private.al_cambiar_postulacion()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    v_solicitud   RECORD;
    v_material    TEXT;
    v_gestor      UUID := private.usuario_gestor(NEW.gestor_id);
    v_razon_social TEXT;
BEGIN
    SELECT id, generador_id, material_id, estado::TEXT AS estado INTO v_solicitud
    FROM public.solicitudes_recoleccion WHERE id = NEW.solicitud_id;
    v_material := private.nombre_material(v_solicitud.material_id);

    IF TG_OP = 'INSERT' THEN
        SELECT razon_social INTO v_razon_social
        FROM public.perfiles_gestor WHERE id = NEW.gestor_id;
        PERFORM private.notificar(
            private.usuario_generador(v_solicitud.generador_id),
            'POSTULACION_NUEVA',
            format('%s se postuló a tu %s', coalesce(v_razon_social, 'Un gestor'), v_material),
            NEW.solicitud_id);
        RETURN NEW;
    END IF;

    IF NEW.estado IS NOT DISTINCT FROM OLD.estado THEN RETURN NEW; END IF;

    IF NEW.estado::TEXT = 'ACEPTADA' THEN
        PERFORM private.notificar(v_gestor, 'POSTULACION_ACEPTADA',
            format('Te aceptaron la recolección de %s', v_material), NEW.solicitud_id);
    ELSIF NEW.estado::TEXT = 'NO_SELECCIONADA' THEN
        PERFORM private.notificar(v_gestor, 'POSTULACION_NO_SELECCIONADA',
            format('La solicitud de %s fue asignada a otro gestor', v_material), NEW.solicitud_id);
    ELSIF NEW.estado::TEXT = 'RECHAZADA' THEN
        IF v_solicitud.estado = 'CANCELADO' THEN
            PERFORM private.notificar(v_gestor, 'SOLICITUD_CANCELADA',
                CASE WHEN current_setting('ecoresiduos.origen', true) = 'ADMIN'
                    THEN format('EcoResiduos canceló la solicitud de %s', v_material)
                    ELSE format('El generador canceló la publicación de %s', v_material)
                END, NEW.solicitud_id);
        ELSE
            PERFORM private.notificar(v_gestor, 'POSTULACION_RECHAZADA',
                format('El generador no aceptó tu propuesta para %s', v_material), NEW.solicitud_id);
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- Trigger de verificación de gestores.
CREATE OR REPLACE FUNCTION private.al_cambiar_verificacion_gestor()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
    v_motivo TEXT := nullif(trim(coalesce(current_setting('ecoresiduos.motivo', true), '')), '');
BEGIN
    IF NEW.estado_verificacion IS NOT DISTINCT FROM OLD.estado_verificacion THEN RETURN NEW; END IF;

    IF NEW.estado_verificacion::TEXT = 'APROBADO' THEN
        PERFORM private.notificar(NEW.usuario_id, 'GESTOR_APROBADO',
            'Aprobamos tu empresa. Ya ves las solicitudes de los materiales verificados.', NULL);
    ELSIF NEW.estado_verificacion::TEXT = 'RECHAZADO' THEN
        PERFORM private.notificar(NEW.usuario_id, 'GESTOR_RECHAZADO',
            CASE WHEN v_motivo IS NULL
                THEN 'No pudimos aprobar tu empresa. Escríbenos para revisar tu permiso ambiental.'
                ELSE format('No pudimos aprobar tu empresa. Motivo: %s', v_motivo)
            END, NULL);
    ELSIF NEW.estado_verificacion::TEXT = 'SUSPENDIDO' THEN
        PERFORM private.notificar(NEW.usuario_id, 'GESTOR_SUSPENDIDO',
            CASE WHEN v_motivo IS NULL
                THEN 'Suspendimos tu empresa: mientras tanto no ves solicitudes nuevas. Escríbenos para revisarlo.'
                ELSE format('Suspendimos tu empresa: mientras tanto no ves solicitudes nuevas. Motivo: %s', v_motivo)
            END, NULL);
    END IF;
    RETURN NEW;
END;
$$;

-- Triggers de materiales verificados.
CREATE OR REPLACE FUNCTION private.avisar_materiales_verificados(p_gestores JSONB)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.notificaciones (usuario_id, tipo, titulo, solicitud_id)
    SELECT pg.usuario_id,
           'MATERIALES_VERIFICADOS',
           CASE WHEN (g.value)::INTEGER = 1
               THEN 'Verificamos un material nuevo de tu empresa. Ya ves sus solicitudes.'
               ELSE format('Verificamos %s materiales nuevos de tu empresa. Ya ves sus solicitudes.', (g.value)::INTEGER)
           END,
           NULL
    FROM jsonb_each_text(p_gestores) AS g
    JOIN public.perfiles_gestor pg ON pg.id = (g.key)::BIGINT
    WHERE pg.estado_verificacion::TEXT = 'APROBADO'
      AND pg.usuario_id IS NOT NULL;
END;
$$;

CREATE OR REPLACE FUNCTION private.al_verificar_materiales()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_gestores JSONB;
BEGIN
    SELECT jsonb_object_agg(gestor_id::TEXT, cantidad) INTO v_gestores
    FROM (
        SELECT n.gestor_id, count(*) AS cantidad
        FROM nuevos n JOIN viejos v ON v.gestor_id = n.gestor_id AND v.material_id = n.material_id
        WHERE n.verificado AND NOT v.verificado GROUP BY n.gestor_id
    ) t;
    IF v_gestores IS NOT NULL THEN
        PERFORM private.avisar_materiales_verificados(v_gestores);
    END IF;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION private.al_agregar_materiales_verificados()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_gestores JSONB;
BEGIN
    SELECT jsonb_object_agg(gestor_id::TEXT, cantidad) INTO v_gestores
    FROM (SELECT n.gestor_id, count(*) AS cantidad FROM nuevos n WHERE n.verificado GROUP BY n.gestor_id) t;
    IF v_gestores IS NOT NULL THEN
        PERFORM private.avisar_materiales_verificados(v_gestores);
    END IF;
    RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION
    private.notificar(UUID, TEXT, TEXT, BIGINT),
    private.nombre_material(BIGINT),
    private.usuario_generador(BIGINT),
    private.usuario_gestor(BIGINT),
    private.al_cambiar_solicitud(),
    private.al_cambiar_postulacion(),
    private.al_cambiar_verificacion_gestor(),
    private.avisar_materiales_verificados(JSONB),
    private.al_verificar_materiales(),
    private.al_agregar_materiales_verificados()
FROM PUBLIC, anon, authenticated;


-- ─── Triggers ─────────────────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS solicitudes_updated_at ON public.solicitudes_recoleccion;
CREATE TRIGGER solicitudes_updated_at
BEFORE UPDATE ON public.solicitudes_recoleccion
FOR EACH ROW EXECUTE PROCEDURE extensions.moddatetime(updated_at);

DROP TRIGGER IF EXISTS solicitudes_historial_y_avisos ON public.solicitudes_recoleccion;
CREATE TRIGGER solicitudes_historial_y_avisos
AFTER INSERT OR UPDATE ON public.solicitudes_recoleccion
FOR EACH ROW EXECUTE FUNCTION private.al_cambiar_solicitud();

DROP TRIGGER IF EXISTS postulaciones_avisos ON public.postulaciones_recoleccion;
CREATE TRIGGER postulaciones_avisos
AFTER INSERT OR UPDATE OF estado ON public.postulaciones_recoleccion
FOR EACH ROW EXECUTE FUNCTION private.al_cambiar_postulacion();

DROP TRIGGER IF EXISTS perfiles_gestor_aviso_verificacion ON public.perfiles_gestor;
CREATE TRIGGER perfiles_gestor_aviso_verificacion
AFTER UPDATE OF estado_verificacion ON public.perfiles_gestor
FOR EACH ROW EXECUTE FUNCTION private.al_cambiar_verificacion_gestor();

DROP TRIGGER IF EXISTS gestor_material_aviso_verificados ON public.gestor_material;
CREATE TRIGGER gestor_material_aviso_verificados
AFTER UPDATE ON public.gestor_material
REFERENCING OLD TABLE AS viejos NEW TABLE AS nuevos
FOR EACH STATEMENT EXECUTE FUNCTION private.al_verificar_materiales();

DROP TRIGGER IF EXISTS gestor_material_aviso_agregados ON public.gestor_material;
CREATE TRIGGER gestor_material_aviso_agregados
AFTER INSERT ON public.gestor_material
REFERENCING NEW TABLE AS nuevos
FOR EACH STATEMENT EXECUTE FUNCTION private.al_agregar_materiales_verificados();


-- ─── Funciones públicas (RPC) ─────────────────────────────────────────────────

-- Acepta una postulación y pone las demás como NO_SELECCIONADA.
CREATE OR REPLACE FUNCTION public.aceptar_postulacion_recoleccion(
    p_solicitud_id BIGINT, p_postulacion_id BIGINT
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_uid UUID; v_solicitud RECORD; v_postulacion RECORD;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN RAISE EXCEPTION 'No autenticado.' USING ERRCODE = '28000'; END IF;

    SELECT s.* INTO v_solicitud
    FROM solicitudes_recoleccion s JOIN perfiles_generador pg ON s.generador_id = pg.id
    WHERE s.id = p_solicitud_id AND pg.usuario_id = v_uid FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'No autorizado.' USING ERRCODE = '42501'; END IF;
    IF v_solicitud.estado <> 'PUBLICADO' THEN
        RAISE EXCEPTION 'La solicitud no está en estado PUBLICADO (estado actual: %).', v_solicitud.estado;
    END IF;

    SELECT * INTO v_postulacion FROM postulaciones_recoleccion
    WHERE id = p_postulacion_id AND solicitud_id = p_solicitud_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'La postulación % no corresponde a la solicitud %.', p_postulacion_id, p_solicitud_id; END IF;
    IF v_postulacion.estado <> 'PROPUESTA' THEN
        RAISE EXCEPTION 'La postulación no está en estado PROPUESTA (estado actual: %).', v_postulacion.estado;
    END IF;

    UPDATE postulaciones_recoleccion SET estado = 'ACEPTADA'       WHERE id = p_postulacion_id;
    UPDATE postulaciones_recoleccion SET estado = 'NO_SELECCIONADA'
    WHERE solicitud_id = p_solicitud_id AND id <> p_postulacion_id AND estado = 'PROPUESTA';
    UPDATE solicitudes_recoleccion
    SET estado = 'EN_NEGOCIACION', gestor_asignado_id = v_postulacion.gestor_id, updated_at = NOW()
    WHERE id = p_solicitud_id;

    RETURN jsonb_build_object('success', TRUE, 'solicitud_id', p_solicitud_id,
        'postulacion_id', p_postulacion_id, 'gestor_id', v_postulacion.gestor_id,
        'mensaje', 'Postulación aceptada exitosamente.');
END;
$$;

-- Gestor rechaza una propuesta que recibió.
CREATE OR REPLACE FUNCTION public.rechazar_postulacion_recoleccion(p_postulacion_id BIGINT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_uid UUID; v_postulacion RECORD;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN RAISE EXCEPTION 'No autenticado.' USING ERRCODE = '28000'; END IF;

    SELECT pr.* INTO v_postulacion
    FROM postulaciones_recoleccion pr JOIN solicitudes_recoleccion s ON s.id = pr.solicitud_id
    JOIN perfiles_generador pg ON pg.id = s.generador_id
    WHERE pr.id = p_postulacion_id AND pg.usuario_id = v_uid FOR UPDATE OF pr;
    IF NOT FOUND THEN RAISE EXCEPTION 'No autorizado.' USING ERRCODE = '42501'; END IF;
    IF v_postulacion.estado <> 'PROPUESTA' THEN
        RAISE EXCEPTION 'La postulación no está en estado PROPUESTA (estado actual: %).', v_postulacion.estado;
    END IF;

    UPDATE postulaciones_recoleccion SET estado = 'RECHAZADA' WHERE id = p_postulacion_id;
    RETURN jsonb_build_object('success', TRUE, 'postulacion_id', p_postulacion_id);
END;
$$;

-- El gestor asignado marca que ya recogió el residuo.
CREATE OR REPLACE FUNCTION public.marcar_recolectado_gestor(p_solicitud_id BIGINT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_uid UUID; v_solicitud RECORD; v_postulacion RECORD;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN RAISE EXCEPTION 'No autenticado.' USING ERRCODE = '28000'; END IF;

    SELECT * INTO v_solicitud FROM solicitudes_recoleccion WHERE id = p_solicitud_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'La solicitud % no existe.', p_solicitud_id; END IF;
    IF v_solicitud.estado <> 'EN_NEGOCIACION' THEN
        RAISE EXCEPTION 'La solicitud debe estar en estado EN_NEGOCIACION (estado actual: %).', v_solicitud.estado;
    END IF;

    SELECT pr.* INTO v_postulacion
    FROM postulaciones_recoleccion pr JOIN perfiles_gestor pg ON pr.gestor_id = pg.id
    WHERE pr.solicitud_id = p_solicitud_id AND pr.estado = 'ACEPTADA' AND pg.usuario_id = v_uid;
    IF NOT FOUND THEN RAISE EXCEPTION 'No autorizado.' USING ERRCODE = '42501'; END IF;

    UPDATE solicitudes_recoleccion
    SET estado = 'RECOLECTADO', recolectado_at = NOW(), updated_at = NOW()
    WHERE id = p_solicitud_id;

    RETURN jsonb_build_object('success', TRUE, 'solicitud_id', p_solicitud_id,
        'recolectado_at', NOW(), 'mensaje', 'Solicitud marcada como recolectada.');
END;
$$;

-- El generador confirma que el residuo fue recogido.
CREATE OR REPLACE FUNCTION public.confirmar_recoleccion_generador(p_solicitud_id BIGINT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_uid UUID; v_solicitud RECORD;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN RAISE EXCEPTION 'No autenticado.' USING ERRCODE = '28000'; END IF;

    SELECT s.* INTO v_solicitud
    FROM solicitudes_recoleccion s JOIN perfiles_generador pg ON s.generador_id = pg.id
    WHERE s.id = p_solicitud_id AND pg.usuario_id = v_uid FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'No autorizado.' USING ERRCODE = '42501'; END IF;
    IF v_solicitud.recolectado_at IS NULL THEN
        RAISE EXCEPTION 'El gestor aún no ha marcado la recolección.';
    END IF;
    IF v_solicitud.confirmado_at IS NOT NULL THEN
        RAISE EXCEPTION 'La recolección ya fue confirmada.';
    END IF;

    UPDATE solicitudes_recoleccion SET confirmado_at = NOW(), updated_at = NOW() WHERE id = p_solicitud_id;
    RETURN jsonb_build_object('success', TRUE, 'solicitud_id', p_solicitud_id,
        'confirmado_at', NOW(), 'mensaje', 'Recolección confirmada exitosamente.');
END;
$$;

-- El generador reporta un problema tras marcar la recolección.
CREATE OR REPLACE FUNCTION public.reportar_problema_recoleccion(p_solicitud_id BIGINT, p_detalle TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_uid UUID; v_solicitud RECORD;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN RAISE EXCEPTION 'No autenticado.' USING ERRCODE = '28000'; END IF;

    SELECT s.* INTO v_solicitud
    FROM solicitudes_recoleccion s JOIN perfiles_generador pg ON s.generador_id = pg.id
    WHERE s.id = p_solicitud_id AND pg.usuario_id = v_uid FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'No autorizado.' USING ERRCODE = '42501'; END IF;
    IF v_solicitud.recolectado_at IS NULL OR v_solicitud.confirmado_at IS NOT NULL THEN
        RAISE EXCEPTION 'Solo se puede reportar un problema de una recolección marcada y sin confirmar.';
    END IF;

    UPDATE solicitudes_recoleccion
    SET problema_reportado = TRUE, problema_detalle = p_detalle, updated_at = NOW()
    WHERE id = p_solicitud_id;

    RETURN jsonb_build_object('success', TRUE, 'solicitud_id', p_solicitud_id,
        'problema_reportado', TRUE,
        'mensaje', 'Problema registrado. Nuestro equipo administrativo revisará el caso.');
END;
$$;

-- El generador cancela su propia publicación.
CREATE OR REPLACE FUNCTION public.cancelar_solicitud_generador(p_solicitud_id BIGINT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_uid UUID; v_solicitud RECORD;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN RAISE EXCEPTION 'No autenticado.' USING ERRCODE = '28000'; END IF;

    SELECT s.* INTO v_solicitud
    FROM solicitudes_recoleccion s JOIN perfiles_generador pg ON s.generador_id = pg.id
    WHERE s.id = p_solicitud_id AND pg.usuario_id = v_uid FOR UPDATE OF s;
    IF NOT FOUND THEN RAISE EXCEPTION 'No autorizado.' USING ERRCODE = '42501'; END IF;
    IF v_solicitud.estado NOT IN ('PUBLICADO', 'EN_NEGOCIACION') THEN
        RAISE EXCEPTION 'No se puede cancelar una solicitud en estado %.', v_solicitud.estado;
    END IF;

    UPDATE solicitudes_recoleccion SET estado = 'CANCELADO', updated_at = NOW() WHERE id = p_solicitud_id;
    UPDATE postulaciones_recoleccion SET estado = 'RECHAZADA'
    WHERE solicitud_id = p_solicitud_id AND estado = 'PROPUESTA';

    RETURN jsonb_build_object('success', TRUE, 'solicitud_id', p_solicitud_id);
END;
$$;

-- El admin-panel cancela una solicitud (el aviso dice «EcoResiduos canceló…»).
CREATE OR REPLACE FUNCTION public.cancelar_solicitud_admin(p_solicitud_id BIGINT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_solicitud RECORD; v_rechazadas INTEGER;
BEGIN
    SELECT s.* INTO v_solicitud FROM solicitudes_recoleccion s WHERE s.id = p_solicitud_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'La solicitud % no existe.', p_solicitud_id USING ERRCODE = 'P0002'; END IF;
    IF v_solicitud.estado::TEXT NOT IN ('PUBLICADO', 'EN_NEGOCIACION') THEN
        RAISE EXCEPTION 'Solo se puede cancelar una solicitud publicada o en negociación (estado: %).', v_solicitud.estado;
    END IF;

    PERFORM set_config('ecoresiduos.origen', 'ADMIN', true);
    UPDATE solicitudes_recoleccion SET estado = 'CANCELADO', updated_at = NOW() WHERE id = p_solicitud_id;
    UPDATE postulaciones_recoleccion SET estado = 'RECHAZADA'
    WHERE solicitud_id = p_solicitud_id AND estado = 'PROPUESTA';
    GET DIAGNOSTICS v_rechazadas = ROW_COUNT;

    PERFORM private.notificar(
        private.usuario_generador(v_solicitud.generador_id), 'SOLICITUD_CANCELADA',
        format('EcoResiduos canceló tu solicitud de %s. Si fue un error, puedes publicarla de nuevo.',
               private.nombre_material(v_solicitud.material_id)),
        p_solicitud_id);

    RETURN jsonb_build_object('success', TRUE, 'solicitud_id', p_solicitud_id,
        'postulaciones_rechazadas', v_rechazadas);
END;
$$;

REVOKE ALL ON FUNCTION public.cancelar_solicitud_admin(BIGINT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cancelar_solicitud_admin(BIGINT) TO service_role;

-- El gestor carga el certificado de disposición final o aprovechamiento.
CREATE OR REPLACE FUNCTION public.cargar_certificado_gestor(
    p_solicitud_id BIGINT, p_url TEXT, p_tipo TEXT
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_uid UUID; v_solicitud RECORD;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN RAISE EXCEPTION 'No autenticado.' USING ERRCODE = '28000'; END IF;

    SELECT * INTO v_solicitud FROM solicitudes_recoleccion WHERE id = p_solicitud_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'La solicitud % no existe.', p_solicitud_id; END IF;

    IF NOT EXISTS (
        SELECT 1 FROM postulaciones_recoleccion pr JOIN perfiles_gestor pg ON pg.id = pr.gestor_id
        WHERE pr.solicitud_id = p_solicitud_id AND pr.estado = 'ACEPTADA' AND pg.usuario_id = v_uid
    ) THEN RAISE EXCEPTION 'No autorizado.' USING ERRCODE = '42501'; END IF;
    IF v_solicitud.recolectado_at IS NULL THEN RAISE EXCEPTION 'Marca primero la recolección.'; END IF;
    IF p_tipo NOT IN ('DISPOSICION_FINAL', 'APROVECHAMIENTO') THEN
        RAISE EXCEPTION 'Tipo de certificado no válido: %.', p_tipo;
    END IF;
    IF position('/storage/v1/object/public/certificados/' || v_uid::text || '/' IN p_url) = 0
       OR right(lower(p_url), 4) <> '.pdf' THEN
        RAISE EXCEPTION 'El certificado debe ser un PDF subido por el gestor asignado.';
    END IF;

    UPDATE solicitudes_recoleccion
    SET certificado_url = p_url, certificado_tipo = p_tipo, certificado_at = NOW()
    WHERE id = p_solicitud_id;

    RETURN jsonb_build_object('success', TRUE, 'solicitud_id', p_solicitud_id,
        'anterior', v_solicitud.certificado_url);
END;
$$;

REVOKE ALL ON FUNCTION public.cargar_certificado_gestor(BIGINT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cargar_certificado_gestor(BIGINT, TEXT, TEXT) TO authenticated;

-- Usuario: registra que aceptó la política de tratamiento de datos (Ley 1581
-- de 2012). La usan las cuentas creadas antes de pedir la autorización y
-- todas cuando cambia la versión de la política.
CREATE OR REPLACE FUNCTION public.registrar_autorizacion_datos(p_version TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    IF (SELECT auth.uid()) IS NULL THEN
        RAISE EXCEPTION 'Inicia sesión para continuar.';
    END IF;
    IF p_version IS NULL OR char_length(btrim(p_version)) NOT BETWEEN 1 AND 20 THEN
        RAISE EXCEPTION 'La versión de la política no es válida.';
    END IF;
    UPDATE public.usuarios
    SET autorizacion_datos_version = btrim(p_version), autorizacion_datos_at = NOW()
    WHERE id = (SELECT auth.uid());
END;
$$;

REVOKE ALL ON FUNCTION public.registrar_autorizacion_datos(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_autorizacion_datos(TEXT) TO authenticated;

-- Admin resuelve un problema reportado («No se recogió»).
CREATE OR REPLACE FUNCTION public.resolver_problema_no_recogido(p_solicitud_id BIGINT, p_nota TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_solicitud   RECORD;
    v_nota        TEXT := nullif(left(trim(coalesce(p_nota, '')), 300), '');
    v_material    TEXT;
    v_razon_social TEXT;
    v_cola        TEXT;
BEGIN
    SELECT s.* INTO v_solicitud FROM solicitudes_recoleccion s WHERE s.id = p_solicitud_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'La solicitud % no existe.', p_solicitud_id USING ERRCODE = 'P0002'; END IF;
    IF NOT v_solicitud.problema_reportado OR v_solicitud.confirmado_at IS NOT NULL
       OR v_solicitud.estado::TEXT <> 'RECOLECTADO' THEN
        RAISE EXCEPTION 'Solo se puede resolver un problema reportado en una recolección sin confirmar.';
    END IF;

    UPDATE solicitudes_recoleccion
    SET estado = 'EN_NEGOCIACION', recolectado_at = NULL, problema_reportado = FALSE,
        problema_resuelto_at = NOW(), problema_resolucion = 'NO_RECOGIDO',
        problema_nota = v_nota, updated_at = NOW()
    WHERE id = p_solicitud_id;

    v_material := private.nombre_material(v_solicitud.material_id);
    SELECT razon_social INTO v_razon_social FROM perfiles_gestor WHERE id = v_solicitud.gestor_asignado_id;
    v_cola := CASE WHEN v_nota IS NULL THEN '' ELSE format(' Nota: %s', v_nota) END;

    PERFORM private.notificar(private.usuario_generador(v_solicitud.generador_id), 'PROBLEMA_RESUELTO',
        format('Revisamos el problema con la recolección de %s: el residuo no se recogió. %s debe volver a coordinar la recogida.%s',
               v_material, coalesce(v_razon_social, 'El gestor'), v_cola), p_solicitud_id);
    PERFORM private.notificar(private.usuario_gestor(v_solicitud.gestor_asignado_id), 'PROBLEMA_RESUELTO',
        format('Revisamos el problema con la recolección de %s: el residuo no se recogió. Coordina de nuevo la recogida con el generador.%s',
               v_material, v_cola), p_solicitud_id);

    RETURN jsonb_build_object('success', TRUE, 'solicitud_id', p_solicitud_id);
END;
$$;

REVOKE ALL ON FUNCTION public.resolver_problema_no_recogido(BIGINT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.resolver_problema_no_recogido(BIGINT, TEXT) TO service_role;

-- Admin cambia el estado de verificación de un gestor y guarda el motivo.
CREATE OR REPLACE FUNCTION public.cambiar_verificacion_gestor_admin(
    p_gestor_id BIGINT, p_estado TEXT, p_observacion TEXT, p_admin TEXT
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_estado      TEXT   := upper(trim(coalesce(p_estado, '')));
    v_observacion TEXT   := nullif(left(trim(coalesce(p_observacion, '')), 300), '');
    v_decision    BIGINT;
BEGIN
    IF v_estado NOT IN ('PENDIENTE', 'APROBADO', 'RECHAZADO', 'SUSPENDIDO') THEN
        RAISE EXCEPTION 'Estado inválido: %.', p_estado;
    END IF;

    PERFORM 1 FROM perfiles_gestor WHERE id = p_gestor_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'El gestor % no existe.', p_gestor_id USING ERRCODE = 'P0002'; END IF;

    INSERT INTO gestor_decisiones (gestor_id, estado, observacion, creado_por)
    VALUES (p_gestor_id, v_estado, v_observacion, nullif(trim(coalesce(p_admin, '')), ''))
    RETURNING id INTO v_decision;

    PERFORM set_config('ecoresiduos.motivo', coalesce(v_observacion, ''), true);
    UPDATE perfiles_gestor
    SET estado_verificacion = v_estado::public.estado_verificacion_gestor WHERE id = p_gestor_id;

    RETURN jsonb_build_object('success', TRUE, 'gestor_id', p_gestor_id, 'decision_id', v_decision);
END;
$$;

REVOKE ALL ON FUNCTION public.cambiar_verificacion_gestor_admin(BIGINT, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cambiar_verificacion_gestor_admin(BIGINT, TEXT, TEXT, TEXT) TO service_role;

-- Gestor reemplaza la lista de materiales que declara recibir.
CREATE OR REPLACE FUNCTION public.actualizar_materiales_gestor(p_materiales BIGINT[])
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_gestor_id BIGINT; v_quitados INTEGER; v_nuevos INTEGER;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'No autenticado.' USING ERRCODE = '28000'; END IF;
    v_gestor_id := private.mi_gestor_id();
    IF v_gestor_id IS NULL THEN RAISE EXCEPTION 'No autorizado.' USING ERRCODE = '42501'; END IF;
    IF coalesce(cardinality(p_materiales), 0) = 0 THEN RAISE EXCEPTION 'Elige al menos un material.'; END IF;

    DELETE FROM gestor_material WHERE gestor_id = v_gestor_id AND material_id <> ALL (p_materiales);
    GET DIAGNOSTICS v_quitados = ROW_COUNT;

    INSERT INTO gestor_material (gestor_id, material_id, verificado)
    SELECT v_gestor_id, m.id, FALSE FROM materiales_residuos m
    WHERE m.id = ANY (p_materiales)
      AND NOT EXISTS (SELECT 1 FROM gestor_material gm WHERE gm.gestor_id = v_gestor_id AND gm.material_id = m.id);
    GET DIAGNOSTICS v_nuevos = ROW_COUNT;

    RETURN jsonb_build_object('nuevos', v_nuevos, 'quitados', v_quitados);
END;
$$;

REVOKE ALL ON FUNCTION public.actualizar_materiales_gestor(BIGINT[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.actualizar_materiales_gestor(BIGINT[]) TO authenticated;

-- Vincula la cuenta de un gestor con su empresa del directorio. Si la cuenta
-- viene de un registro nuevo crea la empresa en estado PENDIENTE.
CREATE OR REPLACE FUNCTION public.vincular_cuenta_gestor()
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_uid        UUID; v_email TEXT; v_meta JSONB; v_confirmado TIMESTAMPTZ;
    v_gestor     RECORD; v_gestor_id BIGINT; v_nit TEXT; v_permiso TEXT;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN RAISE EXCEPTION 'No autenticado.' USING ERRCODE = '28000'; END IF;

    SELECT email, raw_user_meta_data, email_confirmed_at
    INTO v_email, v_meta, v_confirmado FROM auth.users WHERE id = v_uid;

    IF v_confirmado IS NULL OR upper(coalesce(v_meta->>'rol', '')) <> 'GESTOR' THEN
        RETURN jsonb_build_object('vinculado', FALSE);
    END IF;

    v_gestor_id := (v_meta->>'gestor_id')::BIGINT;
    IF v_gestor_id IS NULL THEN
        SELECT id INTO v_gestor_id FROM perfiles_gestor
        WHERE lower(email_contacto) = lower(v_email)
          AND (usuario_id IS NULL OR usuario_id = v_uid) LIMIT 1;
    END IF;

    IF v_gestor_id IS NULL AND coalesce(v_meta->>'registro_nuevo', '') = 'true' THEN
        v_nit := regexp_replace(split_part(coalesce(v_meta->>'nit', ''), '-', 1), '[^0-9]', '', 'g');
        IF v_nit !~ '^[0-9]{8,15}$' THEN RAISE EXCEPTION 'El NIT del registro no es válido.'; END IF;
        IF EXISTS (SELECT 1 FROM perfiles_gestor WHERE nit = v_nit) THEN
            RAISE EXCEPTION 'Ya hay una empresa registrada con el NIT %.', v_nit USING ERRCODE = '23505';
        END IF;

        v_permiso := v_meta->>'permiso_path';
        IF v_permiso IS NULL
           OR NOT EXISTS (SELECT 1 FROM storage.objects WHERE bucket_id = 'permisos' AND name = v_permiso AND name LIKE 'registro/%')
           OR EXISTS (SELECT 1 FROM perfiles_gestor WHERE permiso_path = v_permiso) THEN
            RAISE EXCEPTION 'Falta el permiso ambiental en PDF del registro.';
        END IF;

        INSERT INTO perfiles_gestor (
            nit, razon_social, representante_legal, telefono_contacto, email_contacto,
            direccion, municipio, horario, latitud, longitud, estado_verificacion, permiso_path
        ) VALUES (
            v_nit,
            upper(left(trim(coalesce(v_meta->>'razon_social', '')), 200)),
            nullif(trim(coalesce(v_meta->>'representante_legal', '')), ''),
            trim(coalesce(v_meta->>'telefono', '')),
            lower(v_email),
            trim(coalesce(v_meta->>'direccion', '')),
            upper(trim(coalesce(v_meta->>'municipio', ''))),
            nullif(left(trim(coalesce(v_meta->>'horario', '')), 120), ''),
            7.119349, -73.122741, 'PENDIENTE', v_permiso
        ) RETURNING id INTO v_gestor_id;
    END IF;

    IF v_gestor_id IS NULL THEN RETURN jsonb_build_object('vinculado', FALSE); END IF;

    SELECT * INTO v_gestor FROM perfiles_gestor WHERE id = v_gestor_id FOR UPDATE;
    IF NOT FOUND THEN RETURN jsonb_build_object('vinculado', FALSE); END IF;
    IF v_gestor.usuario_id IS NOT NULL AND v_gestor.usuario_id <> v_uid THEN
        RAISE EXCEPTION 'Esta empresa ya tiene una cuenta vinculada.' USING ERRCODE = '42501';
    END IF;
    IF lower(coalesce(v_gestor.email_contacto, '')) <> lower(v_email) THEN
        RAISE EXCEPTION 'El correo no coincide con el registrado para la empresa.' USING ERRCODE = '42501';
    END IF;

    UPDATE perfiles_gestor
    SET usuario_id = v_uid,
        telefono_contacto = coalesce(nullif(v_meta->>'telefono', ''), telefono_contacto),
        direccion         = coalesce(nullif(v_meta->>'direccion', ''), direccion),
        municipio         = coalesce(nullif(upper(v_meta->>'municipio'), ''), municipio)
    WHERE id = v_gestor_id;

    INSERT INTO gestor_material (gestor_id, material_id, verificado)
    SELECT v_gestor_id, declarado::BIGINT, FALSE
    FROM jsonb_array_elements_text(coalesce(v_meta->'materiales_declarados', '[]'::jsonb)) AS declarado
    WHERE EXISTS (SELECT 1 FROM materiales_residuos m WHERE m.id = declarado::BIGINT)
      AND NOT EXISTS (SELECT 1 FROM gestor_material gm WHERE gm.gestor_id = v_gestor_id AND gm.material_id = declarado::BIGINT);

    INSERT INTO usuarios (id, email, rol)
    VALUES (v_uid, v_email, 'GESTOR')
    ON CONFLICT (id) DO UPDATE SET rol = 'GESTOR';

    RETURN jsonb_build_object('vinculado', TRUE, 'gestor_id', v_gestor_id);
END;
$$;

REVOKE ALL ON FUNCTION public.vincular_cuenta_gestor() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vincular_cuenta_gestor() TO authenticated;

-- Auto-confirmación de recolecciones sin respuesta tras 72 horas.
CREATE OR REPLACE FUNCTION public.auto_confirmar_recolecciones_vencidas()
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_afectadas INTEGER;
BEGIN
    UPDATE solicitudes_recoleccion
    SET confirmado_at = NOW(), updated_at = NOW()
    WHERE recolectado_at IS NOT NULL
      AND confirmado_at IS NULL
      AND problema_reportado = FALSE
      AND recolectado_at <= NOW() - INTERVAL '72 hours';
    GET DIAGNOSTICS v_afectadas = ROW_COUNT;
    RETURN v_afectadas;
END;
$$;

REVOKE ALL ON FUNCTION public.aceptar_postulacion_recoleccion(BIGINT, BIGINT)    FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rechazar_postulacion_recoleccion(BIGINT)           FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.marcar_recolectado_gestor(BIGINT)                  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.confirmar_recoleccion_generador(BIGINT)            FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reportar_problema_recoleccion(BIGINT, TEXT)        FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cancelar_solicitud_generador(BIGINT)               FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.vincular_cuenta_gestor()                           FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.auto_confirmar_recolecciones_vencidas()            FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.aceptar_postulacion_recoleccion(BIGINT, BIGINT)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.rechazar_postulacion_recoleccion(BIGINT)         TO authenticated;
GRANT EXECUTE ON FUNCTION public.marcar_recolectado_gestor(BIGINT)                TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirmar_recoleccion_generador(BIGINT)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.reportar_problema_recoleccion(BIGINT, TEXT)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancelar_solicitud_generador(BIGINT)             TO authenticated;
GRANT EXECUTE ON FUNCTION public.vincular_cuenta_gestor()                         TO authenticated;

-- pg_cron: activar en Dashboard → Database → Extensions → pg_cron antes de ejecutar.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule('auto-confirmar-recolecciones-72h', '0 * * * *',
            'SELECT public.auto_confirmar_recolecciones_vencidas();');
    ELSE
        RAISE NOTICE 'pg_cron no está habilitado: la auto-confirmación no quedó programada.';
    END IF;
END $$;


-- ─── Permisos por tabla ───────────────────────────────────────────────────────

REVOKE ALL ON
    public.usuarios, public.perfiles_generador, public.perfiles_gestor,
    public.gestor_material, public.materiales_residuos, public.autoridades_ambientales,
    public.solicitudes_recoleccion, public.postulaciones_recoleccion,
    public.historial_escaneos_ia, public.solicitudes_historial_estados,
    public.notificaciones, public.gestor_decisiones
FROM anon, authenticated;

GRANT SELECT ON public.perfiles_gestor, public.gestor_material,
    public.materiales_residuos, public.autoridades_ambientales TO anon, authenticated;

GRANT SELECT ON public.usuarios, public.perfiles_generador,
    public.solicitudes_recoleccion, public.postulaciones_recoleccion,
    public.historial_escaneos_ia, public.solicitudes_historial_estados
TO authenticated;

GRANT SELECT, DELETE ON public.notificaciones TO authenticated;
GRANT UPDATE (leida_at) ON public.notificaciones TO authenticated;

GRANT INSERT (
    generador_id, material_id, cantidad_estimada, unidad_medida, descripcion,
    direccion_recoleccion, municipio, telefono, estado, foto_url, latitud, longitud
) ON public.solicitudes_recoleccion TO authenticated;

GRANT UPDATE (
    material_id, cantidad_estimada, unidad_medida, descripcion,
    direccion_recoleccion, municipio, telefono, foto_url, latitud, longitud
) ON public.solicitudes_recoleccion TO authenticated;

REVOKE UPDATE (problema_resuelto_at, problema_resolucion, problema_nota)
ON public.solicitudes_recoleccion FROM anon, authenticated;

GRANT INSERT (solicitud_id, gestor_id, estado, propuesta, tipo_valor, valor, modalidad_entrega)
ON public.postulaciones_recoleccion TO authenticated;

GRANT INSERT (usuario_id, nombre_detectado, categoria_detectada, nivel_confianza, imagen_path)
ON public.historial_escaneos_ia TO authenticated;

GRANT UPDATE (municipio)            ON public.perfiles_generador TO authenticated;
GRANT UPDATE (municipio)            ON public.perfiles_gestor    TO authenticated;
GRANT UPDATE (foto_perfil_path)     ON public.perfiles_generador TO authenticated;
GRANT UPDATE (foto_perfil_path, portada_path) ON public.perfiles_gestor TO authenticated;
GRANT INSERT (modalidad_entrega)    ON public.postulaciones_recoleccion TO authenticated;

REVOKE ALL ON public.gestor_decisiones FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON public.gestor_decisiones TO service_role;


-- ─── Row Level Security ───────────────────────────────────────────────────────

ALTER TABLE public.usuarios                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfiles_generador          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfiles_gestor             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gestor_material             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materiales_residuos         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.autoridades_ambientales     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_recoleccion     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.postulaciones_recoleccion   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historial_escaneos_ia       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_historial_estados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificaciones              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gestor_decisiones           ENABLE ROW LEVEL SECURITY;

-- Limpiar todas las políticas existentes antes de recrearlas.
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public'
             AND tablename IN (
                 'usuarios','perfiles_generador','perfiles_gestor','gestor_material',
                 'materiales_residuos','autoridades_ambientales','solicitudes_recoleccion',
                 'postulaciones_recoleccion','historial_escaneos_ia',
                 'solicitudes_historial_estados','notificaciones','gestor_decisiones'
             )
    LOOP
        EXECUTE format('DROP POLICY %I ON public.%I', r.policyname, r.tablename);
    END LOOP;
END $$;

CREATE POLICY "usuarios: ver la propia"
ON public.usuarios FOR SELECT TO authenticated
USING (id = (SELECT auth.uid()));

CREATE POLICY "perfiles_generador: ver el propio"
ON public.perfiles_generador FOR SELECT TO authenticated
USING (usuario_id = (SELECT auth.uid()));

CREATE POLICY "perfiles_generador: editar el propio"
ON public.perfiles_generador FOR UPDATE TO authenticated
USING (usuario_id = (SELECT auth.uid()))
WITH CHECK (usuario_id = (SELECT auth.uid()));

CREATE POLICY "perfiles_gestor: directorio público"
ON public.perfiles_gestor FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "perfiles_gestor: editar el propio"
ON public.perfiles_gestor FOR UPDATE TO authenticated
USING (usuario_id = (SELECT auth.uid()))
WITH CHECK (usuario_id = (SELECT auth.uid()));

CREATE POLICY "gestor_material: lectura pública"
ON public.gestor_material FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "materiales_residuos: lectura pública"
ON public.materiales_residuos FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "autoridades_ambientales: lectura pública"
ON public.autoridades_ambientales FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "solicitudes: ver las permitidas"
ON public.solicitudes_recoleccion FOR SELECT TO authenticated
USING (
    generador_id = (SELECT private.mi_generador_id())
    OR gestor_asignado_id = (SELECT private.mi_gestor_id())
    OR id IN (SELECT private.mis_solicitudes_postuladas())
    OR (estado = 'PUBLICADO' AND material_id IN (SELECT private.mis_materiales_verificados()))
);

CREATE POLICY "solicitudes: publicar como generador"
ON public.solicitudes_recoleccion FOR INSERT TO authenticated
WITH CHECK (generador_id = (SELECT private.mi_generador_id()) AND estado = 'PUBLICADO');

CREATE POLICY "solicitudes: editar la propia publicada"
ON public.solicitudes_recoleccion FOR UPDATE TO authenticated
USING (generador_id = (SELECT private.mi_generador_id()) AND estado = 'PUBLICADO')
WITH CHECK (generador_id = (SELECT private.mi_generador_id()) AND estado = 'PUBLICADO');

CREATE POLICY "postulaciones: ver las propias o las recibidas"
ON public.postulaciones_recoleccion FOR SELECT TO authenticated
USING (
    gestor_id = (SELECT private.mi_gestor_id())
    OR solicitud_id IN (SELECT private.mis_solicitudes())
);

CREATE POLICY "postulaciones: postularse como gestor"
ON public.postulaciones_recoleccion FOR INSERT TO authenticated
WITH CHECK (
    gestor_id = (SELECT private.mi_gestor_id())
    AND estado = 'PROPUESTA'
    AND tipo_valor IS NOT NULL
    AND valor IS NOT NULL
    AND solicitud_id IN (SELECT private.solicitudes_abiertas_para_mi())
);

CREATE POLICY "historial: ver el propio"
ON public.historial_escaneos_ia FOR SELECT TO authenticated
USING (usuario_id = (SELECT auth.uid()));

CREATE POLICY "historial: registrar el propio"
ON public.historial_escaneos_ia FOR INSERT TO authenticated
WITH CHECK (usuario_id = (SELECT auth.uid()));

CREATE POLICY "historial_estados: ver el de mis solicitudes"
ON public.solicitudes_historial_estados FOR SELECT TO authenticated
USING (
    solicitud_id IN (SELECT private.mis_solicitudes())
    OR solicitud_id IN (SELECT private.mis_solicitudes_postuladas())
);

CREATE POLICY "notificaciones: ver las propias"
ON public.notificaciones FOR SELECT TO authenticated
USING (usuario_id = (SELECT auth.uid()));

CREATE POLICY "notificaciones: marcar las propias"
ON public.notificaciones FOR UPDATE TO authenticated
USING (usuario_id = (SELECT auth.uid()))
WITH CHECK (usuario_id = (SELECT auth.uid()));

CREATE POLICY "notificaciones: descartar las propias"
ON public.notificaciones FOR DELETE TO authenticated
USING (usuario_id = (SELECT auth.uid()));


-- ─── Tiempo real ──────────────────────────────────────────────────────────────

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notificaciones'
    ) THEN ALTER PUBLICATION supabase_realtime ADD TABLE public.notificaciones; END IF;
END $$;


-- ─── Storage: buckets y políticas ─────────────────────────────────────────────

-- escaneos_ia: fotos de residuos tomadas por la app. Se crea si no existe
-- (antes solo se actualizaba y en un proyecto nuevo no quedaba creado).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('escaneos_ia', 'escaneos_ia', TRUE, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit, allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "escaneos_ia: subir en carpeta propia"  ON storage.objects;
DROP POLICY IF EXISTS "escaneos_ia: leer carpeta propia"      ON storage.objects;
DROP POLICY IF EXISTS "escaneos_ia: borrar en carpeta propia" ON storage.objects;

CREATE POLICY "escaneos_ia: subir en carpeta propia"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'escaneos_ia' AND (storage.foldername(name))[1] = (SELECT auth.uid()::text));

CREATE POLICY "escaneos_ia: leer carpeta propia"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'escaneos_ia' AND (storage.foldername(name))[1] = (SELECT auth.uid()::text));

CREATE POLICY "escaneos_ia: borrar en carpeta propia"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'escaneos_ia' AND (storage.foldername(name))[1] = (SELECT auth.uid()::text));

-- certificados: PDF de disposición final o aprovechamiento.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('certificados', 'certificados', TRUE, 10485760, ARRAY['application/pdf'])
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit, allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "certificados: subir en carpeta propia"  ON storage.objects;
DROP POLICY IF EXISTS "certificados: leer carpeta propia"      ON storage.objects;
DROP POLICY IF EXISTS "certificados: borrar en carpeta propia" ON storage.objects;

CREATE POLICY "certificados: subir en carpeta propia"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'certificados' AND (storage.foldername(name))[1] = (SELECT auth.uid()::text));

CREATE POLICY "certificados: leer carpeta propia"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'certificados' AND (storage.foldername(name))[1] = (SELECT auth.uid()::text));

CREATE POLICY "certificados: borrar en carpeta propia"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'certificados' AND (storage.foldername(name))[1] = (SELECT auth.uid()::text));

-- permisos: licencias ambientales (privado, solo service_role las lee).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('permisos', 'permisos', FALSE, 10485760, ARRAY['application/pdf'])
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit, allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "permisos: subir al registrarse"    ON storage.objects;
DROP POLICY IF EXISTS "permisos: renovar en carpeta propia" ON storage.objects;

CREATE POLICY "permisos: subir al registrarse"
ON storage.objects FOR INSERT TO anon, authenticated
WITH CHECK (bucket_id = 'permisos' AND (storage.foldername(name))[1] = 'registro'
            AND lower(storage.extension(name)) = 'pdf');

CREATE POLICY "permisos: renovar en carpeta propia"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'permisos' AND (storage.foldername(name))[1] = 'renovacion'
            AND lower(storage.extension(name)) = 'pdf');

-- fotos_perfil: foto de perfil y portada (público).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('fotos_perfil', 'fotos_perfil', TRUE, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit, allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "fotos_perfil: subir en carpeta propia"  ON storage.objects;
DROP POLICY IF EXISTS "fotos_perfil: leer carpeta propia"      ON storage.objects;
DROP POLICY IF EXISTS "fotos_perfil: borrar en carpeta propia" ON storage.objects;

CREATE POLICY "fotos_perfil: subir en carpeta propia"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'fotos_perfil'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
    AND (storage.foldername(name))[2] IN ('perfil', 'portada'));

CREATE POLICY "fotos_perfil: leer carpeta propia"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'fotos_perfil' AND (storage.foldername(name))[1] = (SELECT auth.uid()::text));

CREATE POLICY "fotos_perfil: borrar en carpeta propia"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'fotos_perfil' AND (storage.foldername(name))[1] = (SELECT auth.uid()::text));
