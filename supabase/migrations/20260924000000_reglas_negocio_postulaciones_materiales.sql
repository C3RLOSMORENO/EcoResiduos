-- ==============================================================================
-- Migración: Reglas de Negocio y Seguridad en Postulaciones y Recolección
-- Fecha: 2026-09-24
-- ==============================================================================

-- 1. Estructura de Columnas Requeridas en solicitudes_recoleccion y gestor_material
ALTER TABLE IF EXISTS solicitudes_recoleccion
ADD COLUMN IF NOT EXISTS recolectado_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS confirmado_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS problema_reportado BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS problema_detalle TEXT,
ADD COLUMN IF NOT EXISTS gestor_asignado_id BIGINT,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS gestor_material
ADD COLUMN IF NOT EXISTS verificado BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE IF EXISTS postulaciones_recoleccion
ADD COLUMN IF NOT EXISTS propuesta TEXT CHECK (char_length(propuesta) <= 500);

-- Inicializar materiales de gestores ya aprobados por el administrador
UPDATE gestor_material gm
SET verificado = TRUE
FROM perfiles_gestor pg
WHERE gm.gestor_id = pg.id
  AND pg.estado_verificacion = 'APROBADO';

-- Índice para optimizar consultas de solicitudes por materiales verificados
CREATE INDEX IF NOT EXISTS idx_gestor_material_verificado
ON gestor_material (gestor_id, material_id)
WHERE verificado = TRUE;

-- 2. Estados de postulación requeridos.
-- La columna puede ser un enum (de nombre desconocido) o texto con CHECK;
-- se resuelve el tipo real en lugar de asumir su nombre.
DO $$
DECLARE
    v_tipo TEXT;
    v_valor TEXT;
BEGIN
    SELECT t.typname INTO v_tipo
    FROM pg_attribute a
    JOIN pg_type t ON t.oid = a.atttypid
    WHERE a.attrelid = 'public.postulaciones_recoleccion'::regclass
      AND a.attname = 'estado'
      AND t.typtype = 'e';

    IF v_tipo IS NOT NULL THEN
        FOREACH v_valor IN ARRAY ARRAY['PROPUESTA', 'ACEPTADA', 'RECHAZADA', 'NO_SELECCIONADA'] LOOP
            EXECUTE format('ALTER TYPE public.%I ADD VALUE IF NOT EXISTS %L', v_tipo, v_valor);
        END LOOP;
    ELSE
        ALTER TABLE postulaciones_recoleccion
        DROP CONSTRAINT IF EXISTS postulaciones_recoleccion_estado_check;

        ALTER TABLE postulaciones_recoleccion
        ADD CONSTRAINT postulaciones_recoleccion_estado_check
        CHECK (estado IN ('PROPUESTA', 'ACEPTADA', 'RECHAZADA', 'NO_SELECCIONADA'));
    END IF;
END $$;

-- Valores que ya ofrecen la app (metros cúbicos al publicar) y el admin-panel (suspender un gestor).
ALTER TYPE public.unidad_medida_residuo ADD VALUE IF NOT EXISTS 'M3';
ALTER TYPE public.estado_verificacion_gestor ADD VALUE IF NOT EXISTS 'SUSPENDIDO';

-- Firmas de un borrador anterior de esta migración que recibían el id del
-- usuario como parámetro en lugar de derivarlo de auth.uid().
DROP FUNCTION IF EXISTS aceptar_postulacion_recoleccion(BIGINT, BIGINT, BIGINT);
DROP FUNCTION IF EXISTS marcar_recolectado_gestor(BIGINT, BIGINT);
DROP FUNCTION IF EXISTS confirmar_recoleccion_generador(BIGINT, BIGINT);

