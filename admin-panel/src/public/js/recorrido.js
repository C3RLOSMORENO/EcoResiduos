/*
 * Recorrido guiado de una pantalla, con Driver.js (servido desde /vendor).
 * Los pasos llegan del servidor en <script id="datosRecorrido">; su texto y
 * su versión viven en src/utils/recorridos.js. Se muestra solo la primera
 * vez, o solo los pasos nuevos después de una actualización, y se repite
 * cuando se quiera con el botón de ayuda del encabezado.
 */
(function () {
  'use strict';

  const fuente = document.getElementById('datosRecorrido');
  const boton = document.getElementById('botonRecorrido');
  if (!fuente || !boton || !window.driver || !window.driver.js) return;

  let datos;
  try {
    datos = JSON.parse(fuente.textContent);
  } catch {
    return;
  }
  if (!datos || !Array.isArray(datos.pasos)) return;

  const metaCsrf = document.querySelector('meta[name="csrf-token"]');
  const tokenCsrf = metaCsrf ? metaCsrf.content : '';
  const sinMovimiento = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ------------------------------------------------------------------
  // Qué versión ya vio el administrador
  // ------------------------------------------------------------------
  // La cuenta es la fuente principal (datos.vista). La copia local cubre el
  // caso en que el servidor no pudo guardarla: el recorrido no vuelve a
  // aparecer en este navegador.
  const claveLocal = `recorrido:${datos.pantalla}:${datos.usuario}`;

  function versionLocal() {
    try {
      return Number(localStorage.getItem(claveLocal)) || 0;
    } catch {
      return 0;
    }
  }

  // Anota que este navegador ya vio la versión actual y avisa al servidor.
  // estado: 'visto', 'completado' u 'omitido'; paso: hasta dónde llegó.
  function guardar(estado, paso) {
    try {
      localStorage.setItem(claveLocal, String(datos.version));
    } catch {
      // Sin almacenamiento (ventana privada, bloqueado): queda en la cuenta.
    }
    // keepalive: el aviso llega aunque el administrador ya esté saliendo de la página.
    fetch(`/recorridos/${encodeURIComponent(datos.pantalla)}`, {
      method: 'POST',
      keepalive: true,
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'fetch',
        'X-CSRF-Token': tokenCsrf,
        Accept: 'application/json'
      },
      body: JSON.stringify({ version: datos.version, estado, paso })
    }).catch(() => {});
  }

  // ------------------------------------------------------------------
  // Pasos disponibles
  // ------------------------------------------------------------------
  // Un paso se muestra solo si su elemento está en la página y se ve: una
  // sección que no se pintó no debe dejar el recorrido apuntando al vacío.
  function visible(elemento) {
    return Boolean(elemento) && elemento.getClientRects().length > 0 && getComputedStyle(elemento).visibility !== 'hidden';
  }

  // Pasos que entraron después de versionVista y cuyo elemento se ve.
  function pasosDesde(versionVista) {
    return datos.pasos
      .filter((paso) => paso.desde > versionVista)
      .map((paso) => ({ paso, elemento: document.querySelector(paso.elemento) }))
      .filter((p) => visible(p.elemento));
  }

  // Un recorrido que solo señalaría el botón de ayuda no explica nada.
  function vale(pasos) {
    return pasos.some((p) => p.elemento !== boton);
  }

  // Driver.js pinta el título y el texto con innerHTML.
  function html(texto) {
    const div = document.createElement('div');
    div.textContent = texto;
    return div.innerHTML;
  }

  function colorToken(nombre) {
    return getComputedStyle(document.documentElement).getPropertyValue(nombre).trim() || '#000000';
  }

  // ------------------------------------------------------------------
  // Recorrido
  // ------------------------------------------------------------------
  let activo = false;

  // automatico: true cuando arranca solo al abrir la pantalla; false cuando
  // se pidió con el botón de ayuda.
  function iniciar(pasos, automatico) {
    if (activo || !vale(pasos)) return;
    activo = true;

    // Al cerrar, el foco vuelve a donde estaba (el botón de ayuda, si se
    // abrió con él) o al contenido. Driver.js lo devolvería a un botón del
    // recorrido que ya no existe.
    const origen = document.activeElement;
    let pasoMaximo = 0;
    let completado = false;

    const recorrido = window.driver.js.driver({
      steps: pasos.map((p, i) => ({
        element: p.elemento,
        popover: {
          title: html(p.paso.titulo),
          description: html(p.paso.texto),
          side: p.paso.lado || 'bottom',
          align: p.paso.alineacion || 'start',
          // En el primero «Saltar» ocupa el lugar de «Anterior».
          showButtons: i === 0 ? ['next', 'close'] : ['next', 'previous', 'close']
        }
      })),
      animate: !sinMovimiento,
      smoothScroll: false,
      allowClose: true,
      allowKeyboardControl: true,
      // Lo resaltado se mira, no se usa: un clic en una tarjeta a mitad del
      // recorrido sacaría al administrador de la página.
      disableActiveInteraction: true,
      overlayColor: colorToken('--md-sys-color-scrim'),
      overlayOpacity: 0.55,
      stagePadding: 8,
      stageRadius: 16,
      popoverOffset: 12,
      popoverClass: 'recorrido',
      showProgress: pasos.length > 1,
      progressText: '{{current}} de {{total}}',
      nextBtnText: 'Siguiente',
      prevBtnText: 'Anterior',
      doneBtnText: 'Entendido',
      closeBtnLabel: 'Cerrar recorrido',
      onPopoverRender(popover, { driver: d }) {
        popover.wrapper.setAttribute('aria-modal', 'true');
        const icono = document.createElement('span');
        icono.className = 'material-symbols-outlined';
        icono.setAttribute('aria-hidden', 'true');
        icono.textContent = 'close';
        popover.closeButton.replaceChildren(icono);

        if (d.isFirstStep() && !d.isLastStep()) {
          const saltar = document.createElement('button');
          saltar.type = 'button';
          saltar.className = 'driver-popover-footer-btn recorrido-saltar';
          saltar.textContent = 'Saltar';
          saltar.addEventListener('click', () => d.destroy());
          popover.footerButtons.prepend(saltar);
        }
      },
      onHighlighted(_elemento, _paso, { state }) {
        pasoMaximo = Math.max(pasoMaximo, (state.activeIndex || 0) + 1);
        // Driver.js enfoca la ✕, el primer botón de la tarjeta; el foco va
        // a «Siguiente» para que Enter avance.
        if (state.popover) state.popover.nextButton.focus();
      },
      onNextClick(_elemento, _paso, { driver: d }) {
        if (d.isLastStep()) completado = true;
        d.moveNext();
      },
      onDestroyed() {
        activo = false;
        guardar(completado ? 'completado' : 'omitido', pasoMaximo);
        const destino = origen && origen !== document.body && document.contains(origen) ? origen : document.getElementById('contenido');
        if (destino) destino.focus({ preventScroll: true });
      }
    });

    // Se anota al empezar: si cierra la pestaña a mitad, no se le vuelve a
    // imponer. Siempre puede repetirlo con el botón de ayuda.
    if (automatico) guardar('visto', 0);
    recorrido.drive();
  }

  // ------------------------------------------------------------------
  // Arranque
  // ------------------------------------------------------------------
  // El recorrido mide la página: antes de empezar espera a que carguen las
  // fuentes (los íconos cambian el ancho de las tarjetas) y a que el
  // navegador pinte. Si la pestaña está en segundo plano, espera a que vuelva.
  function esperar(ms) {
    return new Promise((listo) => setTimeout(listo, ms));
  }

  function paginaLista() {
    const fuentes = document.fonts && document.fonts.ready ? Promise.race([document.fonts.ready, esperar(3000)]) : Promise.resolve();
    return fuentes.then(() => new Promise((listo) => requestAnimationFrame(() => requestAnimationFrame(listo))));
  }

  function pestanaVisible() {
    if (document.visibilityState === 'visible') return Promise.resolve();
    return new Promise((listo) => {
      document.addEventListener('visibilitychange', function alVolver() {
        if (document.visibilityState !== 'visible') return;
        document.removeEventListener('visibilitychange', alVolver);
        listo();
      });
    });
  }

  boton.hidden = false;
  if (!vale(pasosDesde(0))) {
    boton.hidden = true;
    return;
  }
  boton.addEventListener('click', () => iniciar(pasosDesde(0), false));

  const vista = Math.max(Number(datos.vista) || 0, versionLocal());
  if (vista >= datos.version) return;
  paginaLista().then(pestanaVisible).then(() => {
    // No se encima a un diálogo abierto (por ejemplo, el aviso de sesión).
    if (document.querySelector('dialog[open]')) return;
    iniciar(pasosDesde(vista), true);
  });
})();
