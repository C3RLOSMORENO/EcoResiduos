-- ==============================================================================
-- Migración: Límites y permisos del bucket de fotos
-- Fecha: 2026-09-26
-- Ejecutar DESPUÉS de 20260925000000_seguridad_rls_y_perfiles.sql
--
-- Referencias (documentación oficial de Supabase):
--   Límites del bucket: https://supabase.com/docs/guides/storage/buckets/fundamentals
--   Políticas:          https://supabase.com/docs/guides/storage/security/access-control
-- ==============================================================================

-- La app reduce las fotos a 1600 px (unos 200–400 KB). El límite de 5 MB y los
-- tipos permitidos frenan subidas de otros archivos con la llave pública.
UPDATE storage.buckets
SET public = TRUE,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']
WHERE id = 'escaneos_ia';

-- Borrar requiere permiso de lectura y de borrado sobre el objeto. Ambos se
-- limitan a la carpeta del propio usuario (<uid>/...). La lectura pública de
-- las fotos va por URL y no depende de estas políticas.
DROP POLICY IF EXISTS "escaneos_ia: leer carpeta propia" ON storage.objects;
CREATE POLICY "escaneos_ia: leer carpeta propia"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'escaneos_ia'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);

DROP POLICY IF EXISTS "escaneos_ia: borrar en carpeta propia" ON storage.objects;
CREATE POLICY "escaneos_ia: borrar en carpeta propia"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'escaneos_ia'
    AND (storage.foldername(name))[1] = (SELECT auth.uid()::text)
);