-- 3. Función RPC: Aceptar Postulación de Forma Atómica
-- Seguridad: Solo el Generador propietario de la solicitud (auth.uid()) puede ejecutarla.
-- Validación: Solicitud en estado 'PUBLICADO' y Postulación en 'PROPUESTA'.
CREATE OR REPLACE FUNCTION aceptar_postulacion_recoleccion(
    p_solicitud_id BIGINT,
    p_postulacion_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID;
    v_solicitud RECORD;
    v_postulacion RECORD;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No autenticado: Se requiere una sesión activa.' USING ERRCODE = '28000';
    END IF;

    -- Validar que el usuario sea el generador dueño de la solicitud
    SELECT s.* INTO v_solicitud
    FROM solicitudes_recoleccion s
    JOIN perfiles_generador pg ON s.generador_id = pg.id
    WHERE s.id = p_solicitud_id AND pg.usuario_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No autorizado: Solo el generador propietario puede aceptar postulaciones para esta solicitud.'
        USING ERRCODE = '42501';
    END IF;

    -- Validar que la solicitud esté en estado PUBLICADO
    IF v_solicitud.estado <> 'PUBLICADO' THEN
        RAISE EXCEPTION 'Operación inválida: La solicitud no se encuentra en estado PUBLICADO (estado actual: %).', v_solicitud.estado;
    END IF;

    -- Validar que la postulación exista, corresponda a la solicitud y esté en estado PROPUESTA
    SELECT * INTO v_postulacion
    FROM postulaciones_recoleccion
    WHERE id = p_postulacion_id AND solicitud_id = p_solicitud_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La postulación % no corresponde a la solicitud %.', p_postulacion_id, p_solicitud_id;
    END IF;

    IF v_postulacion.estado <> 'PROPUESTA' THEN
        RAISE EXCEPTION 'La postulación no se encuentra en estado PROPUESTA (estado actual: %).', v_postulacion.estado;
    END IF;

    -- 1. Marcar la postulación seleccionada como ACEPTADA
    UPDATE postulaciones_recoleccion
    SET estado = 'ACEPTADA'
    WHERE id = p_postulacion_id;

    -- 2. Marcar las demás postulaciones activas como NO_SELECCIONADA
    UPDATE postulaciones_recoleccion
    SET estado = 'NO_SELECCIONADA'
    WHERE solicitud_id = p_solicitud_id
      AND id <> p_postulacion_id
      AND estado = 'PROPUESTA';

    -- 3. Actualizar la solicitud a EN_NEGOCIACION y asignar el gestor
    UPDATE solicitudes_recoleccion
    SET estado = 'EN_NEGOCIACION',
        gestor_asignado_id = v_postulacion.gestor_id,
        updated_at = NOW()
    WHERE id = p_solicitud_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'solicitud_id', p_solicitud_id,
        'postulacion_id', p_postulacion_id,
        'gestor_id', v_postulacion.gestor_id,
        'mensaje', 'Postulación aceptada exitosamente.'
    );
END;
$$;


-- 4. Función RPC: Gestor Marca Solicitud como Recolectada
-- Seguridad: Solo el Gestor asignado cuya postulación está ACEPTADA (auth.uid()) puede marcarla.
-- Validación: Solicitud en 'EN_NEGOCIACION'.
CREATE OR REPLACE FUNCTION marcar_recolectado_gestor(
    p_solicitud_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID;
    v_solicitud RECORD;
    v_postulacion RECORD;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No autenticado: Se requiere una sesión activa.' USING ERRCODE = '28000';
    END IF;

    -- Validar que la solicitud exista y esté en EN_NEGOCIACION
    SELECT * INTO v_solicitud
    FROM solicitudes_recoleccion
    WHERE id = p_solicitud_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud % no existe.', p_solicitud_id;
    END IF;

    IF v_solicitud.estado <> 'EN_NEGOCIACION' THEN
        RAISE EXCEPTION 'Operación inválida: La solicitud debe estar en estado EN_NEGOCIACION (estado actual: %).', v_solicitud.estado;
    END IF;

    -- Validar que el llamante sea el gestor con postulación ACEPTADA
    SELECT pr.* INTO v_postulacion
    FROM postulaciones_recoleccion pr
    JOIN perfiles_gestor pg ON pr.gestor_id = pg.id
    WHERE pr.solicitud_id = p_solicitud_id
      AND pr.estado = 'ACEPTADA'
      AND pg.usuario_id = v_uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No autorizado: Solo el gestor ambiental asignado con postulación aceptada puede marcar recolección.'
        USING ERRCODE = '42501';
    END IF;

    -- Registrar marca de tiempo de recolección
    UPDATE solicitudes_recoleccion
    SET estado = 'RECOLECTADO',
        recolectado_at = NOW(),
        updated_at = NOW()
    WHERE id = p_solicitud_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'solicitud_id', p_solicitud_id,
        'recolectado_at', NOW(),
        'mensaje', 'Solicitud marcada como recolectada.'
    );
