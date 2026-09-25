# limpiar-fotos-huerfanas

Borra del bucket `escaneos_ia` las fotos que ya no referencia ninguna fila de
`solicitudes_recoleccion.foto_url` ni de `historial_escaneos_ia.imagen_path`.
Esto pasa, por ejemplo, cuando el generador cambia la foto de una publicación.
Solo toca archivos con más de 24 horas, para no borrar una subida en curso.

La app no borra la foto anterior al editar porque «Publicar de nuevo» y los
escaneos pueden compartir el mismo archivo.

## 1. Desplegar

Con la [CLI de Supabase](https://supabase.com/docs/guides/functions/deploy) enlazada al proyecto:

```bash
supabase secrets set LIMPIEZA_SECRETO=<una-cadena-larga-y-aleatoria>
supabase functions deploy limpiar-fotos-huerfanas --no-verify-jwt
```

`--no-verify-jwt` es porque la protege el secreto propio, no una sesión de usuario.
`SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` las pone Supabase automáticamente.

## 2. Probar sin borrar

```bash
curl -X POST "https://<proyecto>.supabase.co/functions/v1/limpiar-fotos-huerfanas?simular=1" \
  -H "x-limpieza-secreto: <el-mismo-secreto>"
```

Responde cuántas fotos revisó y cuáles borraría.

## 3. Programar una vez al día

En el SQL Editor, con las extensiones `pg_cron` y `pg_net` activas
(Database → Extensions). Guía oficial:
[Scheduling Edge Functions](https://supabase.com/docs/guides/functions/schedule-functions).

```sql
SELECT vault.create_secret('https://<proyecto>.supabase.co', 'url_proyecto');
SELECT vault.create_secret('<el-mismo-secreto>', 'limpieza_secreto');

SELECT cron.schedule(
    'limpiar-fotos-huerfanas',
    '0 4 * * *',  -- todos los días a las 4:00 UTC
    $$
    SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'url_proyecto')
               || '/functions/v1/limpiar-fotos-huerfanas',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-limpieza-secreto', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'limpieza_secreto')
        ),
        body := '{}'::jsonb
    );
    $$
);
```

Para quitarla: `SELECT cron.unschedule('limpiar-fotos-huerfanas');`
