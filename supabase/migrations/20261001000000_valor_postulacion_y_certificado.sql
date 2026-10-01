-- ==============================================================================
-- Migración: Valor económico de la postulación y certificado del gestor
-- Fecha: 2026-10-01
-- Ejecutar DESPUÉS de 20260930000000_certificado_recoleccion.sql
--
-- 1. Al postularse, el gestor indica uno de dos valores:
--    - COBRO_RECOLECCION:    valor cobrado por recolección externa (paga el generador).
--    - PAGO_APROVECHAMIENTO: valor pagado por aprovechamiento (paga el gestor).
-- 2. Al terminar, el gestor carga en PDF el certificado de disposición final o
--    de aprovechamiento, y el generador lo descarga desde la app.
--
-- Referencias (documentación oficial de Supabase):
--   Buckets:  https://supabase.com/docs/guides/storage/buckets/fundamentals
--   Políticas de Storage: https://supabase.com/docs/guides/storage/security/access-control
-- ==============================================================================


-- 1. Valor propuesto por el gestor
-- Pesos colombianos sin decimales. 0 es válido (recolección sin costo).
ALTER TABLE public.postulaciones_recoleccion
ADD COLUMN IF NOT EXISTS tipo_valor TEXT,
ADD COLUMN IF NOT EXISTS valor BIGINT;

ALTER TABLE public.postulaciones_recoleccion
DROP CONSTRAINT IF EXISTS postulaciones_tipo_valor_check;
ALTER TABLE public.postulaciones_recoleccion
ADD CONSTRAINT postulaciones_tipo_valor_check
CHECK (tipo_valor IN ('COBRO_RECOLECCION', 'PAGO_APROVECHAMIENTO'));

-- Las postulaciones anteriores a esta migración no tienen valor; las nuevas
-- deben traer los dos campos juntos.
ALTER TABLE public.postulaciones_recoleccion
DROP CONSTRAINT IF EXISTS postulaciones_valor_check;
ALTER TABLE public.postulaciones_recoleccion
ADD CONSTRAINT postulaciones_valor_check
CHECK (
    (tipo_valor IS NULL AND valor IS NULL)
    OR (tipo_valor IS NOT NULL AND valor BETWEEN 0 AND 1000000000)
);

COMMENT ON COLUMN public.postulaciones_recoleccion.tipo_valor IS
    'COBRO_RECOLECCION: valor cobrado por recolección externa. PAGO_APROVECHAMIENTO: valor pagado por aprovechamiento.';
COMMENT ON COLUMN public.postulaciones_recoleccion.valor IS 'Valor en pesos colombianos (COP), sin decimales.';

GRANT INSERT (tipo_valor, valor) ON public.postulaciones_recoleccion TO authenticated;

DROP POLICY IF EXISTS "postulaciones: postularse como gestor" ON public.postulaciones_recoleccion;
CREATE POLICY "postulaciones: postularse como gestor"
ON public.postulaciones_recoleccion FOR INSERT TO authenticated
WITH CHECK (
    gestor_id = (SELECT private.mi_gestor_id())
    AND estado = 'PROPUESTA'
    AND tipo_valor IS NOT NULL
    AND valor IS NOT NULL
    AND solicitud_id IN (SELECT private.solicitudes_abiertas_para_mi())
);


-- 2. Datos del certificado en la solicitud
-- certificado_url ya existe (20260930000000_certificado_recoleccion.sql).
ALTER TABLE public.solicitudes_recoleccion
ADD COLUMN IF NOT EXISTS certificado_url TEXT,
ADD COLUMN IF NOT EXISTS certificado_tipo TEXT,
ADD COLUMN IF NOT EXISTS certificado_at TIMESTAMPTZ;

ALTER TABLE public.solicitudes_recoleccion
DROP CONSTRAINT IF EXISTS solicitudes_certificado_tipo_check;
ALTER TABLE public.solicitudes_recoleccion
ADD CONSTRAINT solicitudes_certificado_tipo_check
CHECK (certificado_tipo IN ('DISPOSICION_FINAL', 'APROVECHAMIENTO'));

COMMENT ON COLUMN public.solicitudes_recoleccion.certificado_tipo IS
    'DISPOSICION_FINAL o APROVECHAMIENTO, según el certificado que cargó el gestor.';