END;
$$;


-- 5. Función RPC: Generador Confirma Recolección
-- Seguridad: Solo el Generador dueño de la solicitud (auth.uid()) puede confirmar.
-- Validación: recolectado_at IS NOT NULL y confirmado_at IS NULL.
CREATE OR REPLACE FUNCTION confirmar_recoleccion_generador(
    p_solicitud_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID;
    v_solicitud RECORD;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No autenticado: Se requiere una sesión activa.' USING ERRCODE = '28000';
    END IF;

    -- Validar que el llamante sea el generador dueño
    SELECT s.* INTO v_solicitud
    FROM solicitudes_recoleccion s
    JOIN perfiles_generador pg ON s.generador_id = pg.id
    WHERE s.id = p_solicitud_id AND pg.usuario_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No autorizado: Solo el generador propietario puede confirmar la recolección.'
        USING ERRCODE = '42501';
    END IF;

    IF v_solicitud.recolectado_at IS NULL THEN
        RAISE EXCEPTION 'Operación inválida: El gestor aún no ha marcado la recolección como realizada.';
    END IF;

    IF v_solicitud.confirmado_at IS NOT NULL THEN
        RAISE EXCEPTION 'La recolección ya fue confirmada previamente.';
    END IF;

    -- Confirmar recolección
    UPDATE solicitudes_recoleccion
    SET confirmado_at = NOW(),
        updated_at = NOW()
    WHERE id = p_solicitud_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'solicitud_id', p_solicitud_id,
        'confirmado_at', NOW(),
        'mensaje', 'Recolección confirmada exitosamente.'
    );
END;
$$;


-- 6. Función RPC: Reportar Problema en la Recolección
-- Seguridad: Solo el Generador dueño de la solicitud (auth.uid()) puede reportar.
CREATE OR REPLACE FUNCTION reportar_problema_recoleccion(
    p_solicitud_id BIGINT,
    p_detalle TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID;
    v_solicitud RECORD;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No autenticado: Se requiere una sesión activa.' USING ERRCODE = '28000';
    END IF;

    -- Validar que el llamante sea el generador dueño
    SELECT s.* INTO v_solicitud
    FROM solicitudes_recoleccion s
    JOIN perfiles_generador pg ON s.generador_id = pg.id
    WHERE s.id = p_solicitud_id AND pg.usuario_id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No autorizado: Solo el generador propietario puede reportar un problema en esta solicitud.'
        USING ERRCODE = '42501';
    END IF;

    IF v_solicitud.recolectado_at IS NULL OR v_solicitud.confirmado_at IS NOT NULL THEN
        RAISE EXCEPTION 'Operación inválida: Solo se puede reportar un problema de una recolección pendiente de confirmar.';
    END IF;

    UPDATE solicitudes_recoleccion
    SET problema_reportado = TRUE,
        problema_detalle = p_detalle,
        updated_at = NOW()
    WHERE id = p_solicitud_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'solicitud_id', p_solicitud_id,
        'problema_reportado', TRUE,
        'mensaje', 'Problema registrado. Nuestro equipo administrativo revisará el caso.'
    );
END;
$$;


