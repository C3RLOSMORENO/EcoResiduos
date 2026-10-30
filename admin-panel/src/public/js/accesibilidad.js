/*
 * Preferencias de accesibilidad. Cada opción es un atributo en <html>
 * (data-texto, data-contraste…) que el CSS interpreta; head.ejs los aplica
 * antes de pintar con lo guardado en localStorage, y este archivo maneja el
 * panel. Son preferencias de visualización: el panel ya es accesible sin
 * ellas (pruebas de WCAG en pruebas/accesibilidad.test.js y la declaración
 * en /accesibilidad).
 */
(function () {
  'use strict';

  const boton = document.getElementById('botonAccesibilidad');
  const panel = document.getElementById('panelAccesibilidad');
  if (!boton || !panel) return;

  const raiz = document.documentElement;
  const CLAVE = 'accesibilidad';
  const OPCIONES = ['contraste', 'espaciado', 'legible', 'enlaces', 'animaciones', 'mascara'];
  const TAMANOS = ['100', '115', '130', '150'];
  const URL_FUENTE = 'https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400&display=swap';
  const mascara = document.getElementById('mascaraLectura');
  const valorTamano = document.getElementById('valorTamano');

  function leer() {
    try {
      const guardado = JSON.parse(localStorage.getItem(CLAVE) || 'null');
      return guardado && typeof guardado === 'object' ? guardado : {};
    } catch (e) {
      return {};
    }
  }

  function guardar() {
    try { localStorage.setItem(CLAVE, JSON.stringify(prefs)); } catch (e) { /* sin almacenamiento: vale solo en esta página */ }
  }

  let prefs = leer();

  function cargarFuente() {
    if (document.getElementById('fuenteLegible')) return;
    const enlace = document.createElement('link');
    enlace.id = 'fuenteLegible';
    enlace.rel = 'stylesheet';
    enlace.href = URL_FUENTE;
    document.head.append(enlace);
  }

  // La franja visible de la máscara sigue al puntero.
  function moverMascara(e) {
    mascara.style.transform = `translateY(${e.clientY - 48}px)`;
  }

  // Lleva prefs a los atributos de <html> y al estado de los controles.
  function aplicar() {
    const texto = TAMANOS.includes(prefs.texto) ? prefs.texto : '100';
    if (texto === '100') raiz.removeAttribute('data-texto'); else raiz.setAttribute('data-texto', texto);
    valorTamano.textContent = `${texto} %`;
    panel.querySelector('[data-paso="-1"]').disabled = texto === TAMANOS[0];
    panel.querySelector('[data-paso="1"]').disabled = texto === TAMANOS[TAMANOS.length - 1];

    OPCIONES.forEach((opcion) => {
      const activa = prefs[opcion] === true;
      raiz.toggleAttribute(`data-${opcion}`, activa);
      const mosaico = panel.querySelector(`[data-opcion="${opcion}"]`);
      if (mosaico) mosaico.setAttribute('aria-pressed', String(activa));
    });

    if (prefs.legible) cargarFuente();
    mascara.hidden = !prefs.mascara;
    if (prefs.mascara) window.addEventListener('pointermove', moverMascara, { passive: true });
    else window.removeEventListener('pointermove', moverMascara);
  }

  function cambiar(cambio) {
    Object.assign(prefs, cambio);
    guardar();
    aplicar();
  }

  function abrir() {
    // Solo un panel flotante abierto a la vez (el otro es el asistente).
    document.dispatchEvent(new CustomEvent('panel-flotante', { detail: 'accesibilidad' }));
    panel.hidden = false;
    boton.setAttribute('aria-expanded', 'true');
    document.getElementById('cerrarAccesibilidad').focus();
  }

  function cerrar(devolverFoco) {
    if (panel.hidden) return;
    panel.hidden = true;
    boton.setAttribute('aria-expanded', 'false');
    if (devolverFoco) boton.focus();
  }

  boton.addEventListener('click', () => (panel.hidden ? abrir() : cerrar(true)));
  document.getElementById('cerrarAccesibilidad').addEventListener('click', () => cerrar(true));
  document.addEventListener('panel-flotante', (e) => { if (e.detail !== 'accesibilidad') cerrar(false); });
  panel.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      e.stopPropagation();
      cerrar(true);
    }
  });

  // Alt + Shift + A abre o cierra el panel desde cualquier lugar.
  document.addEventListener('keydown', (e) => {
    if (e.altKey && e.shiftKey && !e.ctrlKey && !e.metaKey && e.code === 'KeyA') {
      e.preventDefault();
      if (panel.hidden) abrir(); else cerrar(true);
    }
  });

  panel.addEventListener('click', (e) => {
    const paso = e.target.closest('[data-paso]');
    if (paso) {
      const actual = Math.max(0, TAMANOS.indexOf(prefs.texto || '100'));
      const siguiente = Math.min(TAMANOS.length - 1, Math.max(0, actual + Number(paso.dataset.paso)));
      cambiar({ texto: TAMANOS[siguiente] });
      return;
    }
    const mosaico = e.target.closest('[data-opcion]');
    if (mosaico) cambiar({ [mosaico.dataset.opcion]: prefs[mosaico.dataset.opcion] !== true });
  });

  document.getElementById('restablecerAccesibilidad').addEventListener('click', () => {
    prefs = {};
    guardar();
    aplicar();
    detenerLectura();
  });

  // ------------------------------------------------------------------
  // Leer en voz alta (Web Speech API, con las voces del sistema)
  // ------------------------------------------------------------------
  const voz = window.speechSynthesis;
  const botonLeer = document.getElementById('botonLeer');
  let leyendo = false;

  function marcarLectura(activa) {
    leyendo = activa;
    botonLeer.setAttribute('aria-pressed', String(activa));
    botonLeer.querySelector('[data-icono-leer]').textContent = activa ? 'stop_circle' : 'record_voice_over';
    botonLeer.querySelector('[data-texto-leer]').textContent = activa ? 'Detener lectura' : 'Leer en voz alta';
  }

  function detenerLectura() {
    if (!voz) return;
    voz.cancel();
    marcarLectura(false);
  }

  // Frases de hasta ~200 caracteres: Chrome corta las lecturas muy largas.
  function trozos(texto) {
    const frases = texto.replace(/\s+/g, ' ').match(/[^.!?]+[.!?]*/g) || [];
    const resultado = [];
    frases.forEach((frase) => {
      const ultima = resultado[resultado.length - 1];
      if (ultima && (ultima + frase).length < 200) resultado[resultado.length - 1] = ultima + frase;
      else resultado.push(frase.trim());
    });
    return resultado.filter(Boolean);
  }

  function leerEnVoz() {
    if (leyendo) {
      detenerLectura();
      return;
    }
    const seleccion = String(window.getSelection ? window.getSelection() : '').trim();
    const contenido = document.getElementById('contenido');
    const partes = trozos((seleccion || (contenido || document.body).innerText).slice(0, 8000));
    if (!partes.length) return;

    voz.cancel();
    const espanol = voz.getVoices().find((v) => /^es(-|_|$)/i.test(v.lang));
    partes.forEach((parte, i) => {
      const frase = new SpeechSynthesisUtterance(parte);
      frase.lang = 'es-CO';
      if (espanol) frase.voice = espanol;
      if (i === partes.length - 1) frase.onend = () => marcarLectura(false);
      frase.onerror = () => marcarLectura(false);
      voz.speak(frase);
    });
    marcarLectura(true);
  }

  if (voz && typeof window.SpeechSynthesisUtterance === 'function') {
    botonLeer.hidden = false;
    botonLeer.setAttribute('aria-pressed', 'false');
    botonLeer.addEventListener('click', leerEnVoz);
    window.addEventListener('pagehide', detenerLectura);
  }

  // Sin JavaScript el botón no serviría: se muestra solo cuando ya funciona.
  boton.hidden = false;
  aplicar();
})();
