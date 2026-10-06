-- ==============================================================================
-- Migración: Foto de perfil y portada
-- Fecha: 2026-10-06
-- Ejecutar DESPUÉS de 20261003000200_resolucion_problemas_reportados.sql
--
-- Cada usuario (generador o gestor) puede poner su foto de perfil. El gestor,
-- además, una portada: se ve detrás de su foto en la ficha del directorio. Las
-- dos son opcionales; sin foto la app muestra las iniciales.
--
-- Las fotos van al bucket público «fotos_perfil», dentro de la carpeta del
-- propio usuario (<uid>/perfil/… y <uid>/portada/…). La tabla guarda la ruta,
-- no la URL, y una restricción exige que la ruta sea de la carpeta del dueño
-- del perfil: nadie puede apuntar su perfil a la foto de otro ni a otro sitio.
--
-- Referencias (documentación oficial de Supabase y PostgreSQL):
--   Buckets:              https://supabase.com/docs/guides/storage/buckets/fundamentals
--   Políticas de Storage: https://supabase.com/docs/guides/storage/security/access-control
--   Funciones de Storage: https://supabase.com/docs/guides/storage/schema/helper-functions
--   Permisos por columna: https://www.postgresql.org/docs/current/sql-grant.html
-- ==============================================================================


-- 1. Columnas
ALTER TABLE public.perfiles_generador
ADD COLUMN IF NOT EXISTS foto_perfil_path TEXT;

ALTER TABLE public.perfiles_gestor
ADD COLUMN IF NOT EXISTS foto_perfil_path TEXT,
ADD COLUMN IF NOT EXISTS portada_path TEXT;

COMMENT ON COLUMN public.perfiles_generador.foto_perfil_path IS
    'Ruta de la foto de perfil en el bucket «fotos_perfil» (<uid>/perfil/<marca>.<ext>). NULL: sin foto.';
COMMENT ON COLUMN public.perfiles_gestor.foto_perfil_path IS
    'Ruta de la foto de perfil o logo en el bucket «fotos_perfil» (<uid>/perfil/<marca>.<ext>). NULL: sin foto.';
COMMENT ON COLUMN public.perfiles_gestor.portada_path IS
    'Ruta de la portada en el bucket «fotos_perfil» (<uid>/portada/<marca>.<ext>). NULL: sin portada.';


-- 2. La ruta debe estar en la carpeta del dueño del perfil
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


-- 3. Permiso para cambiar solo estas columnas
-- Igual que «municipio»: la política «editar el propio» limita la fila al
-- dueño y el GRANT por columna impide tocar las demás (por ejemplo,
-- estado_verificacion).
GRANT UPDATE (foto_perfil_path) ON public.perfiles_generador TO authenticated;
GRANT UPDATE (foto_perfil_path, portada_path) ON public.perfiles_gestor TO authenticated;


-- 4. Bucket público de fotos de perfil
-- La app reduce la foto de perfil a 512 px y la portada a 1600 px; quedan muy
-- por debajo de 2 MB. Público: la foto del gestor se ve en el directorio y la
-- URL se arma desde la ruta sin firmarla.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('fotos_perfil', 'fotos_perfil', TRUE, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Subir, leer (necesario para borrar) y borrar solo dentro de la carpeta
-- propia. Sin UPDATE: cada foto nueva lleva un nombre nuevo y la anterior se
-- borra, así la caché del teléfono nunca muestra una foto vieja.
DROP POLICY IF EXISTS "fotos_perfil: subir en carpeta propia" ON storage.objects;
CREATE POLICY "fotos_perfil: subir en carpeta propia"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'fotos_perfil'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
    AND (storage.foldername(name))[2] IN ('perfil', 'portada')
);

DROP POLICY IF EXISTS "fotos_perfil: leer carpeta propia" ON storage.objects;
CREATE POLICY "fotos_perfil: leer carpeta propia"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'fotos_perfil'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);

DROP POLICY IF EXISTS "fotos_perfil: borrar en carpeta propia" ON storage.objects;
CREATE POLICY "fotos_perfil: borrar en carpeta propia"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'fotos_perfil'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);
