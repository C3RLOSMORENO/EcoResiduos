-- ==============================================================================
-- Migración: Seguridad de datos (RLS), perfiles creados por el servidor e
-- integridad de postulaciones.
-- Fecha: 2026-09-25
-- Ejecutar DESPUÉS de 20260924000000_reglas_negocio_postulaciones_materiales.sql
--
-- Referencias (documentación oficial de Supabase):
--   RLS:                    https://supabase.com/docs/guides/database/postgres/row-level-security
--   Rendimiento de RLS:     https://supabase.com/docs/guides/troubleshooting/rls-performance-and-best-practices-Z5Jjwv
--   Seguridad por columnas: https://supabase.com/docs/guides/database/postgres/column-level-security
--   Perfiles con trigger:   https://supabase.com/docs/guides/auth/managing-user-data
--   Storage:                https://supabase.com/docs/guides/storage/security/access-control
--   updated_at:             https://supabase.com/docs/guides/database/extensions/moddatetime
--
-- El admin-panel usa la llave service_role, que no pasa por RLS: nada de esto
-- lo limita.
-- ==============================================================================


-- 1. Funciones auxiliares para las políticas
-- Van en un esquema que la API no expone. Son SECURITY DEFINER para que una
-- política de solicitudes pueda consultar postulaciones (y al revés) sin
-- entrar en recursión infinita.
CREATE SCHEMA IF NOT EXISTS private;
GRANT USAGE ON SCHEMA private TO authenticated;

CREATE OR REPLACE FUNCTION private.mi_generador_id()
RETURNS BIGINT
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT id::BIGINT FROM public.perfiles_generador
    WHERE usuario_id = (SELECT auth.uid())
    ORDER BY id
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION private.mi_gestor_id()
RETURNS BIGINT
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT id::BIGINT FROM public.perfiles_gestor
    WHERE usuario_id = (SELECT auth.uid())
    ORDER BY id
    LIMIT 1;
$$;

-- Materiales aprobados por el administrador para el gestor autenticado (regla 3).
CREATE OR REPLACE FUNCTION private.mis_materiales_verificados()
RETURNS SETOF BIGINT
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT gm.material_id::BIGINT
    FROM public.gestor_material gm
    JOIN public.perfiles_gestor pg ON pg.id = gm.gestor_id
    WHERE pg.usuario_id = (SELECT auth.uid())
      AND pg.estado_verificacion = 'APROBADO'
      AND gm.verificado;
$$;

CREATE OR REPLACE FUNCTION private.mis_solicitudes()
RETURNS SETOF BIGINT
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT s.id::BIGINT
    FROM public.solicitudes_recoleccion s
    JOIN public.perfiles_generador pg ON pg.id = s.generador_id
    WHERE pg.usuario_id = (SELECT auth.uid());
$$;

CREATE OR REPLACE FUNCTION private.mis_solicitudes_postuladas()
RETURNS SETOF BIGINT
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT pr.solicitud_id::BIGINT
    FROM public.postulaciones_recoleccion pr
    JOIN public.perfiles_gestor pg ON pg.id = pr.gestor_id
    WHERE pg.usuario_id = (SELECT auth.uid());
$$;

-- Solicitudes publicadas de materiales que el gestor autenticado tiene verificados.
CREATE OR REPLACE FUNCTION private.solicitudes_abiertas_para_mi()
RETURNS SETOF BIGINT
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
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


-- 2. Filas de usuarios y perfiles creadas por el servidor
-- Antes la app las escribía con datos de user_metadata, que el propio usuario
-- puede modificar (incluido el rol). Ahora las crea un trigger al registrarse y
-- los clientes no pueden escribir en `usuarios`.
CREATE OR REPLACE FUNCTION private.crear_perfil_nuevo_usuario()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_meta JSONB := coalesce(NEW.raw_user_meta_data, '{}'::jsonb);
    v_rol TEXT := upper(coalesce(v_meta->>'rol', 'GENERADOR'));
BEGIN
    -- ADMIN solo lo asigna un administrador desde el SQL Editor.
    IF v_rol NOT IN ('GENERADOR', 'GESTOR') THEN
        v_rol := 'GENERADOR';
    END IF;

    INSERT INTO public.usuarios (id, email, rol)
    VALUES (NEW.id, NEW.email, v_rol::public.rol_usuario)
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

-- Cuentas que ya existían: se completan con la misma regla.
INSERT INTO public.usuarios (id, email, rol)
SELECT
    u.id,
    u.email,
    (CASE WHEN upper(coalesce(u.raw_user_meta_data->>'rol', '')) = 'GESTOR' THEN 'GESTOR' ELSE 'GENERADOR' END)::public.rol_usuario
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.usuarios x WHERE x.id = u.id);

INSERT INTO public.perfiles_generador
    (usuario_id, nombre_completo_o_empresa, documento_nit, telefono, municipio, email)
