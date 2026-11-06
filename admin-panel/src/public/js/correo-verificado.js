/*
 * Página a la que Supabase manda a la persona después de abrir el enlace de
 * verificación del correo (emailRedirectTo de la app). Supabase ya verificó
 * el correo antes de redirigir; aquí solo se decide qué mensaje mostrar.
 *
 * Si el enlace venció o ya se usó, Supabase agrega error y error_code en el
 * fragmento (#) o en la consulta (?). Si salió bien, agrega un código o los
 * tokens de la sesión: no se usan (la sesión se abre en la app) y se quitan
 * de la barra de direcciones para que no queden en el historial.
 */
(function () {
  'use strict';

  const fragmento = new URLSearchParams(window.location.hash.replace(/^#/, ''));
  const consulta = new URLSearchParams(window.location.search);
  const error = fragmento.get('error') || consulta.get('error') || fragmento.get('error_code') || consulta.get('error_code');

  if (window.location.hash || window.location.search) {
    window.history.replaceState(null, '', window.location.pathname);
  }

  if (!error) return;
  document.getElementById('estadoVerificado').hidden = true;
  document.getElementById('estadoVencido').hidden = false;
  document.title = 'Enlace vencido · EcoResiduos';
})();
