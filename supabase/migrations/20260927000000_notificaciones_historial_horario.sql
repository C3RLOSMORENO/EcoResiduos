-- ==============================================================================
-- Migración: Notificaciones, historial de estados y horario de los gestores
-- Fecha: 2026-09-27
-- Ejecutar DESPUÉS de 20260926000000_storage_fotos.sql
--
-- Las notificaciones y el historial los escriben triggers del servidor: los
-- clientes solo leen, marcan como leída o descartan las propias.
--
-- Referencias (documentación oficial de Supabase):
--   Triggers:               https://supabase.com/docs/guides/database/postgres/triggers
--   RLS:                    https://supabase.com/docs/guides/database/postgres/row-level-security
--   Seguridad por columnas: https://supabase.com/docs/guides/database/postgres/column-level-security
-- ==============================================================================


-- 1. Horario de atención de los gestores (lo edita el admin-panel)
ALTER TABLE public.perfiles_gestor
ADD COLUMN IF NOT EXISTS horario TEXT CHECK (char_length(horario) <= 120);


-- 2. Historial de estados de cada solicitud
CREATE TABLE IF NOT EXISTS public.solicitudes_historial_estados (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    solicitud_id BIGINT NOT NULL REFERENCES public.solicitudes_recoleccion (id) ON DELETE CASCADE,
    estado TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_historial_estados_solicitud
ON public.solicitudes_historial_estados (solicitud_id, created_at);

-- Solicitudes que ya existían: se reconstruye lo que las columnas permiten.
-- La fecha de «En negociación» de las que ya se recolectaron no se guardó.
INSERT INTO public.solicitudes_historial_estados (solicitud_id, estado, created_at)
SELECT e.solicitud_id, e.estado, e.fecha
FROM (
    SELECT s.id AS solicitud_id, 'PUBLICADO' AS estado, s.created_at AS fecha
    FROM public.solicitudes_recoleccion s
    UNION ALL
    SELECT s.id, s.estado::TEXT, coalesce(s.updated_at, s.created_at)
    FROM public.solicitudes_recoleccion s
    WHERE s.estado::TEXT IN ('EN_NEGOCIACION', 'CANCELADO')
    UNION ALL
    SELECT s.id, 'RECOLECTADO', s.recolectado_at
    FROM public.solicitudes_recoleccion s
    WHERE s.recolectado_at IS NOT NULL
) e
WHERE e.fecha IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM public.solicitudes_historial_estados h WHERE h.solicitud_id = e.solicitud_id
  );