SELECT
    u.id,
    coalesce(u.raw_user_meta_data->>'nombre_completo_o_empresa', ''),
    coalesce(u.raw_user_meta_data->>'documento_nit', ''),
    coalesce(u.raw_user_meta_data->>'telefono', ''),
    coalesce(u.raw_user_meta_data->>'municipio', ''),
    coalesce(u.email, '')
FROM auth.users u
JOIN public.usuarios x ON x.id = u.id AND x.rol = 'GENERADOR'
WHERE NOT EXISTS (SELECT 1 FROM public.perfiles_generador pg WHERE pg.usuario_id = u.id)
  AND NOT EXISTS (SELECT 1 FROM public.perfiles_gestor pg WHERE pg.usuario_id = u.id);


-- 3. Privilegios por tabla y columna
-- Supabase da por defecto todos los privilegios a anon y authenticated; se
-- dejan solo los que usa la app. Lo que no está aquí solo lo hace el servidor
-- (funciones RPC) o el admin-panel (service_role).
REVOKE ALL ON
    public.usuarios,
    public.perfiles_generador,
    public.perfiles_gestor,
    public.gestor_material,
    public.materiales_residuos,
    public.autoridades_ambientales,
    public.solicitudes_recoleccion,
    public.postulaciones_recoleccion,
    public.historial_escaneos_ia
FROM anon, authenticated;

-- Catálogo público: directorio, materiales y autoridades.
GRANT SELECT ON
    public.perfiles_gestor,
    public.gestor_material,
    public.materiales_residuos,
    public.autoridades_ambientales
TO anon, authenticated;

GRANT SELECT ON
    public.usuarios,
    public.perfiles_generador,
    public.solicitudes_recoleccion,
    public.postulaciones_recoleccion,
    public.historial_escaneos_ia
TO authenticated;

GRANT INSERT (
    generador_id, material_id, cantidad_estimada, unidad_medida, descripcion,
    direccion_recoleccion, municipio, telefono, estado, foto_url, latitud, longitud
) ON public.solicitudes_recoleccion TO authenticated;

GRANT UPDATE (
    material_id, cantidad_estimada, unidad_medida, descripcion,
    direccion_recoleccion, municipio, telefono, foto_url, latitud, longitud
) ON public.solicitudes_recoleccion TO authenticated;

GRANT INSERT (solicitud_id, gestor_id, estado, propuesta)
ON public.postulaciones_recoleccion TO authenticated;

GRANT INSERT (usuario_id, nombre_detectado, categoria_detectada, nivel_confianza, imagen_path)
ON public.historial_escaneos_ia TO authenticated;

GRANT UPDATE (municipio) ON public.perfiles_generador TO authenticated;
GRANT UPDATE (municipio) ON public.perfiles_gestor TO authenticated;


-- 4. Row Level Security
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfiles_generador ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfiles_gestor ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gestor_material ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materiales_residuos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.autoridades_ambientales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_recoleccion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.postulaciones_recoleccion ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historial_escaneos_ia ENABLE ROW LEVEL SECURITY;

-- Las políticas anteriores de estas tablas se reemplazan por el conjunto
-- completo de abajo. Como las políticas se suman con OR, una política vieja
-- demasiado abierta anularía las nuevas.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT policyname, tablename
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename IN (
              'usuarios', 'perfiles_generador', 'perfiles_gestor', 'gestor_material',
              'materiales_residuos', 'autoridades_ambientales', 'solicitudes_recoleccion',
              'postulaciones_recoleccion', 'historial_escaneos_ia'
          )
    LOOP
        EXECUTE format('DROP POLICY %I ON public.%I', r.policyname, r.tablename);
    END LOOP;
END $$;

-- usuarios: cada cuenta ve solo su fila. Sin escritura desde la app.
CREATE POLICY "usuarios: ver la propia"
ON public.usuarios FOR SELECT TO authenticated
USING (id = (SELECT auth.uid()));

-- perfiles_generador
CREATE POLICY "perfiles_generador: ver el propio"
ON public.perfiles_generador FOR SELECT TO authenticated
USING (usuario_id = (SELECT auth.uid()));

CREATE POLICY "perfiles_generador: editar el propio"
ON public.perfiles_generador FOR UPDATE TO authenticated
USING (usuario_id = (SELECT auth.uid()))
WITH CHECK (usuario_id = (SELECT auth.uid()));

-- perfiles_gestor: directorio público de empresas autorizadas.
CREATE POLICY "perfiles_gestor: directorio público"
ON public.perfiles_gestor FOR SELECT TO anon, authenticated
USING (true);

CREATE POLICY "perfiles_gestor: editar el propio"
ON public.perfiles_gestor FOR UPDATE TO authenticated
USING (usuario_id = (SELECT auth.uid()))
WITH CHECK (usuario_id = (SELECT auth.uid()));

-- Catálogo de solo lectura.
CREATE POLICY "gestor_material: lectura pública"
ON public.gestor_material FOR SELECT TO anon, authenticated
USING (true);

