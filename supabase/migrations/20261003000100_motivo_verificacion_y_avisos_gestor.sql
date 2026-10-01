-- ==============================================================================
-- Migración: Decisiones del administrador sobre gestores y avisos al gestor
-- Fecha: 2026-10-03
-- Ejecutar DESPUÉS de 20261003000000_cancelar_solicitud_admin.sql
--
-- 1. public.gestor_decisiones guarda cada cambio de estado de verificación
--    que hace el administrador, con su motivo. No va en perfiles_gestor porque
--    esa tabla es de lectura pública (directorio): cualquiera leería el motivo
--    de un rechazo. Esta tabla solo la lee service_role (el panel).
-- 2. public.cambiar_verificacion_gestor_admin registra la decisión y cambia el
--    estado en una sola transacción; el motivo llega al trigger de avisos por
--    la configuración de la transacción (ecoresiduos.motivo), sin guardarse en
--    la tabla pública.
-- 3. El aviso de rechazo incluye el motivo y se agregan dos avisos que faltaban:
--    GESTOR_SUSPENDIDO y MATERIALES_VERIFICADOS (cuando el administrador
--    verifica o agrega materiales de un gestor ya aprobado).
--
-- El panel funciona sin esta migración: cambia el estado directamente y avisa
-- que el motivo no se guardó.
--
-- Referencias (documentación oficial):
--   RLS:               https://supabase.com/docs/guides/database/postgres/row-level-security
--   set_config:        https://www.postgresql.org/docs/current/functions-admin.html#FUNCTIONS-ADMIN-SET
--   Tablas de transición: https://www.postgresql.org/docs/current/sql-createtrigger.html
-- ==============================================================================


