-- ==============================================================================
-- Migración: Resolver un problema reportado desde el panel
-- Fecha: 2026-10-03
-- Ejecutar DESPUÉS de 20261003000100_motivo_verificacion_y_avisos_gestor.sql
--
-- Cuando el generador reporta un problema, la app le dice «lo estamos
-- revisando». La única resolución que decidió el dueño del producto es
-- «Resuelto: no se recogió»: la solicitud vuelve a EN_NEGOCIACION con el mismo
-- gestor, se borra recolectado_at para que el gestor pueda marcarla de nuevo,
-- y se avisa al generador y al gestor. problema_detalle se conserva como
-- historia y problema_reportado vuelve a FALSE (un problema sin resolver es
-- problema_reportado = TRUE).
--
-- Solo la ejecuta service_role (el servidor del panel).
-- La app debe tener ícono para el tipo de aviso PROBLEMA_RESUELTO.
-- ==============================================================================

ALTER TABLE public.solicitudes_recoleccion
ADD COLUMN IF NOT EXISTS problema_resuelto_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS problema_resolucion TEXT,
ADD COLUMN IF NOT EXISTS problema_nota TEXT;

ALTER TABLE public.solicitudes_recoleccion
DROP CONSTRAINT IF EXISTS solicitudes_problema_resolucion_check;
ALTER TABLE public.solicitudes_recoleccion
ADD CONSTRAINT solicitudes_problema_resolucion_check
CHECK (problema_resolucion IN ('NO_RECOGIDO'));

ALTER TABLE public.solicitudes_recoleccion
DROP CONSTRAINT IF EXISTS solicitudes_problema_nota_check;
ALTER TABLE public.solicitudes_recoleccion
ADD CONSTRAINT solicitudes_problema_nota_check
CHECK (char_length(problema_nota) <= 300);

COMMENT ON COLUMN public.solicitudes_recoleccion.problema_resuelto_at IS
    'Cuándo el administrador resolvió el último problema reportado.';
COMMENT ON COLUMN public.solicitudes_recoleccion.problema_resolucion IS
    'NO_RECOGIDO: el residuo no se recogió y la solicitud volvió a EN_NEGOCIACION.';
COMMENT ON COLUMN public.solicitudes_recoleccion.problema_nota IS
    'Nota del administrador que se agregó a los avisos del generador y del gestor.';

CREATE INDEX IF NOT EXISTS idx_solicitudes_problemas_sin_resolver
ON public.solicitudes_recoleccion (created_at DESC)
WHERE problema_reportado;

-- Los clientes de la app no escriben estas columnas: solo el servidor.
REVOKE UPDATE (problema_resuelto_at, problema_resolucion, problema_nota)
ON public.solicitudes_recoleccion FROM anon, authenticated;


CREATE OR REPLACE FUNCTION public.resolver_problema_no_recogido(
    p_solicitud_id BIGINT,
    p_nota TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_solicitud RECORD;
    v_nota TEXT := nullif(left(trim(coalesce(p_nota, '')), 300), '');
    v_material TEXT;
    v_razon_social TEXT;
    v_cola TEXT;
BEGIN
    SELECT s.* INTO v_solicitud
    FROM solicitudes_recoleccion s
    WHERE s.id = p_solicitud_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud % no existe.', p_solicitud_id USING ERRCODE = 'P0002';
    END IF;

    IF NOT v_solicitud.problema_reportado
       OR v_solicitud.confirmado_at IS NOT NULL
       OR v_solicitud.estado::TEXT <> 'RECOLECTADO' THEN
        RAISE EXCEPTION 'Solo se puede resolver un problema reportado en una recolección marcada como recolectada y sin confirmar.';
    END IF;

    UPDATE solicitudes_recoleccion
    SET estado = 'EN_NEGOCIACION',
        recolectado_at = NULL,
        problema_reportado = FALSE,
        problema_resuelto_at = NOW(),
        problema_resolucion = 'NO_RECOGIDO',
        problema_nota = v_nota,
        updated_at = NOW()
    WHERE id = p_solicitud_id;

    v_material := private.nombre_material(v_solicitud.material_id);
    SELECT razon_social INTO v_razon_social
    FROM perfiles_gestor WHERE id = v_solicitud.gestor_asignado_id;
    v_cola := CASE WHEN v_nota IS NULL THEN '' ELSE format(' Nota: %s', v_nota) END;

    PERFORM private.notificar(
        private.usuario_generador(v_solicitud.generador_id),
        'PROBLEMA_RESUELTO',
        format('Revisamos el problema con la recolección de %s: el residuo no se recogió. %s debe volver a coordinar la recogida.%s',
               v_material, coalesce(v_razon_social, 'El gestor'), v_cola),
        p_solicitud_id
    );

    PERFORM private.notificar(
        private.usuario_gestor(v_solicitud.gestor_asignado_id),
        'PROBLEMA_RESUELTO',
        format('Revisamos el problema con la recolección de %s: el residuo no se recogió. Coordina de nuevo la recogida con el generador.%s',
               v_material, v_cola),
        p_solicitud_id
    );

    RETURN jsonb_build_object('success', TRUE, 'solicitud_id', p_solicitud_id);
END;
$$;

REVOKE ALL ON FUNCTION public.resolver_problema_no_recogido(BIGINT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.resolver_problema_no_recogido(BIGINT, TEXT) TO service_role;
