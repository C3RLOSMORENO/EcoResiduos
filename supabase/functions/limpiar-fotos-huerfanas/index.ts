// Borra del bucket `escaneos_ia` las fotos que ninguna publicación ni escaneo
// referencia (p. ej. las que se reemplazaron al editar una publicación).
//
// La llama pg_cron una vez al día (ver README.md). Solo responde si trae el
// encabezado `x-limpieza-secreto` con el valor del secreto LIMPIEZA_SECRETO.
// Con `?simular=1` devuelve lo que borraría sin borrar nada.
//
// Docs: https://supabase.com/docs/guides/functions/schedule-functions
//       https://supabase.com/docs/reference/javascript/storage-from-remove

import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

const BUCKET = 'escaneos_ia';
const MARCA_URL = `/storage/v1/object/public/${BUCKET}/`;
const TAMANO_PAGINA = 1000;
const TAMANO_LOTE = 100;

// Margen para no borrar una foto que se acaba de subir y cuya fila aún no existe.
const ANTIGUEDAD_MINIMA_MS = 24 * 60 * 60 * 1000;

interface Archivo {
  ruta: string;
  creado: number;
}

function rutaEnBucket(url: string | null): string | null {
  if (!url) return null;
  const inicio = url.indexOf(MARCA_URL);
  if (inicio < 0) return null;
  return decodeURIComponent(url.slice(inicio + MARCA_URL.length).split('?')[0]);
}

async function listarArchivos(supabase: SupabaseClient, carpeta = ''): Promise<Archivo[]> {
  const archivos: Archivo[] = [];
  for (let offset = 0; ; offset += TAMANO_PAGINA) {
    const { data, error } = await supabase.storage
      .from(BUCKET)
      .list(carpeta, { limit: TAMANO_PAGINA, offset });
    if (error) throw error;

    for (const item of data) {
      const ruta = carpeta ? `${carpeta}/${item.name}` : item.name;
      // Las carpetas vienen sin id.
      if (item.id === null) {
        archivos.push(...(await listarArchivos(supabase, ruta)));
      } else {
        archivos.push({ ruta, creado: Date.parse(item.created_at ?? '') || Date.now() });
      }
    }
    if (data.length < TAMANO_PAGINA) return archivos;
  }
}

async function rutasReferenciadas(
  supabase: SupabaseClient,
  tabla: string,
  columna: string,
): Promise<Set<string>> {
  const rutas = new Set<string>();
  for (let desde = 0; ; desde += TAMANO_PAGINA) {
    const { data, error } = await supabase
      .from(tabla)
      .select(columna)
      .not(columna, 'is', null)
      .range(desde, desde + TAMANO_PAGINA - 1);
    if (error) throw error;

    // La columna llega por parámetro, así que el cliente no puede inferir el tipo de la fila.
    for (const fila of data as unknown as Record<string, string | null>[]) {
      const ruta = rutaEnBucket(fila[columna]);
      if (ruta) rutas.add(ruta);
    }
    if (data.length < TAMANO_PAGINA) return rutas;
  }
}

Deno.serve(async (req) => {
  const secreto = Deno.env.get('LIMPIEZA_SECRETO');
  if (!secreto || req.headers.get('x-limpieza-secreto') !== secreto) {
    return new Response('No autorizado', { status: 401 });
  }

  const simular = new URL(req.url).searchParams.get('simular') === '1';
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  try {
    const [archivos, deSolicitudes, deEscaneos] = await Promise.all([
      listarArchivos(supabase),
      rutasReferenciadas(supabase, 'solicitudes_recoleccion', 'foto_url'),
      rutasReferenciadas(supabase, 'historial_escaneos_ia', 'imagen_path'),
    ]);

    const limite = Date.now() - ANTIGUEDAD_MINIMA_MS;
    const huerfanas = archivos
      .filter((a) => a.creado < limite && !deSolicitudes.has(a.ruta) && !deEscaneos.has(a.ruta))
      .map((a) => a.ruta);

    if (!simular) {
      for (let i = 0; i < huerfanas.length; i += TAMANO_LOTE) {
        const { error } = await supabase.storage.from(BUCKET).remove(huerfanas.slice(i, i + TAMANO_LOTE));
        if (error) throw error;
      }
    }

    return Response.json({
      revisadas: archivos.length,
      [simular ? 'se_borrarian' : 'borradas']: huerfanas.length,
      ...(simular ? { rutas: huerfanas } : {}),
    });
  } catch (error) {
    console.error('Limpieza de fotos fallida', error);
    return Response.json({ error: 'No se pudo completar la limpieza' }, { status: 500 });
  }
});
