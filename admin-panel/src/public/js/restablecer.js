/*
 * Restablecer contraseña: el código de 8 dígitos llega por correo desde
 * Supabase Auth y la contraseña nueva se guarda con esa misma sesión.
 * Necesita /vendor/supabase.js cargado antes (define window.supabase).
 */
(function () {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const notificar = (mensaje, esError) => window.mostrarNotificacion && window.mostrarNotificacion(mensaje, esError);

  let config = {};
  try { config = JSON.parse($('configuracionSupabase').textContent); } catch (e) { /* se avisa abajo */ }

  // Sin la URL o la clave pública no hay forma de enviar el código: se dice
  // claro en lugar de dejar un botón que no hace nada.
  if (!window.supabase || !config.url || !config.anonKey) {
    $('btnEnviarOtp').disabled = true;
    notificar('Restablecer la contraseña no está disponible en este momento. Pide ayuda al equipo técnico de EcoResiduos.', true);
    return;
  }

  const cliente = window.supabase.createClient(config.url, config.anonKey, {
    auth: { persistSession: false, autoRefreshToken: false }
  });
  let correo = '';

  $('verClaves').addEventListener('change', (e) => {
    ['nuevaClave', 'confirmarClave'].forEach((id) => { $(id).type = e.target.checked ? 'text' : 'password'; });
  });

  $('codigoOtp').addEventListener('input', (e) => {
    e.target.value = e.target.value.replace(/\D/g, '').slice(0, 8);
  });

  // main.js valida los campos antes; aquí solo se actúa si el formulario es válido.
  $('formPasoEmail').addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!e.target.checkValidity()) return;
    correo = $('correoRecuperar').value.trim();
    $('btnEnviarOtp').disabled = true;
    $('btnEnviarOtpTexto').textContent = 'Enviando…';

    const { error } = await cliente.auth.resetPasswordForEmail(correo);
    $('btnEnviarOtp').disabled = false;
    $('btnEnviarOtpTexto').textContent = 'Enviar código';
    if (error) {
      notificar(error.status === 429
        ? 'Ya pediste varios códigos seguidos. Espera unos minutos y vuelve a intentarlo.'
        : 'No pudimos enviar el código. Revisa el correo y vuelve a intentarlo.', true);
      return;
    }
    // El mensaje es el mismo exista o no la cuenta: así no se puede averiguar
    // qué correos están registrados.
    notificar(`Si ${correo} tiene acceso al panel, le llegará un código de 8 dígitos.`);
    $('correoDestinoTexto').textContent = correo;
    $('formPasoEmail').hidden = true;
    $('formPasoClave').hidden = false;
    $('subtituloPaso').textContent = 'Escribe el código que recibiste y tu nueva contraseña.';
    $('codigoOtp').focus();
  });

  $('btnCambiarCorreo').addEventListener('click', () => {
    $('formPasoClave').hidden = true;
    $('formPasoEmail').hidden = false;
    $('subtituloPaso').textContent = 'Escribe tu correo y te enviaremos un código de 8 dígitos.';
    $('correoRecuperar').focus();
  });

  $('formPasoClave').addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!e.target.checkValidity()) return;
    if ($('nuevaClave').value !== $('confirmarClave').value) {
      $('confirmarClave').setAttribute('aria-invalid', 'true');
      notificar('Las contraseñas no coinciden.', true);
      $('confirmarClave').focus();
      return;
    }
    $('confirmarClave').removeAttribute('aria-invalid');
    const boton = $('btnConfirmarCambio');
    const restaurar = () => {
      boton.disabled = false;
      $('btnConfirmarTexto').textContent = 'Guardar contraseña';
    };
    boton.disabled = true;
    $('btnConfirmarTexto').textContent = 'Validando código…';

    const { error: errorOtp } = await cliente.auth.verifyOtp({ email: correo, token: $('codigoOtp').value.trim(), type: 'recovery' });
    if (errorOtp) {
      notificar('El código es incorrecto o ya venció. Revisa los 8 dígitos o pide uno nuevo.', true);
      restaurar();
      $('codigoOtp').focus();
      return;
    }

    $('btnConfirmarTexto').textContent = 'Guardando…';
    const { error: errorClave } = await cliente.auth.updateUser({ password: $('nuevaClave').value });
    if (errorClave) {
      notificar(errorClave.code === 'same_password'
        ? 'La contraseña nueva debe ser distinta de la anterior.'
        : 'No pudimos guardar la contraseña. Usa una más larga o distinta y vuelve a intentarlo.', true);
      restaurar();
      $('nuevaClave').focus();
      return;
    }
    await cliente.auth.signOut();
    window.location.href = '/login?aviso=clave-actualizada';
  });
})();