CREATE POLICY "materiales_residuos: lectura pública"
ON public.materiales_residuos FOR SELECT TO anon, authenticated
USING (true);

CREATE POLICY "autoridades_ambientales: lectura pública"
ON public.autoridades_ambientales FOR SELECT TO anon, authenticated
USING (true);

-- solicitudes_recoleccion
-- Las ven: su generador, el gestor asignado, los gestores que se postularon y,
-- mientras están publicadas, los gestores con el material verificado.
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
WITH CHECK (
    generador_id = (SELECT private.mi_generador_id())
    AND estado = 'PUBLICADO'
);

-- Editar solo mientras sigue publicada. Los cambios de estado van por RPC.
CREATE POLICY "solicitudes: editar la propia publicada"
ON public.solicitudes_recoleccion FOR UPDATE TO authenticated
USING (generador_id = (SELECT private.mi_generador_id()) AND estado = 'PUBLICADO')
WITH CHECK (generador_id = (SELECT private.mi_generador_id()) AND estado = 'PUBLICADO');

-- postulaciones_recoleccion
CREATE POLICY "postulaciones: ver las propias o las recibidas"
ON public.postulaciones_recoleccion FOR SELECT TO authenticated
USING (
    gestor_id = (SELECT private.mi_gestor_id())
    OR solicitud_id IN (SELECT private.mis_solicitudes())
);

-- Solo a solicitudes publicadas de un material que el gestor tiene verificado.
CREATE POLICY "postulaciones: postularse como gestor"
ON public.postulaciones_recoleccion FOR INSERT TO authenticated
WITH CHECK (
    gestor_id = (SELECT private.mi_gestor_id())
    AND estado = 'PROPUESTA'
    AND solicitud_id IN (SELECT private.solicitudes_abiertas_para_mi())
);

-- historial_escaneos_ia
CREATE POLICY "historial: ver el propio"
ON public.historial_escaneos_ia FOR SELECT TO authenticated
USING (usuario_id = (SELECT auth.uid()));

CREATE POLICY "historial: registrar el propio"
ON public.historial_escaneos_ia FOR INSERT TO authenticated
WITH CHECK (usuario_id = (SELECT auth.uid()));


-- 5. Storage: cada usuario sube fotos solo dentro de su carpeta (<uid>/archivo).
-- El bucket es público, así que la lectura por URL no necesita política.
DROP POLICY IF EXISTS "escaneos_ia: subir en carpeta propia" ON storage.objects;
CREATE POLICY "escaneos_ia: subir en carpeta propia"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'escaneos_ia'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);


-- 6. Índices para las columnas que usan las políticas y las consultas de la app
CREATE INDEX IF NOT EXISTS idx_perfiles_generador_usuario ON public.perfiles_generador (usuario_id);
CREATE INDEX IF NOT EXISTS idx_perfiles_gestor_usuario ON public.perfiles_gestor (usuario_id);
CREATE INDEX IF NOT EXISTS idx_solicitudes_generador ON public.solicitudes_recoleccion (generador_id);
CREATE INDEX IF NOT EXISTS idx_solicitudes_estado_material ON public.solicitudes_recoleccion (estado, material_id);
CREATE INDEX IF NOT EXISTS idx_solicitudes_gestor_asignado ON public.solicitudes_recoleccion (gestor_asignado_id);
CREATE INDEX IF NOT EXISTS idx_postulaciones_solicitud ON public.postulaciones_recoleccion (solicitud_id);
CREATE INDEX IF NOT EXISTS idx_postulaciones_gestor ON public.postulaciones_recoleccion (gestor_id);
CREATE INDEX IF NOT EXISTS idx_historial_usuario ON public.historial_escaneos_ia (usuario_id);


-- 7. Una sola postulación por gestor y solicitud
-- La app lee «mi postulación» como un único registro. Si ya hay duplicados no
-- se crea el índice y se avisa, para limpiarlos a mano antes.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.postulaciones_recoleccion
        GROUP BY solicitud_id, gestor_id
        HAVING count(*) > 1
    ) THEN
        RAISE NOTICE 'Hay postulaciones duplicadas (mismo gestor y solicitud): no se creó uq_postulacion_solicitud_gestor.';
    ELSE
        CREATE UNIQUE INDEX IF NOT EXISTS uq_postulacion_solicitud_gestor
        ON public.postulaciones_recoleccion (solicitud_id, gestor_id);
    END IF;
END $$;


-- 8. updated_at lo pone la base de datos, no el reloj del teléfono.
CREATE EXTENSION IF NOT EXISTS moddatetime SCHEMA extensions;

DROP TRIGGER IF EXISTS solicitudes_updated_at ON public.solicitudes_recoleccion;
CREATE TRIGGER solicitudes_updated_at
BEFORE UPDATE ON public.solicitudes_recoleccion
FOR EACH ROW EXECUTE PROCEDURE extensions.moddatetime(updated_at);