-- 3. Notificaciones por usuario
CREATE TABLE IF NOT EXISTS public.notificaciones (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    tipo TEXT NOT NULL,
    titulo TEXT NOT NULL,
    solicitud_id BIGINT REFERENCES public.solicitudes_recoleccion (id) ON DELETE CASCADE,
    leida_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario
ON public.notificaciones (usuario_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notificaciones_no_leidas
ON public.notificaciones (usuario_id)
WHERE leida_at IS NULL;


-- 4. Funciones que escriben historial y notificaciones
CREATE OR REPLACE FUNCTION private.notificar(
    p_usuario_id UUID,
    p_tipo TEXT,
    p_titulo TEXT,
    p_solicitud_id BIGINT
)
RETURNS VOID
LANGUAGE sql SECURITY DEFINER
SET search_path = ''
AS $$
    -- Las empresas del padrón sin cuenta vinculada no tienen usuario.
    INSERT INTO public.notificaciones (usuario_id, tipo, titulo, solicitud_id)
    SELECT p_usuario_id, p_tipo, p_titulo, p_solicitud_id
    WHERE p_usuario_id IS NOT NULL;
$$;

-- Nombre del material en minúscula inicial, para usarlo dentro de una frase.
CREATE OR REPLACE FUNCTION private.nombre_material(p_material_id BIGINT)
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT coalesce(
        (SELECT lower(left(m.nombre_comun, 1)) || substr(m.nombre_comun, 2)
         FROM public.materiales_residuos m WHERE m.id = p_material_id),
        'residuo'
    );
$$;

CREATE OR REPLACE FUNCTION private.usuario_generador(p_generador_id BIGINT)
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT usuario_id FROM public.perfiles_generador WHERE id = p_generador_id;
$$;

CREATE OR REPLACE FUNCTION private.usuario_gestor(p_gestor_id BIGINT)
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT usuario_id FROM public.perfiles_gestor WHERE id = p_gestor_id;
$$;

CREATE OR REPLACE FUNCTION private.al_cambiar_solicitud()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_material TEXT := private.nombre_material(NEW.material_id);
    v_generador UUID := private.usuario_generador(NEW.generador_id);
    v_gestor UUID := private.usuario_gestor(NEW.gestor_asignado_id);
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
        PERFORM private.notificar(
            v_generador,
            'RECOLECCION_MARCADA',
            format('%s marcó como recolectado tu %s. Confírmalo o reporta un problema.',
                   coalesce(v_razon_social, 'El gestor'), v_material),
            NEW.id
        );
    END IF;

    IF NEW.estado IS DISTINCT FROM OLD.estado AND NEW.estado::TEXT = 'CANCELADO' THEN
        PERFORM private.notificar(
            v_gestor,
            'SOLICITUD_CANCELADA',
            format('El generador canceló la recolección de %s', v_material),
            NEW.id
        );
    END IF;

    IF OLD.confirmado_at IS NULL AND NEW.confirmado_at IS NOT NULL THEN
        PERFORM private.notificar(
            v_gestor,
            'RECOLECCION_CONFIRMADA',
            format('Se confirmó la recolección de %s', v_material),
            NEW.id
        );
    END IF;

    IF NOT OLD.problema_reportado AND NEW.problema_reportado THEN
        PERFORM private.notificar(
            v_gestor,
            'PROBLEMA_REPORTADO',
            format('El generador reportó un problema con la recolección de %s', v_material),
            NEW.id
        );
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.al_cambiar_postulacion()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_solicitud RECORD;
    v_material TEXT;
    v_gestor UUID := private.usuario_gestor(NEW.gestor_id);
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
            NEW.solicitud_id
        );
        RETURN NEW;
    END IF;

    IF NEW.estado IS NOT DISTINCT FROM OLD.estado THEN
        RETURN NEW;
    END IF;

    IF NEW.estado::TEXT = 'ACEPTADA' THEN
        PERFORM private.notificar(v_gestor, 'POSTULACION_ACEPTADA',
            format('Te aceptaron la recolección de %s', v_material), NEW.solicitud_id);
    ELSIF NEW.estado::TEXT = 'NO_SELECCIONADA' THEN
        PERFORM private.notificar(v_gestor, 'POSTULACION_NO_SELECCIONADA',
            format('La solicitud de %s fue asignada a otro gestor', v_material), NEW.solicitud_id);
    ELSIF NEW.estado::TEXT = 'RECHAZADA' THEN
        -- Al cancelar, la solicitud ya quedó CANCELADO antes de rechazar las propuestas.
        IF v_solicitud.estado = 'CANCELADO' THEN
            PERFORM private.notificar(v_gestor, 'SOLICITUD_CANCELADA',
                format('El generador canceló la publicación de %s', v_material), NEW.solicitud_id);
        ELSE
            PERFORM private.notificar(v_gestor, 'POSTULACION_RECHAZADA',
                format('El generador no aceptó tu propuesta para %s', v_material), NEW.solicitud_id);
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION
    private.notificar(UUID, TEXT, TEXT, BIGINT),
    private.nombre_material(BIGINT),
    private.usuario_generador(BIGINT),
    private.usuario_gestor(BIGINT),
    private.al_cambiar_solicitud(),
    private.al_cambiar_postulacion()
FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS solicitudes_historial_y_avisos ON public.solicitudes_recoleccion;
CREATE TRIGGER solicitudes_historial_y_avisos
AFTER INSERT OR UPDATE ON public.solicitudes_recoleccion
FOR EACH ROW EXECUTE FUNCTION private.al_cambiar_solicitud();

DROP TRIGGER IF EXISTS postulaciones_avisos ON public.postulaciones_recoleccion;
CREATE TRIGGER postulaciones_avisos
AFTER INSERT OR UPDATE OF estado ON public.postulaciones_recoleccion
FOR EACH ROW EXECUTE FUNCTION private.al_cambiar_postulacion();


-- 5. Permisos y políticas
REVOKE ALL ON public.solicitudes_historial_estados, public.notificaciones FROM anon, authenticated;

GRANT SELECT ON public.solicitudes_historial_estados TO authenticated;
GRANT SELECT, DELETE ON public.notificaciones TO authenticated;
GRANT UPDATE (leida_at) ON public.notificaciones TO authenticated;

ALTER TABLE public.solicitudes_historial_estados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "historial_estados: ver el de mis solicitudes" ON public.solicitudes_historial_estados;
CREATE POLICY "historial_estados: ver el de mis solicitudes"
ON public.solicitudes_historial_estados FOR SELECT TO authenticated
USING (
    solicitud_id IN (SELECT private.mis_solicitudes())
    OR solicitud_id IN (SELECT private.mis_solicitudes_postuladas())
);

DROP POLICY IF EXISTS "notificaciones: ver las propias" ON public.notificaciones;
CREATE POLICY "notificaciones: ver las propias"
ON public.notificaciones FOR SELECT TO authenticated
USING (usuario_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "notificaciones: marcar las propias" ON public.notificaciones;
CREATE POLICY "notificaciones: marcar las propias"
ON public.notificaciones FOR UPDATE TO authenticated
USING (usuario_id = (SELECT auth.uid()))
WITH CHECK (usuario_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "notificaciones: descartar las propias" ON public.notificaciones;
CREATE POLICY "notificaciones: descartar las propias"
ON public.notificaciones FOR DELETE TO authenticated
USING (usuario_id = (SELECT auth.uid()));


-- 6. Tiempo real para el contador de la campana
-- Realtime aplica las mismas políticas: cada usuario recibe solo sus avisos.
-- https://supabase.com/docs/guides/realtime/postgres-changes
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notificaciones'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notificaciones;
    END IF;
END $$;
