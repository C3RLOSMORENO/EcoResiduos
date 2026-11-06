// Envía una notificación de la tabla `notificaciones` a los teléfonos del
// usuario con Firebase Cloud Messaging (API HTTP v1).
//
// La llama el trigger notificaciones_enviar_push con { notificacion_id } cada
// vez que la base crea una notificación (ver README.md). Solo responde si trae
// el encabezado `x-push-secreto` con el valor del secreto PUSH_SECRETO.
// Borra los tokens que Firebase da por vencidos (app desinstalada, datos
// borrados).
//
// Docs: https://firebase.google.com/docs/cloud-messaging/send-message
//       https://developers.google.com/identity/protocols/oauth2/service-account#httprest

import { createClient } from 'npm:@supabase/supabase-js@2';
import { importPKCS8, SignJWT } from 'npm:jose@5.9.6';

interface CuentaServicio {
  project_id: string;
  client_email: string;
  private_key: string;
}

const ALCANCE = 'https://www.googleapis.com/auth/firebase.messaging';

// El token de Google dura una hora; se reutiliza mientras la función siga viva.
let tokenGoogle: { valor: string; vence: number } | null = null;

/** Token de acceso de Google firmado con la cuenta de servicio de Firebase. */
async function obtenerTokenGoogle(cuenta: CuentaServicio): Promise<string> {
  if (tokenGoogle && tokenGoogle.vence > Date.now() + 60_000) return tokenGoogle.valor;

  const llave = await importPKCS8(cuenta.private_key, 'RS256');
  const ahora = Math.floor(Date.now() / 1000);
  const afirmacion = await new SignJWT({ scope: ALCANCE })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(cuenta.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(ahora)
    .setExpirationTime(ahora + 3600)
    .sign(llave);

  const respuesta = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: afirmacion,
    }),
  });
  if (!respuesta.ok) throw new Error(`Google no entregó el token: ${await respuesta.text()}`);
  const datos = await respuesta.json();
  tokenGoogle = { valor: datos.access_token, vence: Date.now() + datos.expires_in * 1000 };
  return tokenGoogle.valor;
}

/** true si Firebase dice que el token ya no sirve y hay que borrarlo. */
function tokenVencido(estado: number, error: unknown): boolean {
  if (estado === 404) return true;
  const detalles = (error as { error?: { details?: { errorCode?: string }[] } })?.error?.details ?? [];
  // INVALID_ARGUMENT no se cuenta: también sale si el mensaje está mal armado,
  // y entonces se borrarían tokens que sí sirven.
  return detalles.some((d) => d.errorCode === 'UNREGISTERED');
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Método no permitido', { status: 405 });
  const secreto = Deno.env.get('PUSH_SECRETO');
  if (!secreto || req.headers.get('x-push-secreto') !== secreto) {
    return new Response('No autorizado', { status: 401 });
  }

  const { notificacion_id: id } = await req.json().catch(() => ({}));
  if (!Number.isInteger(id)) return new Response('Falta notificacion_id', { status: 400 });

  const cuenta: CuentaServicio = JSON.parse(Deno.env.get('FIREBASE_CUENTA_SERVICIO') ?? '{}');
  if (!cuenta.project_id || !cuenta.client_email || !cuenta.private_key) {
    return new Response('Falta el secreto FIREBASE_CUENTA_SERVICIO', { status: 500 });
  }

  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  const { data: aviso, error: errorAviso } = await supabase
    .from('notificaciones')
    .select('id, usuario_id, tipo, titulo, solicitud_id')
    .eq('id', id)
    .maybeSingle();
  if (errorAviso) return new Response(errorAviso.message, { status: 500 });
  if (!aviso) return Response.json({ enviadas: 0, motivo: 'La notificación ya no existe' });

  const { data: dispositivos, error: errorDispositivos } = await supabase
    .from('dispositivos_push')
    .select('token')
    .eq('usuario_id', aviso.usuario_id);
  if (errorDispositivos) return new Response(errorDispositivos.message, { status: 500 });
  if (!dispositivos?.length) return Response.json({ enviadas: 0 });

  const acceso = await obtenerTokenGoogle(cuenta);
  const url = `https://fcm.googleapis.com/v1/projects/${cuenta.project_id}/messages:send`;

  let enviadas = 0;
  const vencidos: string[] = [];
  await Promise.all(
    dispositivos.map(async ({ token }) => {
      const respuesta = await fetch(url, {
        method: 'POST',
        headers: { Authorization: `Bearer ${acceso}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: 'EcoResiduos', body: aviso.titulo },
            // Los valores de data tienen que ser texto.
            data: {
              notificacion_id: String(aviso.id),
              tipo: aviso.tipo,
              solicitud_id: aviso.solicitud_id == null ? '' : String(aviso.solicitud_id),
            },
            android: {
              priority: 'HIGH',
              // El canal lo crea MainActivity.kt; si no existe, Android usa uno genérico.
              notification: { channel_id: 'novedades', tag: `notificacion-${aviso.id}` },
            },
          },
        }),
      });
      if (respuesta.ok) {
        enviadas++;
        return;
      }
      const error = await respuesta.json().catch(() => null);
      if (tokenVencido(respuesta.status, error)) {
        vencidos.push(token);
      } else {
        console.error(`FCM respondió ${respuesta.status}:`, JSON.stringify(error));
      }
    }),
  );

  if (vencidos.length) await supabase.from('dispositivos_push').delete().in('token', vencidos);

  return Response.json({ enviadas, vencidos: vencidos.length });
});
