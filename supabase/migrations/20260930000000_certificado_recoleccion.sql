-- Añadir columna de certificado de recolección
ALTER TABLE solicitudes_recoleccion
ADD COLUMN certificado_url TEXT;

COMMENT ON COLUMN solicitudes_recoleccion.certificado_url IS 'URL del PDF (Certificado de recolección o manifiesto de carga) subido por el gestor ambiental.';
