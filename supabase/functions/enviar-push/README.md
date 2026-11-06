# enviar-push

Manda al teléfono cada notificación que la base guarda en `notificaciones`
(oferta nueva, recolección marcada, certificado cargado, gestor aprobado…).
Usa Firebase Cloud Messaging. Con la app cerrada o en segundo plano, Android
la muestra en la barra de notificaciones y al tocarla se abre la pantalla de
novedades. Con la app abierta no sale nada extra, porque la campana ya se
actualiza en tiempo real.

Cómo funciona:

1. Al entrar con sesión, la app pide el permiso de notificaciones y guarda el
   token del teléfono con `registrar_dispositivo_push`. Al cerrar sesión lo
   borra con `quitar_dispositivo_push`.
2. El trigger `notificaciones_enviar_push` llama a esta función con pg_net
   cada vez que se crea una notificación de un usuario con teléfono
   registrado.
3. La función lee la notificación y los tokens del usuario, y los envía a
   Firebase. Los tokens que Firebase da por vencidos se borran.

Mientras falte cualquiera de los pasos de abajo, las notificaciones siguen
saliendo dentro de la app como hasta ahora.

Por ahora es solo para Android. En iPhone hace falta además una llave APNs
de una cuenta de Apple Developer.

## 1. Crear el proyecto de Firebase

1. En <https://console.firebase.google.com>, crea un proyecto (Analytics no
   hace falta).
2. Agrega una app Android con el paquete `co.edu.udes.ecoresiduos` y descarga
   `google-services.json`. No hay que guardarlo en el repositorio.
3. Copia estos cuatro valores del archivo a
   [`app/lib/config/firebase_config.dart`](../../../app/lib/config/firebase_config.dart):

   | Constante | En google-services.json |
   |---|---|
   | `apiKey` | `client[0].api_key[0].current_key` |
   | `appId` | `client[0].client_info.mobilesdk_app_id` |
   | `messagingSenderId` | `project_info.project_number` |
   | `projectId` | `project_info.project_id` |

   Pueden ir en el código: solo identifican el proyecto. Para enviar hace
   falta la cuenta de servicio del paso 2, que no va en la app.

## 2. Desplegar la función

En Firebase: Configuración del proyecto → Cuentas de servicio → Generar nueva
clave privada. Descarga un JSON; **ese archivo sí es secreto**.

Con la [CLI de Supabase](https://supabase.com/docs/guides/functions/deploy)
enlazada al proyecto:

```bash
supabase secrets set PUSH_SECRETO=<una-cadena-larga-y-aleatoria>
supabase secrets set FIREBASE_CUENTA_SERVICIO="$(cat ruta/a/la-cuenta-de-servicio.json)"
supabase functions deploy enviar-push --no-verify-jwt
```

`--no-verify-jwt` es porque la protege `PUSH_SECRETO`, no una sesión de usuario.
`SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` las pone Supabase automáticamente.

## 3. Conectar la base

Activa la extensión `pg_net` (Database → Extensions) y guarda los dos
secretos en Vault desde el SQL Editor. Si ya creaste `url_proyecto` para
`limpiar-fotos-huerfanas`, no lo repitas.

```sql
SELECT vault.create_secret('https://<proyecto>.supabase.co', 'url_proyecto');
SELECT vault.create_secret('<el-mismo-PUSH_SECRETO>', 'push_secreto');
```

## 4. Probar

1. Instala el APK en un teléfono, entra con una cuenta y acepta el permiso.
2. Comprueba que el teléfono quedó registrado:
   `SELECT usuario_id, updated_at FROM dispositivos_push;`
3. Cierra la app y crea una notificación de prueba para esa cuenta:

   ```sql
   INSERT INTO notificaciones (usuario_id, tipo, titulo)
   VALUES ('<uuid-de-la-cuenta>', 'PRUEBA', 'Notificación de prueba');
   ```

Si no llega, revisa los registros de la función (Edge Functions →
enviar-push → Logs) y las respuestas de pg_net:
`SELECT status_code, content FROM net._http_response ORDER BY created DESC LIMIT 5;`
