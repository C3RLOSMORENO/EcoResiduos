-- ==============================================================================
-- Migración: Registro de gestores nuevos desde la app
-- Fecha: 2026-10-02
-- Ejecutar DESPUÉS de 20261001000000_valor_postulacion_y_certificado.sql
--
-- Un gestor nuevo llena sus datos, elige los materiales que recibe y adjunta
-- en PDF su licencia o permiso ambiental. La empresa queda PENDIENTE hasta que
-- el administrador revisa el permiso y la aprueba desde el admin-panel.
--
-- El PDF se sube ANTES de crear la cuenta (aún no hay sesión), así que el bucket
-- acepta subidas anónimas, solo PDF, solo en la carpeta registro/ y sin
-- lectura pública: únicamente el admin-panel (service_role) los abre.
--
-- Referencias (documentación oficial de Supabase):
--   Buckets:  https://supabase.com/docs/guides/storage/buckets/fundamentals
--   Políticas de Storage: https://supabase.com/docs/guides/storage/security/access-control
-- ==============================================================================


-- 1. Ruta del permiso en perfiles_gestor
ALTER TABLE public.perfiles_gestor
ADD COLUMN IF NOT EXISTS permiso_path TEXT;

COMMENT ON COLUMN public.perfiles_gestor.permiso_path IS
    'Ruta en el bucket privado «permisos» de la licencia o permiso ambiental que adjuntó el gestor al registrarse.';


-- 2. Bucket privado de permisos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('permisos', 'permisos', FALSE, 10485760, ARRAY['application/pdf'])
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Solo subir: sin SELECT, UPDATE ni DELETE nadie puede leer, reemplazar ni
-- borrar un permiso desde la app.
DROP POLICY IF EXISTS "permisos: subir al registrarse" ON storage.objects;
CREATE POLICY "permisos: subir al registrarse"
ON storage.objects FOR INSERT TO anon, authenticated
WITH CHECK (
    bucket_id = 'permisos'
    AND (storage.foldername(name))[1] = 'registro'
    AND lower(storage.extension(name)) = 'pdf'
);


-- 3. Vincular cuenta: ahora también crea la empresa de un registro nuevo
-- Igual que antes para las empresas ya registradas. Si la cuenta viene de un
-- registro nuevo (registro_nuevo = true en los metadatos), se crea la empresa
-- en estado PENDIENTE con el permiso adjunto. Se hace en el primer inicio de
-- sesión, con el correo ya confirmado, para no llenar el panel de cuentas falsas.
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
    v_nit TEXT;
    v_permiso TEXT;
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

    -- Cuentas creadas antes de guardar gestor_id, y registros nuevos ya
    -- creados en un inicio de sesión anterior: se busca la empresa por correo.
    v_gestor_id := (v_meta->>'gestor_id')::BIGINT;
    IF v_gestor_id IS NULL THEN
        SELECT id INTO v_gestor_id
        FROM perfiles_gestor
        WHERE lower(email_contacto) = lower(v_email)
          AND (usuario_id IS NULL OR usuario_id = v_uid)
        LIMIT 1;
    END IF;

    IF v_gestor_id IS NULL AND coalesce(v_meta->>'registro_nuevo', '') = 'true' THEN
        v_nit := regexp_replace(split_part(coalesce(v_meta->>'nit', ''), '-', 1), '[^0-9]', '', 'g');
        IF v_nit !~ '^[0-9]{8,15}$' THEN
            RAISE EXCEPTION 'El NIT del registro no es válido.';
        END IF;
        IF EXISTS (SELECT 1 FROM perfiles_gestor WHERE nit = v_nit) THEN
            RAISE EXCEPTION 'Ya hay una empresa registrada con el NIT %.', v_nit USING ERRCODE = '23505';
        END IF;

        v_permiso := v_meta->>'permiso_path';
        IF v_permiso IS NULL
           OR NOT EXISTS (
               SELECT 1 FROM storage.objects
               WHERE bucket_id = 'permisos' AND name = v_permiso AND name LIKE 'registro/%'
           )
           OR EXISTS (SELECT 1 FROM perfiles_gestor WHERE permiso_path = v_permiso) THEN
            RAISE EXCEPTION 'Falta el permiso ambiental en PDF del registro.';
        END IF;

        -- Coordenadas del centro de Bucaramanga, como en el admin-panel: se
        -- recalculan con la dirección cuando el administrador aprueba la empresa.
        INSERT INTO perfiles_gestor (
            nit, razon_social, representante_legal, telefono_contacto, email_contacto,
            direccion, municipio, horario, latitud, longitud, estado_verificacion, permiso_path
        )
        VALUES (
            v_nit,
            upper(left(trim(coalesce(v_meta->>'razon_social', '')), 200)),
            nullif(trim(coalesce(v_meta->>'representante_legal', '')), ''),
            trim(coalesce(v_meta->>'telefono', '')),
            lower(v_email),
            trim(coalesce(v_meta->>'direccion', '')),
            upper(trim(coalesce(v_meta->>'municipio', ''))),
            nullif(left(trim(coalesce(v_meta->>'horario', '')), 120), ''),
            7.119349,
            -73.122741,
            'PENDIENTE',
            v_permiso
        )
        RETURNING id INTO v_gestor_id;
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
        RAISE EXCEPTION 'El correo de la cuenta no coincide con el registrado para la empresa.' USING ERRCODE = '42501';
    END IF;

    UPDATE perfiles_gestor
    SET usuario_id = v_uid,
        telefono_contacto = coalesce(nullif(v_meta->>'telefono', ''), telefono_contacto),
        direccion = coalesce(nullif(v_meta->>'direccion', ''), direccion),
        municipio = coalesce(nullif(upper(v_meta->>'municipio'), ''), municipio)
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

