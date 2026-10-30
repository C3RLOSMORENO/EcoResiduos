/*
 * Asistente flotante. La conversación se guarda en sessionStorage para que
 * siga ahí al pasar de una pantalla a otra; se borra al cerrar la pestaña.
 * Cada pregunta manda los últimos mensajes y el servidor responde en JSON.
 * Todo el texto se pinta con textContent, nunca como HTML.
 */
(function () {
  'use strict';

  const boton = document.getElementById('botonAsistente');
  const panel = document.getElementById('panelAsistente');
  const form = document.getElementById('formAsistente');
  if (!boton || !panel || !form) return;

  const campo = document.getElementById('preguntaAsistente');
  const enviar = document.getElementById('botonPreguntar');
  const conversacion = document.getElementById('conversacion');
  const sugerencias = document.getElementById('sugerencias');
  const metaCsrf = document.querySelector('meta[name="csrf-token"]');
  const tokenCsrf = metaCsrf ? metaCsrf.content : '';
  const CLAVE = 'asistente';

  let estado = { abierto: false, mensajes: [] };
  try {
    const guardado = JSON.parse(sessionStorage.getItem(CLAVE) || 'null');
    if (guardado && Array.isArray(guardado.mensajes)) estado = guardado;
  } catch (e) {
    // Sin almacenamiento la conversación empieza vacía en cada pantalla.
  }
  let esperando = false;

  function guardar() {
    try { sessionStorage.setItem(CLAVE, JSON.stringify(estado)); } catch (e) { /* sin almacenamiento */ }
  }

  function burbuja(rol, texto, consultas) {
    const fila = document.createElement('div');
    fila.className = rol === 'usuario' ? 'flex justify-end' : 'flex justify-start';

    const caja = document.createElement('div');
    const base = 'max-w-[90%] rounded-2xl px-4 py-3 text-body-m whitespace-pre-line';
    caja.className = rol === 'usuario'
      ? `${base} rounded-br-sm bg-primary text-on-primary`
      : rol === 'error'
        ? `${base} rounded-bl-sm bg-error-container text-on-error-container`
        : `${base} rounded-bl-sm bg-surface-container-high text-on-surface`;
    caja.textContent = texto;

    if (consultas && consultas.length) {
      const nota = document.createElement('p');
      nota.className = 'mt-2 flex items-center gap-1 text-label-s text-on-surface-variant';
      const icono = document.createElement('span');
      icono.className = 'material-symbols-outlined icono-20';
      icono.setAttribute('aria-hidden', 'true');
      icono.textContent = 'manage_search';
      nota.append(icono, `Consultó: ${consultas.join(', ')}`);
      caja.append(nota);
    }

    fila.append(caja);
    conversacion.append(fila);
    conversacion.scrollTop = conversacion.scrollHeight;
    return fila;
  }

  function pintarConversacion() {
    if (estado.mensajes.length && sugerencias) sugerencias.hidden = true;
    estado.mensajes.forEach((m) => burbuja(m.rol, m.texto, m.consultas));
  }

  function abrir(enfocar) {
    document.dispatchEvent(new CustomEvent('panel-flotante', { detail: 'asistente' }));
    estado.abierto = true;
    panel.hidden = false;
    boton.setAttribute('aria-expanded', 'true');
    boton.setAttribute('aria-label', 'Cerrar el asistente');
    conversacion.scrollTop = conversacion.scrollHeight;
    if (enfocar && !campo.disabled) campo.focus();
    guardar();
  }

  function cerrar() {
    estado.abierto = false;
    panel.hidden = true;
    boton.setAttribute('aria-expanded', 'false');
    boton.setAttribute('aria-label', 'Abrir el asistente');
    boton.focus();
    guardar();
  }

  function nuevaConversacion() {
    estado.mensajes = [];
    guardar();
    Array.from(conversacion.children).forEach((hijo) => {
      if (hijo !== sugerencias && hijo.getAttribute('role') !== 'status') hijo.remove();
    });
    if (sugerencias) sugerencias.hidden = false;
    if (!campo.disabled) campo.focus();
  }

  async function preguntar(texto) {
    const pregunta = texto.trim();
    if (!pregunta || esperando) return;
    esperando = true;
    enviar.disabled = true;
    if (sugerencias) sugerencias.hidden = true;

    burbuja('usuario', pregunta);
    estado.mensajes.push({ rol: 'usuario', texto: pregunta });
    campo.value = '';
    const espera = burbuja('asistente', 'Consultando los datos…');
    espera.firstChild.classList.add('animate-pulse');
    espera.setAttribute('aria-busy', 'true');

    const historial = estado.mensajes
      .filter((m) => m.rol === 'usuario' || m.rol === 'asistente')
      .map((m) => ({ rol: m.rol, texto: m.texto }));

    let respuesta = null;
    try {
      const r = await fetch(form.action, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'fetch',
          'X-CSRF-Token': tokenCsrf,
          Accept: 'application/json'
        },
        credentials: 'same-origin',
        body: JSON.stringify({ historial })
      });
      if (r.status === 401) {
        guardar();
        window.location.href = `/login?aviso=sesion-vencida&volver=${encodeURIComponent(location.pathname + location.search)}`;
        return;
      }
      respuesta = await r.json().catch(() => null);
    } catch (e) {
      respuesta = { ok: false, mensaje: 'No hay conexión con el panel. Revisa tu internet e inténtalo de nuevo.' };
    }

    espera.remove();
    if (respuesta && respuesta.ok) {
      burbuja('asistente', respuesta.respuesta, respuesta.consultas);
      estado.mensajes.push({ rol: 'asistente', texto: respuesta.respuesta, consultas: respuesta.consultas });
    } else {
      // La pregunta sin respuesta sale del historial para no confundir la
      // siguiente; el error se ve en pantalla pero no se guarda.
      estado.mensajes.pop();
      burbuja('error', (respuesta && respuesta.mensaje) || 'El asistente no pudo responder. Inténtalo de nuevo.');
    }
    guardar();
    esperando = false;
    enviar.disabled = false;
    campo.focus();
  }

  boton.addEventListener('click', () => (panel.hidden ? abrir(true) : cerrar()));
  document.getElementById('cerrarAsistente').addEventListener('click', cerrar);
  document.getElementById('nuevaConversacion').addEventListener('click', nuevaConversacion);
  // Solo un panel flotante abierto a la vez (el otro es el de accesibilidad).
  document.addEventListener('panel-flotante', (e) => {
    if (e.detail === 'asistente' || panel.hidden) return;
    estado.abierto = false;
    panel.hidden = true;
    boton.setAttribute('aria-expanded', 'false');
    boton.setAttribute('aria-label', 'Abrir el asistente');
    guardar();
  });

  panel.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      e.stopPropagation();
      cerrar();
    }
  });

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    preguntar(campo.value);
  });

  campo.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) {
      e.preventDefault();
      preguntar(campo.value);
    }
  });

  conversacion.addEventListener('click', (e) => {
    const sugerencia = e.target.closest('[data-pregunta]');
    if (sugerencia) preguntar(sugerencia.dataset.pregunta);
  });

  // Sin JavaScript el botón no serviría: se muestra solo cuando ya funciona.
  boton.hidden = false;
  pintarConversacion();
  if (estado.abierto) abrir(false);
})();