-- 3. Bucket de certificados
-- Público como el de fotos: el admin-panel enlaza la URL directamente. Cada
-- archivo queda en <uid del gestor>/<id solicitud>/<marca de tiempo>.pdf.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('certificados', 'certificados', TRUE, 10485760, ARRAY['application/pdf'])
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "certificados: subir en carpeta propia" ON storage.objects;
CREATE POLICY "certificados: subir en carpeta propia"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'certificados'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);

DROP POLICY IF EXISTS "certificados: leer carpeta propia" ON storage.objects;
CREATE POLICY "certificados: leer carpeta propia"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'certificados'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);

DROP POLICY IF EXISTS "certificados: borrar en carpeta propia" ON storage.objects;
CREATE POLICY "certificados: borrar en carpeta propia"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'certificados'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);


-- 4. Función RPC: el gestor asignado carga (o reemplaza) el certificado
-- Solo después de marcar la recolección. Devuelve la URL anterior para que la
-- app borre el archivo reemplazado.
CREATE OR REPLACE FUNCTION cargar_certificado_gestor(
    p_solicitud_id BIGINT,
    p_url TEXT,
    p_tipo TEXT
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

    SELECT * INTO v_solicitud
    FROM solicitudes_recoleccion
    WHERE id = p_solicitud_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud % no existe.', p_solicitud_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM postulaciones_recoleccion pr
        JOIN perfiles_gestor pg ON pg.id = pr.gestor_id
        WHERE pr.solicitud_id = p_solicitud_id
          AND pr.estado = 'ACEPTADA'
          AND pg.usuario_id = v_uid
    ) THEN
        RAISE EXCEPTION 'No autorizado: Solo el gestor asignado puede cargar el certificado.'
        USING ERRCODE = '42501';
    END IF;

    IF v_solicitud.recolectado_at IS NULL THEN
        RAISE EXCEPTION 'Operación inválida: Marca primero la recolección.';
    END IF;

    IF p_tipo NOT IN ('DISPOSICION_FINAL', 'APROVECHAMIENTO') THEN
        RAISE EXCEPTION 'Tipo de certificado no válido: %.', p_tipo;
    END IF;

    -- El archivo debe estar en el bucket de certificados, dentro de la carpeta
    -- del propio gestor: así nadie enlaza un archivo ajeno.
    IF position('/storage/v1/object/public/certificados/' || v_uid::text || '/' IN p_url) = 0
       OR right(lower(p_url), 4) <> '.pdf' THEN
        RAISE EXCEPTION 'El certificado debe ser un PDF subido por el gestor asignado.';
    END IF;

    UPDATE solicitudes_recoleccion
    SET certificado_url = p_url,
        certificado_tipo = p_tipo,
        certificado_at = NOW()
    WHERE id = p_solicitud_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'solicitud_id', p_solicitud_id,
        'anterior', v_solicitud.certificado_url
    );
END;
$$;

REVOKE ALL ON FUNCTION cargar_certificado_gestor(BIGINT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION cargar_certificado_gestor(BIGINT, TEXT, TEXT) TO authenticated;


-- 5. Aviso al generador cuando el certificado queda disponible
CREATE OR REPLACE FUNCTION private.al_cargar_certificado()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_razon_social TEXT;
    v_documento TEXT;
BEGIN
    IF NEW.certificado_url IS NULL OR NEW.certificado_url IS NOT DISTINCT FROM OLD.certificado_url THEN
        RETURN NEW;
    END IF;

    SELECT razon_social INTO v_razon_social
    FROM public.perfiles_gestor WHERE id = NEW.gestor_asignado_id;

    v_documento := CASE NEW.certificado_tipo
        WHEN 'APROVECHAMIENTO' THEN 'el certificado de aprovechamiento'
        ELSE 'el certificado de disposición final'
    END;

    PERFORM private.notificar(
        private.usuario_generador(NEW.generador_id),
        'CERTIFICADO_CARGADO',
        format('%s cargó %s de tu %s', coalesce(v_razon_social, 'El gestor'), v_documento,
               private.nombre_material(NEW.material_id)),
        NEW.id
    );
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.al_cargar_certificado() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS solicitudes_aviso_certificado ON public.solicitudes_recoleccion;
CREATE TRIGGER solicitudes_aviso_certificado
AFTER UPDATE OF certificado_url ON public.solicitudes_recoleccion
FOR EACH ROW EXECUTE FUNCTION private.al_cargar_certificado();