REVOKE ALL ON FUNCTION vincular_cuenta_gestor() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION vincular_cuenta_gestor() TO authenticated;


-- 4. Aviso al gestor cuando el administrador aprueba o rechaza su empresa
CREATE OR REPLACE FUNCTION private.al_cambiar_verificacion_gestor()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NEW.estado_verificacion IS NOT DISTINCT FROM OLD.estado_verificacion THEN
        RETURN NEW;
    END IF;

    IF NEW.estado_verificacion::TEXT = 'APROBADO' THEN
        PERFORM private.notificar(NEW.usuario_id, 'GESTOR_APROBADO',
            'Aprobamos tu empresa. Ya ves las solicitudes de los materiales verificados.', NULL);
    ELSIF NEW.estado_verificacion::TEXT = 'RECHAZADO' THEN
        PERFORM private.notificar(NEW.usuario_id, 'GESTOR_RECHAZADO',
            'No pudimos aprobar tu empresa. Escríbenos para revisar tu permiso ambiental.', NULL);
    END IF;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.al_cambiar_verificacion_gestor() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS perfiles_gestor_aviso_verificacion ON public.perfiles_gestor;
CREATE TRIGGER perfiles_gestor_aviso_verificacion
AFTER UPDATE OF estado_verificacion ON public.perfiles_gestor
FOR EACH ROW EXECUTE FUNCTION private.al_cambiar_verificacion_gestor();


-- 5. Función RPC: el gestor elige los materiales que recibe
-- Recibe la lista completa. Los que quita se borran; los nuevos quedan sin
-- verificar hasta que el administrador los apruebe; los ya verificados siguen
-- verificados.
CREATE OR REPLACE FUNCTION actualizar_materiales_gestor(p_materiales BIGINT[])
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_gestor_id BIGINT;
    v_quitados INTEGER;
    v_nuevos INTEGER;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'No autenticado: Se requiere una sesión activa.' USING ERRCODE = '28000';
    END IF;

    v_gestor_id := private.mi_gestor_id();
    IF v_gestor_id IS NULL THEN
        RAISE EXCEPTION 'No autorizado: Solo un gestor puede elegir materiales.' USING ERRCODE = '42501';
    END IF;

    IF coalesce(cardinality(p_materiales), 0) = 0 THEN
        RAISE EXCEPTION 'Elige al menos un material.';
    END IF;

    DELETE FROM gestor_material
    WHERE gestor_id = v_gestor_id
      AND material_id <> ALL (p_materiales);
    GET DIAGNOSTICS v_quitados = ROW_COUNT;

    INSERT INTO gestor_material (gestor_id, material_id, verificado)
    SELECT v_gestor_id, m.id, FALSE
    FROM materiales_residuos m
    WHERE m.id = ANY (p_materiales)
      AND NOT EXISTS (
          SELECT 1 FROM gestor_material gm
          WHERE gm.gestor_id = v_gestor_id AND gm.material_id = m.id
      );
    GET DIAGNOSTICS v_nuevos = ROW_COUNT;

    RETURN jsonb_build_object('nuevos', v_nuevos, 'quitados', v_quitados);
END;
$$;

REVOKE ALL ON FUNCTION actualizar_materiales_gestor(BIGINT[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION actualizar_materiales_gestor(BIGINT[]) TO authenticated;