-- 1. Historial de decisiones (solo service_role)
CREATE TABLE IF NOT EXISTS public.gestor_decisiones (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    gestor_id BIGINT NOT NULL REFERENCES public.perfiles_gestor (id) ON DELETE CASCADE,
    estado TEXT NOT NULL CHECK (estado IN ('PENDIENTE', 'APROBADO', 'RECHAZADO', 'SUSPENDIDO')),
    observacion TEXT CHECK (char_length(observacion) <= 300),
    creado_por TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gestor_decisiones_gestor
ON public.gestor_decisiones (gestor_id, created_at DESC);

COMMENT ON TABLE public.gestor_decisiones IS
    'Cambios de estado de verificación que hizo el administrador, con su motivo. Solo la lee el panel (service_role).';

-- RLS sin políticas: anon y authenticated no ven ninguna fila.
ALTER TABLE public.gestor_decisiones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.gestor_decisiones FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON public.gestor_decisiones TO service_role;


-- 2. Función RPC del panel
CREATE OR REPLACE FUNCTION public.cambiar_verificacion_gestor_admin(
    p_gestor_id BIGINT,
    p_estado TEXT,
    p_observacion TEXT,
    p_admin TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_estado TEXT := upper(trim(coalesce(p_estado, '')));
    v_observacion TEXT := nullif(left(trim(coalesce(p_observacion, '')), 300), '');
    v_decision BIGINT;
BEGIN
    IF v_estado NOT IN ('PENDIENTE', 'APROBADO', 'RECHAZADO', 'SUSPENDIDO') THEN
        RAISE EXCEPTION 'Estado de verificación inválido: %.', p_estado;
    END IF;

    PERFORM 1 FROM perfiles_gestor WHERE id = p_gestor_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El gestor % no existe.', p_gestor_id USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO gestor_decisiones (gestor_id, estado, observacion, creado_por)
    VALUES (p_gestor_id, v_estado, v_observacion, nullif(trim(coalesce(p_admin, '')), ''))
    RETURNING id INTO v_decision;

    -- Solo para esta transacción: el trigger de avisos lee el motivo de aquí.
    PERFORM set_config('ecoresiduos.motivo', coalesce(v_observacion, ''), true);

    UPDATE perfiles_gestor
    SET estado_verificacion = v_estado::public.estado_verificacion_gestor
    WHERE id = p_gestor_id;

    RETURN jsonb_build_object('success', TRUE, 'gestor_id', p_gestor_id, 'decision_id', v_decision);
END;
$$;

REVOKE ALL ON FUNCTION public.cambiar_verificacion_gestor_admin(BIGINT, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cambiar_verificacion_gestor_admin(BIGINT, TEXT, TEXT, TEXT) TO service_role;


-- 3. Avisos al cambiar el estado de verificación
CREATE OR REPLACE FUNCTION private.al_cambiar_verificacion_gestor()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_motivo TEXT := nullif(trim(coalesce(current_setting('ecoresiduos.motivo', true), '')), '');
BEGIN
    IF NEW.estado_verificacion IS NOT DISTINCT FROM OLD.estado_verificacion THEN
        RETURN NEW;
    END IF;

    IF NEW.estado_verificacion::TEXT = 'APROBADO' THEN
        PERFORM private.notificar(NEW.usuario_id, 'GESTOR_APROBADO',
            'Aprobamos tu empresa. Ya ves las solicitudes de los materiales verificados.', NULL);
    ELSIF NEW.estado_verificacion::TEXT = 'RECHAZADO' THEN
        PERFORM private.notificar(NEW.usuario_id, 'GESTOR_RECHAZADO',
            CASE WHEN v_motivo IS NULL
                THEN 'No pudimos aprobar tu empresa. Escríbenos para revisar tu permiso ambiental.'
                ELSE format('No pudimos aprobar tu empresa. Motivo: %s', v_motivo)
            END,
            NULL);
    ELSIF NEW.estado_verificacion::TEXT = 'SUSPENDIDO' THEN
        PERFORM private.notificar(NEW.usuario_id, 'GESTOR_SUSPENDIDO',
            CASE WHEN v_motivo IS NULL
                THEN 'Suspendimos tu empresa: mientras tanto no ves solicitudes nuevas. Escríbenos para revisarlo.'
                ELSE format('Suspendimos tu empresa: mientras tanto no ves solicitudes nuevas. Motivo: %s', v_motivo)
            END,
            NULL);
    END IF;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.al_cambiar_verificacion_gestor() FROM PUBLIC, anon, authenticated;


-- 4. Aviso de materiales verificados a un gestor ya aprobado
-- Un aviso por gestor y por operación, aunque se verifiquen varios materiales.
-- Al aprobar una empresa el panel verifica sus materiales ANTES de cambiar el
-- estado, así que en ese momento aún no está APROBADO y solo llega el aviso de
-- aprobación.
CREATE OR REPLACE FUNCTION private.avisar_materiales_verificados(p_gestores JSONB)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
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
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_gestores JSONB;
BEGIN
    SELECT jsonb_object_agg(gestor_id::TEXT, cantidad) INTO v_gestores
    FROM (
        SELECT n.gestor_id, count(*) AS cantidad
        FROM nuevos n
        JOIN viejos v ON v.gestor_id = n.gestor_id AND v.material_id = n.material_id
        WHERE n.verificado AND NOT v.verificado
        GROUP BY n.gestor_id
    ) t;

    IF v_gestores IS NOT NULL THEN
        PERFORM private.avisar_materiales_verificados(v_gestores);
    END IF;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION private.al_agregar_materiales_verificados()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_gestores JSONB;
BEGIN
    SELECT jsonb_object_agg(gestor_id::TEXT, cantidad) INTO v_gestores
    FROM (
        SELECT n.gestor_id, count(*) AS cantidad
        FROM nuevos n
        WHERE n.verificado
        GROUP BY n.gestor_id
    ) t;

    IF v_gestores IS NOT NULL THEN
        PERFORM private.avisar_materiales_verificados(v_gestores);
    END IF;
    RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION
    private.avisar_materiales_verificados(JSONB),
    private.al_verificar_materiales(),
    private.al_agregar_materiales_verificados()
FROM PUBLIC, anon, authenticated;

-- Las tablas de transición no admiten lista de columnas ni varios eventos:
-- un trigger para UPDATE y otro para INSERT.
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
