-- ==============================================================================
-- Migración: Cancelar una solicitud desde el panel de administración
-- Fecha: 2026-10-03
-- Ejecutar DESPUÉS de 20261002000000_registro_gestor_nuevo.sql
--
-- El panel ya no deja poner cualquier estado a una solicitud (dejaba, por
-- ejemplo, RECOLECTADO sin fecha de recolección). La única acción
-- administrativa es cancelar, y hace lo mismo que cancelar_solicitud_generador
-- en una sola transacción: la solicitud pasa a CANCELADO y las postulaciones
-- que seguían en PROPUESTA pasan a RECHAZADA, para que ningún gestor quede
-- esperando una respuesta.
--
-- Avisos: la función marca la transacción con ecoresiduos.origen = 'ADMIN'
-- para que los triggers de 20260927000000 digan «EcoResiduos canceló…» en
-- lugar de «El generador canceló…», y además avisa al generador, que con la
-- cancelación desde la app no recibe aviso (fue él quien canceló).
--
-- Solo la ejecuta service_role (el servidor del panel).
--
-- Referencias (documentación oficial):
--   Funciones de base de datos: https://supabase.com/docs/guides/database/functions
--   set_config / current_setting: https://www.postgresql.org/docs/current/functions-admin.html#FUNCTIONS-ADMIN-SET
-- ==============================================================================


-- 1. Triggers de avisos: copia exacta de 20260927000000 salvo las ramas de
--    cancelación, que distinguen si canceló el administrador.
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
            CASE WHEN current_setting('ecoresiduos.origen', true) = 'ADMIN'
                THEN format('EcoResiduos canceló la solicitud de %s', v_material)
                ELSE format('El generador canceló la recolección de %s', v_material)
            END,
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
                CASE WHEN current_setting('ecoresiduos.origen', true) = 'ADMIN'
                    THEN format('EcoResiduos canceló la solicitud de %s', v_material)
                    ELSE format('El generador canceló la publicación de %s', v_material)
                END,
                NEW.solicitud_id);
        ELSE
            PERFORM private.notificar(v_gestor, 'POSTULACION_RECHAZADA',
                format('El generador no aceptó tu propuesta para %s', v_material), NEW.solicitud_id);
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION
    private.al_cambiar_solicitud(),
    private.al_cambiar_postulacion()
FROM PUBLIC, anon, authenticated;


-- 2. Función RPC del panel
CREATE OR REPLACE FUNCTION public.cancelar_solicitud_admin(
    p_solicitud_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_solicitud RECORD;
    v_rechazadas INTEGER;
BEGIN
    SELECT s.* INTO v_solicitud
    FROM solicitudes_recoleccion s
    WHERE s.id = p_solicitud_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud % no existe.', p_solicitud_id USING ERRCODE = 'P0002';
    END IF;

    IF v_solicitud.estado::TEXT NOT IN ('PUBLICADO', 'EN_NEGOCIACION') THEN
        RAISE EXCEPTION 'Solo se puede cancelar una solicitud publicada o en negociación (estado actual: %).', v_solicitud.estado;
    END IF;

    -- Solo para esta transacción: los triggers de avisos saben que canceló EcoResiduos.
    PERFORM set_config('ecoresiduos.origen', 'ADMIN', true);

    UPDATE solicitudes_recoleccion
    SET estado = 'CANCELADO',
        updated_at = NOW()
    WHERE id = p_solicitud_id;

    UPDATE postulaciones_recoleccion
    SET estado = 'RECHAZADA'
    WHERE solicitud_id = p_solicitud_id
      AND estado = 'PROPUESTA';
    GET DIAGNOSTICS v_rechazadas = ROW_COUNT;

    PERFORM private.notificar(
        private.usuario_generador(v_solicitud.generador_id),
        'SOLICITUD_CANCELADA',
        format('EcoResiduos canceló tu solicitud de %s. Si fue un error, puedes publicarla de nuevo.',
               private.nombre_material(v_solicitud.material_id)),
        p_solicitud_id
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'solicitud_id', p_solicitud_id,
        'postulaciones_rechazadas', v_rechazadas
    );
END;
$$;

REVOKE ALL ON FUNCTION public.cancelar_solicitud_admin(BIGINT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cancelar_solicitud_admin(BIGINT) TO service_role;