-- 7. Función RPC: Generador descarta una propuesta concreta
-- Seguridad: Solo el Generador dueño de la solicitud (auth.uid()) puede rechazarla.
CREATE OR REPLACE FUNCTION rechazar_postulacion_recoleccion(
    p_postulacion_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID;
    v_postulacion RECORD;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No autenticado: Se requiere una sesión activa.' USING ERRCODE = '28000';
    END IF;

    SELECT pr.* INTO v_postulacion
    FROM postulaciones_recoleccion pr
    JOIN solicitudes_recoleccion s ON s.id = pr.solicitud_id
    JOIN perfiles_generador pg ON pg.id = s.generador_id
    WHERE pr.id = p_postulacion_id AND pg.usuario_id = v_uid
    FOR UPDATE OF pr;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No autorizado: Solo el generador propietario puede rechazar esta postulación.'
        USING ERRCODE = '42501';
    END IF;

    IF v_postulacion.estado <> 'PROPUESTA' THEN
        RAISE EXCEPTION 'La postulación no se encuentra en estado PROPUESTA (estado actual: %).', v_postulacion.estado;
    END IF;

    UPDATE postulaciones_recoleccion
    SET estado = 'RECHAZADA'
    WHERE id = p_postulacion_id;

    RETURN jsonb_build_object('success', TRUE, 'postulacion_id', p_postulacion_id);
END;
$$;


-- 8. Función RPC: Vincular la cuenta de un gestor con su empresa del directorio
-- El registro corre sin sesión, así que el vínculo se hace en el primer
-- inicio de sesión. Los metadatos de la cuenta los escribe el cliente, por eso
-- solo se vincula si el correo confirmado coincide con el de la empresa.
-- Los materiales declarados quedan sin verificar hasta que el administrador los apruebe.
CREATE OR REPLACE FUNCTION vincular_cuenta_gestor()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID;
    v_email TEXT;
    v_meta JSONB;
    v_confirmado TIMESTAMPTZ;
    v_gestor RECORD;
    v_gestor_id BIGINT;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No autenticado: Se requiere una sesión activa.' USING ERRCODE = '28000';
    END IF;

    SELECT email, raw_user_meta_data, email_confirmed_at
    INTO v_email, v_meta, v_confirmado
    FROM auth.users WHERE id = v_uid;

    -- Sin correo confirmado no hay prueba de que la cuenta sea de la empresa.
    IF v_confirmado IS NULL OR upper(coalesce(v_meta->>'rol', '')) <> 'GESTOR' THEN
        RETURN jsonb_build_object('vinculado', FALSE);
    END IF;

    -- Cuentas creadas antes de guardar gestor_id: se busca la empresa por correo.
    v_gestor_id := (v_meta->>'gestor_id')::BIGINT;
    IF v_gestor_id IS NULL THEN
        SELECT id INTO v_gestor_id
        FROM perfiles_gestor
        WHERE lower(email_contacto) = lower(v_email)
          AND (usuario_id IS NULL OR usuario_id = v_uid)
        LIMIT 1;
    END IF;
    IF v_gestor_id IS NULL THEN
        RETURN jsonb_build_object('vinculado', FALSE);
    END IF;

    SELECT * INTO v_gestor FROM perfiles_gestor WHERE id = v_gestor_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('vinculado', FALSE);
    END IF;

    IF v_gestor.usuario_id IS NOT NULL AND v_gestor.usuario_id <> v_uid THEN
        RAISE EXCEPTION 'Esta empresa ya tiene una cuenta vinculada.' USING ERRCODE = '42501';
    END IF;

    IF lower(coalesce(v_gestor.email_contacto, '')) <> lower(v_email) THEN
        RAISE EXCEPTION 'El correo de la cuenta no coincide con el de la empresa en el directorio.' USING ERRCODE = '42501';
    END IF;

    UPDATE perfiles_gestor
    SET usuario_id = v_uid,
        telefono_contacto = coalesce(nullif(v_meta->>'telefono', ''), telefono_contacto),
        direccion = coalesce(nullif(v_meta->>'direccion', ''), direccion),
        municipio = coalesce(nullif(v_meta->>'municipio', ''), municipio)
    WHERE id = v_gestor_id;

    INSERT INTO gestor_material (gestor_id, material_id, verificado)
    SELECT v_gestor_id, declarado::BIGINT, FALSE
    FROM jsonb_array_elements_text(coalesce(v_meta->'materiales_declarados', '[]'::jsonb)) AS declarado
    WHERE EXISTS (SELECT 1 FROM materiales_residuos m WHERE m.id = declarado::BIGINT)
      AND NOT EXISTS (
          SELECT 1 FROM gestor_material gm
          WHERE gm.gestor_id = v_gestor_id AND gm.material_id = declarado::BIGINT
      );

    INSERT INTO usuarios (id, email, rol)
    VALUES (v_uid, v_email, 'GESTOR')
    ON CONFLICT (id) DO UPDATE SET rol = 'GESTOR';

    RETURN jsonb_build_object('vinculado', TRUE, 'gestor_id', v_gestor_id);
END;
$$;


-- 9. Función RPC: Generador cancela su publicación
-- Se permite mientras esté PUBLICADO o EN_NEGOCIACION. Las propuestas que
-- seguían abiertas pasan a RECHAZADA para que ningún gestor quede esperando.
CREATE OR REPLACE FUNCTION cancelar_solicitud_generador(
    p_solicitud_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID;
    v_solicitud RECORD;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No autenticado: Se requiere una sesión activa.' USING ERRCODE = '28000';
    END IF;

    SELECT s.* INTO v_solicitud
    FROM solicitudes_recoleccion s
    JOIN perfiles_generador pg ON s.generador_id = pg.id
    WHERE s.id = p_solicitud_id AND pg.usuario_id = v_uid
    FOR UPDATE OF s;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No autorizado: Solo el generador propietario puede cancelar esta solicitud.'
        USING ERRCODE = '42501';
    END IF;

    IF v_solicitud.estado NOT IN ('PUBLICADO', 'EN_NEGOCIACION') THEN
        RAISE EXCEPTION 'Operación inválida: No se puede cancelar una solicitud en estado %.', v_solicitud.estado;
    END IF;

    UPDATE solicitudes_recoleccion
    SET estado = 'CANCELADO',
        updated_at = NOW()
    WHERE id = p_solicitud_id;

    UPDATE postulaciones_recoleccion
    SET estado = 'RECHAZADA'
    WHERE solicitud_id = p_solicitud_id
      AND estado = 'PROPUESTA';

    RETURN jsonb_build_object('success', TRUE, 'solicitud_id', p_solicitud_id);
END;
$$;


-- 10. Procedimiento de Auto-Confirmación tras 72 Horas
-- Si el generador no responde tras 72 horas desde recolectado_at y no hay problema reportado:
CREATE OR REPLACE FUNCTION auto_confirmar_recolecciones_vencidas()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_afectadas INTEGER;
BEGIN
    UPDATE solicitudes_recoleccion
    SET confirmado_at = NOW(),
        updated_at = NOW()
    WHERE recolectado_at IS NOT NULL
      AND confirmado_at IS NULL
      AND problema_reportado = FALSE
      AND recolectado_at <= NOW() - INTERVAL '72 hours';

    GET DIAGNOSTICS v_afectadas = ROW_COUNT;
    RETURN v_afectadas;
END;
$$;

-- Programación horaria con pg_cron. Si la extensión no está activa, se omite:
-- actívala en Dashboard Supabase -> Database -> Extensions -> pg_cron y vuelve
-- a ejecutar este bloque.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule(
            'auto-confirmar-recolecciones-72h',
            '0 * * * *',
            'SELECT public.auto_confirmar_recolecciones_vencidas();'
        );
    ELSE
        RAISE NOTICE 'pg_cron no está habilitado: la auto-confirmación no quedó programada.';
    END IF;
END $$;

-- Solo usuarios autenticados pueden invocar las funciones de negocio.
REVOKE ALL ON FUNCTION aceptar_postulacion_recoleccion(BIGINT, BIGINT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION rechazar_postulacion_recoleccion(BIGINT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION marcar_recolectado_gestor(BIGINT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION confirmar_recoleccion_generador(BIGINT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION reportar_problema_recoleccion(BIGINT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION vincular_cuenta_gestor() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION cancelar_solicitud_generador(BIGINT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION auto_confirmar_recolecciones_vencidas() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION aceptar_postulacion_recoleccion(BIGINT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION rechazar_postulacion_recoleccion(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION marcar_recolectado_gestor(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION confirmar_recoleccion_generador(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION reportar_problema_recoleccion(BIGINT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION vincular_cuenta_gestor() TO authenticated;
GRANT EXECUTE ON FUNCTION cancelar_solicitud_generador(BIGINT) TO authenticated;
