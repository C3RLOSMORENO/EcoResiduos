-- ==============================================================================
-- Migración: Horarios de atención oficiales de Autoridades Ambientales
-- Fecha: 2026-09-28
-- ==============================================================================

ALTER TABLE public.autoridades_ambientales
ADD COLUMN IF NOT EXISTS horario TEXT CHECK (char_length(horario) <= 120);

-- 1. CDMB (Bucaramanga)
UPDATE public.autoridades_ambientales
SET horario = 'Lun-Vie 7:30 a.m. - 11:45 a.m. y 2:00 - 5:45 p.m.'
WHERE sigla = 'CDMB' OR id = 1;

-- 2. AMB (Área Metropolitana de Bucaramanga)
UPDATE public.autoridades_ambientales
SET horario = 'Lun-Jue 8:00 a.m. - 5:00 p.m. | Vie 8:00 a.m. - 4:00 p.m.'
WHERE sigla = 'AMB' OR id = 2;

-- 3. CAS (San Gil / Regional Santander)
UPDATE public.autoridades_ambientales
SET horario = 'Lun-Jue 8:00 a.m. - 12:00 m. y 2:00 - 6:00 p.m. | Vie 7:00 a.m. - 3:00 p.m.'
WHERE sigla = 'CAS' OR id = 3;
