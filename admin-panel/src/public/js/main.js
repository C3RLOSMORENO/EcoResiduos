/*
 * Comportamiento del panel. Todo es mejora progresiva: sin JavaScript los
 * formularios se envían igual y el servidor valida.
 */
(function () {
  'use strict';

  const $ = (selector, raiz) => (raiz || document).querySelector(selector);
  const $$ = (selector, raiz) => Array.from((raiz || document).querySelectorAll(selector));

  // Token CSRF para los fetch (los formularios lo llevan en un campo oculto).
  const metaCsrf = $('meta[name="csrf-token"]');
  const tokenCsrf = metaCsrf ? metaCsrf.content : '';

  // ------------------------------------------------------------------
  // Formato de campos (data-format)
  // ------------------------------------------------------------------
  document.addEventListener('input', (e) => {
    const campo = e.target;
    if (!(campo instanceof HTMLInputElement)) return;
    if (campo.matches('[data-format="nit"]')) campo.value = campo.value.replace(/[^0-9-]/g, '');
    // Teléfono: dígitos, +57, separadores y la extensión («ext. 123»).
    if (campo.matches('[data-format="phone"]')) campo.value = campo.value.replace(/[^0-9+\s().\-extEXT]/g, '');
    if (campo.matches('[data-format="numeric"]')) campo.value = campo.value.replace(/[^0-9]/g, '');
    if (campo.matches('[data-format="uppercase"]')) campo.value = campo.value.toUpperCase();
  });

  // ------------------------------------------------------------------
  // Avisos (snackbar)
  // ------------------------------------------------------------------
  function cerrarAviso(aviso) {
    if (aviso && aviso.parentNode) aviso.remove();
  }

  // Se cierra solo a los 10 s, salvo que tenga el foco o el puntero encima.
  function programarCierre(aviso) {
    let temporizador = null;
    const iniciar = () => { temporizador = setTimeout(() => cerrarAviso(aviso), 10000); };
    const pausar = () => clearTimeout(temporizador);
    aviso.addEventListener('mouseenter', pausar);
    aviso.addEventListener('focusin', pausar);
    aviso.addEventListener('mouseleave', iniciar);
    aviso.addEventListener('focusout', iniciar);
    iniciar();
  }

  // Un error va arriba del contenido y se queda hasta la próxima acción; un
  // aviso de éxito va en la esquina y se cierra solo. Las vistas la llaman
  // como window.mostrarNotificacion.
  function mostrarNotificacion(mensaje, esError) {
    if (esError) {
      const region = $('#avisosAlerta');
      if (!region) return;
      region.textContent = '';
      const nota = document.createElement('div');
      nota.className = 'nota nota-error mb-4';
      const icono = document.createElement('span');
      icono.className = 'material-symbols-outlined';
      icono.setAttribute('aria-hidden', 'true');
      icono.textContent = 'error';
      const texto = document.createElement('p');
      texto.className = 'flex-1';
      texto.textContent = mensaje;
      nota.append(icono, texto);
      region.append(nota);
      // La nota va arriba del contenido: si el administrador estaba más
      // abajo, se lleva a la vista (role="alert" ya la anuncia).
      const sinMovimiento = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      nota.scrollIntoView({ block: 'nearest', behavior: sinMovimiento ? 'auto' : 'smooth' });
      return;
    }
    const region = $('#avisosEstado');
    if (!region) return;
    const aviso = document.createElement('div');
    aviso.className = 'aviso';
    const icono = document.createElement('span');
    icono.className = 'material-symbols-outlined icono-20';
    icono.setAttribute('aria-hidden', 'true');
    icono.textContent = 'check_circle';
    const texto = document.createElement('p');
    texto.className = 'flex-1';
    texto.textContent = mensaje;
    const cerrar = document.createElement('button');
    cerrar.type = 'button';
    cerrar.className = 'btn-icono';
    cerrar.setAttribute('aria-label', 'Cerrar aviso');
    cerrar.innerHTML = '<span class="material-symbols-outlined icono-20" aria-hidden="true">close</span>';
    cerrar.addEventListener('click', () => cerrarAviso(aviso));
    aviso.append(icono, texto, cerrar);
    region.append(aviso);
    programarCierre(aviso);
  }
  window.mostrarNotificacion = mostrarNotificacion;

  $$('[data-aviso]').forEach((aviso) => {
    programarCierre(aviso);
    const cerrar = $('[data-cerrar-aviso]', aviso);
    if (cerrar) cerrar.addEventListener('click', () => cerrarAviso(aviso));
  });

  // ------------------------------------------------------------------
  // Botones sencillos: mostrar la contraseña y el aviso de ejemplo de
  // /componentes. Viven aquí y no en atributos onclick porque la CSP del
  // panel no permite JavaScript escrito dentro del HTML.
  // ------------------------------------------------------------------
  $$('[data-ver-clave]').forEach((boton) => {
    const campo = document.getElementById(boton.dataset.verClave);
    if (!campo) return;
    boton.addEventListener('click', () => {
      const mostrar = campo.type === 'password';
      campo.type = mostrar ? 'text' : 'password';
      // Botón de alternar: el nombre no cambia, cambia aria-pressed.
      boton.setAttribute('aria-pressed', String(mostrar));
      const icono = $('.material-symbols-outlined', boton);
      if (icono) icono.textContent = mostrar ? 'visibility_off' : 'visibility';
    });
  });

  // Aviso accesible cuando Bloq Mayús está activo en el campo de contraseña
  const campoClave = $('#password');
  const avisoMayus = $('#avisoMayusculas');
  if (campoClave && avisoMayus) {
    const revisarMayus = (e) => {
      const activo = Boolean(e && e.getModifierState && e.getModifierState('CapsLock'));
      avisoMayus.hidden = !activo;
    };
    campoClave.addEventListener('keydown', revisarMayus);
    campoClave.addEventListener('keyup', revisarMayus);
    campoClave.addEventListener('focus', revisarMayus);
    campoClave.addEventListener('blur', () => { avisoMayus.hidden = true; });
  }

  $$('[data-aviso-ejemplo]').forEach((boton) => {
    boton.addEventListener('click', () => mostrarNotificacion(boton.dataset.avisoEjemplo));
  });

  // ------------------------------------------------------------------
  // Tema claro u oscuro (interruptor manual que se recuerda)
  // ------------------------------------------------------------------
  const raiz = document.documentElement;
  const botonTema = $('#botonTema');

  // Lo que eligió el administrador; si no ha elegido, el tema del sistema.
  function temaOscuroActivo() {
    const elegido = raiz.getAttribute('data-tema');
    if (elegido) return elegido === 'oscuro';
    return window.matchMedia('(prefers-color-scheme: dark)').matches;
  }

  function pintarBotonTema() {
    if (!botonTema) return;
    const oscuro = temaOscuroActivo();
    botonTema.setAttribute('aria-pressed', String(oscuro));
    const icono = $('[data-icono-tema]', botonTema);
    if (icono) icono.textContent = oscuro ? 'light_mode' : 'dark_mode';
  }

  if (botonTema) {
    botonTema.addEventListener('click', () => {
      const oscuro = !temaOscuroActivo();
      raiz.setAttribute('data-tema', oscuro ? 'oscuro' : 'claro');
      try { localStorage.setItem('theme', oscuro ? 'dark' : 'light'); } catch (e) { /* almacenamiento bloqueado */ }
      pintarBotonTema();
      document.dispatchEvent(new CustomEvent('tema-cambiado'));
    });
    pintarBotonTema();
  }

  // ------------------------------------------------------------------
  // Navegación modal en ventana compacta (< 600 px)
  // ------------------------------------------------------------------
  const botonMenu = $('#botonMenu');
  const nav = $('#navPrincipal');
  const fondo = $('#navFondo');
  const contenido = $('#appContenido');
  const compacta = window.matchMedia('(max-width: 599px)');

  function cerrarMenu(devolverFoco) {
    if (!raiz.classList.contains('nav-abierta')) return;
    raiz.classList.remove('nav-abierta');
    botonMenu.setAttribute('aria-expanded', 'false');
    botonMenu.setAttribute('aria-label', 'Abrir menú de navegación');
    fondo.hidden = true;
    if (contenido) contenido.inert = false;
    if (devolverFoco) botonMenu.focus();
  }

  function abrirMenu() {
    raiz.classList.add('nav-abierta');
    botonMenu.setAttribute('aria-expanded', 'true');
    botonMenu.setAttribute('aria-label', 'Cerrar menú de navegación');
    fondo.hidden = false;
    // El resto de la página queda inerte: el foco no puede salir del menú.
    if (contenido) contenido.inert = true;
    const primero = $('a', nav);
    if (primero) primero.focus();
  }

  if (botonMenu && nav && fondo) {
    botonMenu.addEventListener('click', () => (raiz.classList.contains('nav-abierta') ? cerrarMenu(true) : abrirMenu()));
    fondo.addEventListener('click', () => cerrarMenu(true));
    nav.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') cerrarMenu(true);
    });
    compacta.addEventListener('change', () => cerrarMenu(false));
  }

  // ------------------------------------------------------------------
  // Validación accesible de formularios (data-validar)
  // ------------------------------------------------------------------
  function mensajeCampo(campo) {
    const v = campo.validity;
    if (v.valueMissing) return campo.dataset.mensajeObligatorio || 'Este campo es obligatorio.';
    if (v.typeMismatch && campo.type === 'email') return 'Escribe un correo válido, por ejemplo contacto@empresa.com.';
    if (v.typeMismatch && campo.type === 'url') return 'Escribe una dirección web que empiece por https://.';
    if (v.tooShort) return `Escribe al menos ${campo.minLength} caracteres.`;
    if (v.tooLong) return `Escribe máximo ${campo.maxLength} caracteres.`;
    if (v.patternMismatch) return campo.dataset.mensajeFormato || 'Revisa el formato de este campo.';
    return campo.validationMessage;
  }

  // El mensaje queda debajo del campo y enlazado con aria-describedby, para
  // que el lector de pantalla lo lea al llegar al campo.
  function marcarError(campo, mensaje) {
    const id = `${campo.id}-error`;
    let error = document.getElementById(id);
    if (!error) {
      error = document.createElement('p');
      error.id = id;
      error.className = 'campo-error';
      const contenedor = campo.closest('.campo') || campo.parentNode;
      contenedor.append(error);
    }
    error.textContent = '';
    const icono = document.createElement('span');
    icono.className = 'material-symbols-outlined icono-18';
    icono.setAttribute('aria-hidden', 'true');
    icono.textContent = 'error';
    const texto = document.createElement('span');
    texto.textContent = mensaje;
    error.append(icono, texto);
    error.hidden = false;
    campo.setAttribute('aria-invalid', 'true');
    const descritos = (campo.getAttribute('aria-describedby') || '').split(' ').filter(Boolean);
    if (!descritos.includes(id)) campo.setAttribute('aria-describedby', [...descritos, id].join(' '));
  }

  function limpiarError(campo) {
    const error = document.getElementById(`${campo.id}-error`);
    if (error) error.hidden = true;
    campo.removeAttribute('aria-invalid');
  }

  // Marca todos los campos con error y lleva el foco al primero. Devuelve
  // true si el formulario se puede enviar.
  function validarFormulario(form) {
    let primero = null;
    $$('input, select, textarea', form).forEach((campo) => {
      if (!campo.id || campo.type === 'hidden' || campo.disabled) return;
      if (campo.checkValidity()) {
        limpiarError(campo);
      } else {
        marcarError(campo, mensajeCampo(campo));
        if (!primero) primero = campo;
      }
    });
    if (primero) primero.focus();
    return !primero;
  }

  $$('form[data-validar]').forEach((form) => {
    form.noValidate = true;
    form.addEventListener('input', (e) => {
      if (e.target.getAttribute('aria-invalid') === 'true' && e.target.checkValidity()) limpiarError(e.target);
    });
  });

  // ------------------------------------------------------------------
  // Confirmación con diálogo propio (reemplaza confirm())
  // ------------------------------------------------------------------
  const dialogo = $('#dialogoConfirmar');
  let pendiente = null;

  // El texto del diálogo sale de los data-confirmar-* del formulario o del
  // botón que lo envió; los del botón tienen prioridad.
  function abrirConfirmacion(form, boton) {
    const datos = Object.assign({}, form.dataset, boton ? boton.dataset : {});
    $('#dialogoConfirmarTitulo').textContent = datos.confirmarTitulo || 'Confirmar';
    $('#dialogoConfirmarTexto').textContent = datos.confirmar || '';
    const aceptar = $('#dialogoConfirmarAceptar');
    aceptar.textContent = datos.confirmarAccion || 'Confirmar';
    aceptar.className = datos.confirmarPeligro !== undefined ? 'btn-peligro' : 'btn-filled';

    const bloqueMotivo = $('#dialogoConfirmarMotivo');
    const campoMotivo = $('#dialogoConfirmarMotivoCampo');
    // data-confirmar-motivo: motivo obligatorio (campo «motivo»).
    // data-confirmar-nota: nota opcional (campo «nota»).
    const pideNota = datos.confirmarNota !== undefined;
    const pideMotivo = datos.confirmarMotivo !== undefined || pideNota;
    bloqueMotivo.hidden = !pideMotivo;
    $('#dialogoConfirmarMotivoEtiqueta').textContent = pideNota ? 'Nota' : 'Motivo';
    $('#dialogoConfirmarMotivoRequisito').textContent = pideNota ? '(opcional)' : '(obligatorio)';
    $('#dialogoConfirmarMotivoAyuda').textContent = datos.confirmarAyuda
      || (pideNota ? 'Se agrega al aviso. Máximo 300 caracteres.' : 'El gestor lo recibe en su notificación. Máximo 300 caracteres.');
    campoMotivo.value = '';
    campoMotivo.removeAttribute('aria-invalid');
    $('#dialogoConfirmarMotivoError').hidden = true;

    pendiente = { form, boton, pideMotivo, obligatorio: !pideNota, campo: pideNota ? 'nota' : 'motivo', origen: document.activeElement };
    dialogo.showModal();
    (pideMotivo ? campoMotivo : $('[data-dialogo-cancelar]', dialogo)).focus();
  }

  if (dialogo) {
    $('#dialogoConfirmarForm').addEventListener('submit', (e) => {
      e.preventDefault();
      if (!pendiente) return dialogo.close();
      const campoMotivo = $('#dialogoConfirmarMotivoCampo');
      if (pendiente.pideMotivo && pendiente.obligatorio && !campoMotivo.value.trim()) {
        campoMotivo.setAttribute('aria-invalid', 'true');
        campoMotivo.setAttribute('aria-describedby', 'dialogoConfirmarMotivoAyuda dialogoConfirmarMotivoError');
        $('#dialogoConfirmarMotivoError').hidden = false;
        campoMotivo.focus();
        return;
      }
      const { form, boton, pideMotivo, campo } = pendiente;
      if (pideMotivo) {
        let oculto = form.querySelector(`input[name="${campo}"]`);
        if (!oculto) {
          oculto = document.createElement('input');
          oculto.type = 'hidden';
          oculto.name = campo;
          form.append(oculto);
        }
        oculto.value = campoMotivo.value.trim();
      }
      pendiente = null;
      dialogo.close();
      form.dataset.confirmado = '1';
      if (boton) form.requestSubmit(boton); else form.requestSubmit();
    });

    $('[data-dialogo-cancelar]', dialogo).addEventListener('click', () => dialogo.close());

    dialogo.addEventListener('close', () => {
      if (pendiente && pendiente.origen && pendiente.origen.focus) pendiente.origen.focus();
      pendiente = null;
    });
  }

  // ------------------------------------------------------------------
  // Envío: valida, confirma y muestra «Guardando…»
  // ------------------------------------------------------------------
  document.addEventListener('submit', (e) => {
    const form = e.target;
    if (!(form instanceof HTMLFormElement) || form.method === 'dialog') return;
    const boton = e.submitter || null;

    if (form.hasAttribute('data-validar') && !validarFormulario(form)) {
      e.preventDefault();
      return;
    }

    const pideConfirmacion = form.dataset.confirmar || (boton && boton.dataset.confirmar);
    if (pideConfirmacion && form.dataset.confirmado !== '1' && dialogo) {
      e.preventDefault();
      abrirConfirmacion(form, boton);
      return;
    }
    delete form.dataset.confirmado;
    if (form.hasAttribute('data-conservar')) guardarBorradores('envio');

    const conCarga = boton && boton.dataset.cargando ? boton : $('[data-cargando]', form);
    if (conCarga) {
      // Se deshabilita después de enviar para que el navegador incluya su valor.
      setTimeout(() => {
        conCarga.disabled = true;
        conCarga.setAttribute('aria-busy', 'true');
        const etiqueta = $('[data-etiqueta]', conCarga) || conCarga;
        etiqueta.textContent = conCarga.dataset.cargando;
      }, 0);
    }
  });

  // ------------------------------------------------------------------
  // Fotos que no cargan: en lugar del ícono roto del navegador, un recuadro
  // que dice que la foto no está disponible.
  // ------------------------------------------------------------------
  function marcarFotoCaida(img) {
    if (img.dataset.caida) return;
    img.dataset.caida = '1';
    const grande = img.dataset.respaldo === 'detalle';
    const recuadro = document.createElement('span');
    // La miniatura caída se ve igual que la de una solicitud sin foto.
    recuadro.className = grande ? 'foto-no-disponible h-40 w-full' : 'foto-no-disponible miniatura-vacia';
    const icono = document.createElement('span');
    icono.className = 'material-symbols-outlined';
    icono.setAttribute('aria-hidden', 'true');
    icono.textContent = 'image_not_supported';
    recuadro.append(icono);
    if (grande) {
      const texto = document.createElement('span');
      texto.textContent = 'No pudimos cargar la foto que publicó el generador.';
      recuadro.append(texto);
    } else {
      recuadro.setAttribute('role', 'img');
      recuadro.setAttribute('aria-label', 'Foto no disponible');
    }
    // Si la foto estaba dentro de un enlace al visor, el enlace ya no sirve.
    (img.closest('a[data-visor]') || img).replaceWith(recuadro);
  }

  // Un logo que no carga se quita: debajo están las iniciales del avatar.
  function fotoCaida(img) {
    if (img.hasAttribute('data-avatar')) img.remove();
    else marcarFotoCaida(img);
  }

  document.addEventListener('error', (e) => {
    if (!(e.target instanceof HTMLImageElement)) return;
    if (e.target.hasAttribute('data-respaldo') || e.target.hasAttribute('data-avatar')) fotoCaida(e.target);
  }, true);

  // Las que fallaron antes de que cargara este archivo se comprueban de nuevo.
  $$('img[data-respaldo], img[data-avatar]').forEach((img) => {
    if (!img.complete || img.naturalWidth > 0 || !img.currentSrc) return;
    const prueba = new Image();
    prueba.addEventListener('error', () => fotoCaida(img));
    prueba.src = img.currentSrc;
  });

  // ------------------------------------------------------------------
  // Visor de fotos: acercar, alejar y mover con mouse, teclado o toque.
  // ------------------------------------------------------------------
  const visor = $('#visorImagen');
  if (visor) {
    const lienzo = $('[data-visor-lienzo]', visor);
    const foto = $('[data-visor-foto]', visor);
    const cargando = $('[data-visor-cargando]', visor);
    const fallo = $('[data-visor-fallo]', visor);
    const nivel = $('#visorNivel');
    const original = $('[data-visor-original]', visor);
    const botonAlejar = $('[data-visor-alejar]', visor);
    const botonAcercar = $('[data-visor-acercar]', visor);
    const botonAjustar = $('[data-visor-ajustar]', visor);
    const NIVELES = [1, 1.5, 2, 3, 4];
    const MAXIMO = 4;
    const PASO_FLECHAS = 60;
    let escala = 1;
    let x = 0;
    let y = 0;
    let disparador = null;

    // Los botones se marcan con aria-disabled (no disabled) para que el foco
    // no se pierda cuando llegan al límite.
    function habilitar(boton, activo) {
      boton.setAttribute('aria-disabled', String(!activo));
    }

    // La foto se puede mover solo hasta que su borde toca el del lienzo.
    function limitarDesplazamiento() {
      const sobraX = Math.max(0, (foto.offsetWidth * escala - lienzo.clientWidth) / 2);
      const sobraY = Math.max(0, (foto.offsetHeight * escala - lienzo.clientHeight) / 2);
      x = Math.min(sobraX, Math.max(-sobraX, x));
      y = Math.min(sobraY, Math.max(-sobraY, y));
    }

    function pintar() {
      limitarDesplazamiento();
      foto.style.transform = `translate(${x}px, ${y}px) scale(${escala})`;
      nivel.value = `${Math.round(escala * 100)} %`;
      const lista = !foto.hidden;
      habilitar(botonAlejar, lista && escala > 1);
      habilitar(botonAcercar, lista && escala < MAXIMO);
      habilitar(botonAjustar, lista && escala > 1);
      lienzo.toggleAttribute('data-ampliado', escala > 1);
    }

    // Cambia el acercamiento dejando quieto el punto (px, py), medido desde
    // el centro del lienzo: lo que está bajo el puntero sigue bajo el puntero.
    function acercarA(nueva, px, py) {
      if (foto.hidden) return;
      const destino = Math.min(MAXIMO, Math.max(1, nueva));
      const factor = destino / escala;
      x = (px || 0) - ((px || 0) - x) * factor;
      y = (py || 0) - ((py || 0) - y) * factor;
      escala = destino;
      if (escala === 1) { x = 0; y = 0; }
      pintar();
    }

    const nivelSiguiente = () => NIVELES.find((n) => n > escala + 0.01) || MAXIMO;
    const nivelAnterior = () => NIVELES.slice().reverse().find((n) => n < escala - 0.01) || 1;

    function puntoEnLienzo(e) {
      const r = lienzo.getBoundingClientRect();
      return [e.clientX - r.left - r.width / 2, e.clientY - r.top - r.height / 2];
    }

    // Abre la foto del enlace al 100 %; al cerrar, el foco vuelve al enlace.
    function abrirVisor(enlace) {
      disparador = enlace;
      const titulo = enlace.dataset.visorTitulo || 'Foto';
      $('#visorTitulo').textContent = titulo;
      original.href = enlace.href;
      foto.alt = titulo;
      foto.hidden = true;
      fallo.hidden = true;
      cargando.hidden = false;
      escala = 1;
      x = 0;
      y = 0;
      pintar();
      foto.src = enlace.href;
      raiz.classList.add('visor-abierto');
      visor.showModal();
      $('[data-visor-cerrar]', visor).focus();
    }

    foto.addEventListener('load', () => {
      cargando.hidden = true;
      foto.hidden = false;
      pintar();
    });
    foto.addEventListener('error', () => {
      if (!foto.getAttribute('src')) return;
      cargando.hidden = true;
      fallo.hidden = false;
      pintar();
    });

    visor.addEventListener('close', () => {
      raiz.classList.remove('visor-abierto');
      foto.removeAttribute('src');
      if (disparador && disparador.isConnected) disparador.focus();
      disparador = null;
    });

    document.addEventListener('click', (e) => {
      if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
      const enlace = e.target instanceof Element ? e.target.closest('a[data-visor]') : null;
      if (!enlace) return;
      e.preventDefault();
      abrirVisor(enlace);
    });

    const alPulsar = (boton, accion) => boton.addEventListener('click', () => {
      if (boton.getAttribute('aria-disabled') !== 'true') accion();
    });
    alPulsar(botonAcercar, () => acercarA(nivelSiguiente()));
    alPulsar(botonAlejar, () => acercarA(nivelAnterior()));
    alPulsar(botonAjustar, () => acercarA(1));
    $('[data-visor-cerrar]', visor).addEventListener('click', () => visor.close());

    visor.addEventListener('keydown', (e) => {
      if (e.ctrlKey || e.metaKey || e.altKey) return;
      const flechas = { ArrowLeft: [1, 0], ArrowRight: [-1, 0], ArrowUp: [0, 1], ArrowDown: [0, -1] };
      if (e.key === '+' || e.key === '=') acercarA(nivelSiguiente());
      else if (e.key === '-' || e.key === '_') acercarA(nivelAnterior());
      else if (e.key === '0') acercarA(1);
      else if (flechas[e.key] && escala > 1) {
        x += flechas[e.key][0] * PASO_FLECHAS;
        y += flechas[e.key][1] * PASO_FLECHAS;
        pintar();
      } else return;
      e.preventDefault();
    });

    lienzo.addEventListener('wheel', (e) => {
      if (foto.hidden) return;
      e.preventDefault();
      acercarA(escala * (e.deltaY < 0 ? 1.2 : 1 / 1.2), ...puntoEnLienzo(e));
    }, { passive: false });

    // Arrastre con un dedo o el mouse; pellizco con dos dedos.
    const punteros = new Map();
    let arrastre = null;
    let pellizco = null;
    let ultimoToque = null;
    let tipoPuntero = 'mouse';

    const distancia = (a, b) => Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY);

    function empezarArrastre(e) {
      arrastre = escala > 1 ? { x0: e.clientX - x, y0: e.clientY - y } : null;
      lienzo.toggleAttribute('data-arrastrando', Boolean(arrastre));
    }

    lienzo.addEventListener('pointerdown', (e) => {
      if (foto.hidden) return;
      tipoPuntero = e.pointerType;
      lienzo.setPointerCapture(e.pointerId);
      punteros.set(e.pointerId, e);
      if (punteros.size === 2) {
        const [a, b] = Array.from(punteros.values());
        pellizco = { distancia: distancia(a, b) || 1, escala };
        arrastre = null;
      } else {
        empezarArrastre(e);
      }
    });

    lienzo.addEventListener('pointermove', (e) => {
      if (!punteros.has(e.pointerId)) return;
      punteros.set(e.pointerId, e);
      if (pellizco && punteros.size === 2) {
        const [a, b] = Array.from(punteros.values());
        const centro = { clientX: (a.clientX + b.clientX) / 2, clientY: (a.clientY + b.clientY) / 2 };
        acercarA(pellizco.escala * (distancia(a, b) / pellizco.distancia), ...puntoEnLienzo(centro));
      } else if (arrastre) {
        x = e.clientX - arrastre.x0;
        y = e.clientY - arrastre.y0;
        pintar();
      }
    });

    function soltar(e) {
      if (!punteros.has(e.pointerId)) return;
      punteros.delete(e.pointerId);
      if (punteros.size < 2) pellizco = null;
      if (punteros.size === 1) empezarArrastre(Array.from(punteros.values())[0]);
      if (punteros.size === 0) {
        arrastre = null;
        lienzo.removeAttribute('data-arrastrando');
      }
    }

    lienzo.addEventListener('pointerup', (e) => {
      soltar(e);
      if (e.pointerType !== 'touch' || punteros.size > 0) return;
      // Doble toque: dos toques cortos y cercanos acercan o vuelven al 100 %.
      const ahora = Date.now();
      if (ultimoToque && ahora - ultimoToque.t < 300 && distancia(e, ultimoToque) < 30) {
        acercarA(escala > 1 ? 1 : 2, ...puntoEnLienzo(e));
        ultimoToque = null;
      } else {
        ultimoToque = { t: ahora, clientX: e.clientX, clientY: e.clientY };
      }
    });
    lienzo.addEventListener('pointercancel', soltar);

    lienzo.addEventListener('dblclick', (e) => {
      if (tipoPuntero === 'touch') return;
      acercarA(escala > 1 ? 1 : 2, ...puntoEnLienzo(e));
    });

    window.addEventListener('resize', () => { if (visor.open) pintar(); });
  }

  // ------------------------------------------------------------------
  // Esqueletos de carga: mientras el servidor arma la página siguiente,
  // <main> muestra la forma de esa vista en lugar del contenido anterior.
  // ------------------------------------------------------------------
  const principal = $('#contenido');
  const ESPERA_ESQUELETO_MS = 150;
  let temporizadorEsqueleto = null;

  const RUTAS_SIN_ESQUELETO = [/^\/logout/, /^\/login/, /^\/restablecer-password/, /\/excel$/, /\/permiso$/, /\/certificado$/];

  // Cada pantalla tiene su esqueleto (partials/componentes/esqueletos.ejs).
  // Una ruta sin esqueleto propio no muestra ninguno: mejor la página anterior
  // un momento que la forma de otra pantalla.
  const ESQUELETO_POR_SECCION = {
    solicitudes: 'solicitudes',
    gestores: 'gestores',
    ciudadanos: 'ciudadanos',
    materiales: 'materiales',
    autoridades: 'autoridades',
    reportes: 'reportes'
  };

  // Nombre del esqueleto para la URL de destino, o null si no lleva ninguno.
  function tipoEsqueleto(url) {
    const ruta = url.pathname.replace(/\/+$/, '') || '/';
    if (RUTAS_SIN_ESQUELETO.some((patron) => patron.test(ruta))) return null;
    if (ruta === '/' || ruta === '/dashboard') return 'inicio';
    if (/\/(nuevo|edit|editar)(\/|$)/.test(ruta)) return 'formulario';
    const detalle = ruta.match(/^\/(solicitudes|gestores)\/\d+$/);
    if (detalle) return detalle[1] === 'solicitudes' ? 'detalle-solicitud' : 'detalle-gestor';
    const seccion = ruta.split('/')[1];
    return ruta === `/${seccion}` ? ESQUELETO_POR_SECCION[seccion] || null : null;
  }

  // Mientras carga, la navegación ya marca la sección de destino: así el
  // clic se siente atendido. Si la carga se cancela, vuelve a la anterior.
  let navAnterior = null;

  function marcarNavegacion(url) {
    const seccion = url.pathname.split('/')[1] || 'dashboard';
    const destino = $$('.nav-item').find((enlace) => new URL(enlace.href).pathname.split('/')[1] === seccion);
    const actual = $('.nav-item[aria-current="page"]');
    if (!destino || destino === actual) return;
    navAnterior = actual;
    if (actual) actual.removeAttribute('aria-current');
    destino.setAttribute('aria-current', 'page');
  }

  function restaurarNavegacion() {
    if (navAnterior === null) return;
    $$('.nav-item[aria-current="page"]').forEach((enlace) => enlace.removeAttribute('aria-current'));
    if (navAnterior) navAnterior.setAttribute('aria-current', 'page');
    navAnterior = null;
  }

  function quitarEsqueleto() {
    clearTimeout(temporizadorEsqueleto);
    restaurarNavegacion();
    if (!principal) return;
    $$('[data-esqueleto]', principal).forEach((nodo) => nodo.remove());
    principal.removeAttribute('aria-busy');
  }

  function mostrarEsqueleto(destino) {
    if (!principal) return;
    let url;
    try { url = new URL(destino, location.href); } catch (e) { return; }
    if (url.origin !== location.origin) return;
    const tipo = tipoEsqueleto(url);
    const plantilla = tipo && document.getElementById(`esqueleto-${tipo}`);
    if (!plantilla) return;

    clearTimeout(temporizadorEsqueleto);
    // Solo aparece si la respuesta tarda: así no parpadea en cargas rápidas.
    temporizadorEsqueleto = setTimeout(() => {
      quitarEsqueleto();
      const envoltura = document.createElement('div');
      envoltura.setAttribute('data-esqueleto', '');
      const anuncio = document.createElement('p');
      anuncio.className = 'sr-only';
      anuncio.setAttribute('role', 'status');
      anuncio.textContent = 'Cargando…';
      envoltura.append(anuncio, plantilla.content.cloneNode(true));
      envoltura.lastElementChild.setAttribute('aria-hidden', 'true');
      principal.append(envoltura);
      principal.setAttribute('aria-busy', 'true');
      marcarNavegacion(url);
      // Si la tabla de la pantalla real no cabe, se ve en tarjetas: la del
      // esqueleto también, para que no cambie de forma al llegar.
      $$('.tabla-contenedor > .tabla:not([data-sin-apilar])', envoltura).forEach((tabla) => {
        prepararTabla(tabla);
        tabla.classList.toggle('tabla-apilada', tabla.parentElement.clientWidth < medirTabla(tabla));
      });
      window.scrollTo(0, 0);
    }, ESPERA_ESQUELETO_MS);
  }

  document.addEventListener('click', (e) => {
    if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    const enlace = e.target instanceof Element ? e.target.closest('a[href]') : null;
    if (!enlace || enlace.hasAttribute('download') || enlace.hasAttribute('data-sin-esqueleto')) return;
    if (enlace.target && enlace.target !== '_self') return;
    const url = new URL(enlace.href, location.href);
    // Un ancla dentro de la misma página no navega.
    if (url.hash && url.pathname === location.pathname && url.search === location.search) return;
    mostrarEsqueleto(url.href);
  });

  // Filtros, orden y búsquedas (GET). Los POST ya muestran «Guardando…».
  document.addEventListener('submit', (e) => {
    const form = e.target;
    if (e.defaultPrevented || !(form instanceof HTMLFormElement) || form.method !== 'get') return;
    if (form.target && form.target !== '_self') return;
    mostrarEsqueleto(form.action);
  });

  // Al volver con «Atrás» el navegador puede restaurar la página tal como quedó.
  window.addEventListener('pageshow', (e) => {
    if (e.persisted) quitarEsqueleto();
  });

  // ------------------------------------------------------------------
  // Tablas que no caben en su espacio: cada fila pasa a ser una tarjeta con
  // la etiqueta de su columna en cada dato (.tabla-apilada en input.css). Se
  // decide midiendo la tabla, no con un ancho fijo de pantalla, porque cada
  // lista necesita un ancho distinto.
  // ------------------------------------------------------------------
  // Texto que se ve en pantalla: sin íconos ni textos solo para lector de pantalla.
  function textoVisible(elemento) {
    const copia = elemento.cloneNode(true);
    $$('[aria-hidden="true"], .sr-only', copia).forEach((nodo) => nodo.remove());
    return copia.textContent.replace(/\s+/g, ' ').trim();
  }

  // Copia en cada celda el texto de su encabezado (data-etiqueta), que la
  // vista en tarjetas muestra junto al dato.
  function prepararTabla(tabla) {
    const encabezados = $$('thead th', tabla);
    // Roles explícitos: algunos navegadores dejan de anunciarla como tabla
    // cuando sus filas pasan a display: block.
    tabla.setAttribute('role', 'table');
    $$('thead, tbody, tfoot', tabla).forEach((grupo) => grupo.setAttribute('role', 'rowgroup'));
    $$('tr', tabla).forEach((fila) => {
      fila.setAttribute('role', 'row');
      Array.from(fila.children).forEach((celda, i) => {
        if (celda.closest('thead')) {
          celda.setAttribute('role', 'columnheader');
          return;
        }
        celda.setAttribute('role', celda.tagName === 'TH' ? 'rowheader' : 'cell');
        const encabezado = encabezados[i];
        if (celda.tagName !== 'TD' || !encabezado) return;
        const oculto = $('.sr-only', encabezado);
        const texto = textoVisible(encabezado);
        if (oculto && !texto) celda.setAttribute('data-celda-acciones', '');
        else celda.dataset.etiqueta = texto;
      });
    });
  }

  // Ancho mínimo con que la tabla se ve completa (min-content).
  function medirTabla(tabla) {
    tabla.classList.remove('tabla-apilada');
    tabla.style.width = '1px';
    const ancho = tabla.offsetWidth;
    tabla.style.width = '';
    return ancho;
  }

  const tablasApilables = $$('.tabla-contenedor > .tabla:not([data-sin-apilar])');
  if (tablasApilables.length && 'ResizeObserver' in window) {
    const anchos = new Map();
    const ajustar = (tabla) => {
      tabla.classList.toggle('tabla-apilada', tabla.parentElement.clientWidth < anchos.get(tabla));
    };
    const medirTodas = () => tablasApilables.forEach((tabla) => {
      anchos.set(tabla, medirTabla(tabla));
      ajustar(tabla);
    });

    tablasApilables.forEach(prepararTabla);
    medirTodas();
    // Las fuentes cambian el ancho del texto: se mide de nuevo cuando cargan.
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(medirTodas);
    const observador = new ResizeObserver((entradas) => entradas.forEach((entrada) => {
      const tabla = $('.tabla', entrada.target);
      if (tabla && anchos.has(tabla)) ajustar(tabla);
    }));
    tablasApilables.forEach((tabla) => observador.observe(tabla.parentElement));
  }

  // ------------------------------------------------------------------
  // Listas de materiales con búsqueda, «Todos» y «Ninguno»
  // ------------------------------------------------------------------
  $$('[data-lista-materiales]').forEach((lista) => {
    const filtro = $('[data-filtro-materiales]', lista);
    const contador = $('[data-contador-materiales]', lista);
    const items = $$('[data-material-item]', lista);
    const casillas = () => items.map((item) => $('input[type="checkbox"]', item));

    function contar() {
      if (!contador) return;
      const n = casillas().filter((c) => c.checked).length;
      contador.textContent = `${n} ${n === 1 ? 'material seleccionado' : 'materiales seleccionados'}`;
    }

    function visibles() {
      return items.filter((item) => !item.hidden).map((item) => $('input[type="checkbox"]', item));
    }

    if (filtro) {
      filtro.addEventListener('input', () => {
        const texto = filtro.value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim();
        items.forEach((item) => { item.hidden = Boolean(texto) && !(item.dataset.busqueda || '').includes(texto); });
      });
    }
    const todos = $('[data-marcar-todos]', lista);
    const ninguno = $('[data-marcar-ninguno]', lista);
    if (todos) todos.addEventListener('click', () => { visibles().forEach((c) => { c.checked = true; }); contar(); });
    if (ninguno) ninguno.addEventListener('click', () => { visibles().forEach((c) => { c.checked = false; }); contar(); });
    lista.addEventListener('change', contar);
    contar();
  });

  // ------------------------------------------------------------------
  // Permiso ambiental: el PDF se envía tal cual (application/pdf)
  // ------------------------------------------------------------------
  const formPermiso = $('#formPermiso');
  if (formPermiso) {
    formPermiso.addEventListener('submit', async (e) => {
      e.preventDefault();
      const campo = $('input[type="file"]', formPermiso);
      const archivo = campo.files && campo.files[0];
      if (!archivo) return marcarError(campo, 'Elige el PDF del permiso ambiental.');
      if (archivo.type !== 'application/pdf' && !/\.pdf$/i.test(archivo.name)) return marcarError(campo, 'El archivo debe ser un PDF.');
      if (archivo.size > 4 * 1024 * 1024) return marcarError(campo, 'El PDF supera los 4 MB. Comprímelo antes de subirlo.');
      limpiarError(campo);

      const boton = $('button[type="submit"]', formPermiso);
      const etiqueta = $('[data-etiqueta]', boton) || boton;
      const textoOriginal = etiqueta.textContent;
      boton.disabled = true;
      etiqueta.textContent = 'Subiendo…';
      try {
        const respuesta = await fetch(formPermiso.action, {
          method: 'POST',
          headers: { 'Content-Type': 'application/pdf', 'X-Requested-With': 'fetch', 'X-CSRF-Token': tokenCsrf, Accept: 'application/json' },
          body: archivo,
          credentials: 'same-origin'
        });
        const datos = await respuesta.json().catch(() => ({}));
        if (respuesta.ok && datos.redirigir) {
          window.location.href = datos.redirigir;
          return;
        }
        marcarError(campo, datos.mensaje || 'No pudimos subir el permiso. Intenta de nuevo.');
        campo.focus();
      } catch (err) {
        marcarError(campo, 'No pudimos conectarnos con el servidor. Revisa tu conexión e intenta de nuevo.');
      }
      boton.disabled = false;
      etiqueta.textContent = textoOriginal;
    });
  }

  // ------------------------------------------------------------------
  // Gráficos (Chart.js) con los colores de los tokens
  // ------------------------------------------------------------------
  // Una sola especificación para todos los gráficos del panel:
  // - Barras horizontales (los nombres se leen completos), de 20 px como
  //   máximo, extremo del dato redondeado a 4 px y base recta.
  // - Entre segmentos apilados, 2 px del color de la superficie: separan
  //   sin dibujar bordes.
  // - Rejilla de 1 px solo en el eje del valor; el eje de categorías es la
  //   línea base.
  // - El total va escrito al final de cada barra, en color de texto (nunca
  //   en el color de la serie).
  // - Tooltip: la cifra primero, luego el porcentaje. Responde a toda la
  //   franja de la barra, no solo a la barra pintada.
  // - El alto sale del número de barras: el eje nunca queda recortado.
  // - Leyenda y tabla van en el HTML, así se leen sin JavaScript, con lector
  //   de pantalla y al imprimir.
  const graficos = [];
  const cifraGrafico = new Intl.NumberFormat('es-CO', { maximumFractionDigits: 1 });
  const FUENTE_GRAFICO = "'Public Sans', system-ui, sans-serif";
  const BANDA_BARRA = 40;
  const ALTO_EJE = 36;
  let graficosDibujados = false;

  function colorToken(nombre) {
    return getComputedStyle(raiz).getPropertyValue(nombre).trim() || '#000000';
  }

  function porcentajeGrafico(parte, total) {
    if (!total) return '0 %';
    return `${cifraGrafico.format(Math.round((parte / total) * 1000) / 10)} %`;
  }

  function conUnidad(valor, unidad) {
    const [singular, varios] = unidad || ['', ''];
    return `${cifraGrafico.format(valor)} ${valor === 1 ? singular : varios}`.trim();
  }

  const valorDe = (dataset, i) => Number(dataset.data[i]) || 0;

  // ¿Es el último (o el primer) segmento con valor de su pila? Solo los
  // extremos llevan las esquinas redondeadas; el último no lleva separación.
  function extremoDePila(contexto, haciaAdelante) {
    const { datasets } = contexto.chart.data;
    const paso = haciaAdelante ? 1 : -1;
    for (let k = contexto.datasetIndex + paso; k >= 0 && k < datasets.length; k += paso) {
      if (contexto.chart.isDatasetVisible(k) && valorDe(datasets[k], contexto.dataIndex) > 0) return false;
    }
    return true;
  }

  // Suma de la barra i contando solo las series visibles en la leyenda.
  function totalDeFila(grafico, i) {
    return grafico.data.datasets.reduce((suma, d, k) => suma + (grafico.isDatasetVisible(k) ? valorDe(d, i) : 0), 0);
  }

  // Escribe el total al final de cada barra.
  const pluginTotales = {
    id: 'totales',
    afterDatasetsDraw(grafico, argumentos, opciones) {
      const metas = grafico.getSortedVisibleDatasetMetas();
      if (!metas.length) return;
      const { ctx } = grafico;
      ctx.save();
      ctx.font = `600 13px ${FUENTE_GRAFICO}`;
      ctx.fillStyle = opciones.color;
      ctx.textBaseline = 'middle';
      ctx.textAlign = 'left';
      grafico.data.labels.forEach((etiqueta, i) => {
        const barra = metas[0].data[i];
        if (!barra) return;
        const total = totalDeFila(grafico, i);
        ctx.fillText(cifraGrafico.format(total), grafico.scales.x.getPixelForValue(total) + 8, barra.y);
      });
      ctx.restore();
    }
  };

  function estiloTooltip() {
    const texto = colorToken('--md-sys-color-inverse-on-surface');
    return {
      backgroundColor: colorToken('--md-sys-color-inverse-surface'),
      titleColor: texto,
      bodyColor: texto,
      footerColor: texto,
      titleFont: { family: FUENTE_GRAFICO, size: 13, weight: '600' },
      bodyFont: { family: FUENTE_GRAFICO, size: 13 },
      footerFont: { family: FUENTE_GRAFICO, size: 13, weight: '600' },
      padding: 12,
      cornerRadius: 8,
      caretSize: 6,
      boxWidth: 10,
      boxHeight: 10,
      boxPadding: 6,
      borderWidth: 0
    };
  }

  const sumaFila = (datos, i) => datos.series.reduce((suma, s) => suma + (Number(s.valores[i]) || 0), 0);

  // Barras de una serie, o apiladas por categoría.
  function configuracionBarras(datos, lienzo) {
    const apilado = datos.tipo === 'apiladas';
    const superficie = colorToken('--md-sys-color-surface-container-lowest');
    const totales = datos.etiquetas.map((e, i) => sumaFila(datos, i));
    const totalGeneral = totales.reduce((a, b) => a + b, 0);

    // Alto: una banda por barra más el eje.
    lienzo.parentElement.style.height = `${datos.etiquetas.length * BANDA_BARRA + ALTO_EJE}px`;

    // Aire a la derecha para que quepa el total más largo.
    const medidor = document.createElement('canvas').getContext('2d');
    medidor.font = `600 13px ${FUENTE_GRAFICO}`;
    const aire = Math.ceil(medidor.measureText(cifraGrafico.format(Math.max(0, ...totales))).width) + 16;

    return {
      type: 'bar',
      plugins: [pluginTotales],
      data: {
        labels: datos.etiquetas,
        datasets: datos.series.map((s) => ({
          label: s.nombre,
          data: s.valores,
          backgroundColor: colorToken(s.color),
          borderColor: superficie,
          borderWidth: (contexto) => (apilado && !extremoDePila(contexto, true) ? { right: 2 } : 0),
          borderSkipped: false,
          borderRadius: (contexto) => (extremoDePila(contexto, true) ? { topRight: 4, bottomRight: 4 } : 0),
          barThickness: 20
        }))
      },
      options: {
        indexAxis: 'y',
        layout: { padding: { right: aire } },
        interaction: { mode: 'index', axis: 'y', intersect: false },
        plugins: {
          legend: { display: false },
          totales: { color: colorToken('--md-sys-color-on-surface') },
          tooltip: {
            ...estiloTooltip(),
            displayColors: apilado,
            filter: (item) => !apilado || item.raw > 0,
            callbacks: {
              label: (item) => (apilado
                ? ` ${item.dataset.label}: ${cifraGrafico.format(item.raw)} (${porcentajeGrafico(item.raw, totales[item.dataIndex])})`
                : `${conUnidad(item.raw, datos.unidad)} · ${porcentajeGrafico(item.raw, totalGeneral)} del total`),
              footer: (items) => {
                if (!apilado || !items.length) return '';
                const total = totales[items[0].dataIndex];
                return `Total: ${conUnidad(total, datos.unidad)} · ${porcentajeGrafico(total, totalGeneral)} del total`;
              }
            }
          }
        },
        scales: {
          x: {
            stacked: apilado,
            beginAtZero: true,
            grid: { color: colorToken('--eco-graf-rejilla'), lineWidth: 1, drawTicks: false },
            border: { display: false },
            ticks: { precision: 0, padding: 8, maxTicksLimit: 6, callback: (valor) => cifraGrafico.format(valor) }
          },
          y: {
            stacked: apilado,
            grid: { display: false },
            border: { color: colorToken('--md-sys-color-outline'), width: 1 },
            ticks: { color: colorToken('--md-sys-color-on-surface'), padding: 8, font: { size: 13 } }
          }
        }
      }
    };
  }

  // Parte de un todo: una sola barra al 100 %, un segmento por parte.
  function configuracionProporcion(datos) {
    const superficie = colorToken('--md-sys-color-surface-container-lowest');
    const total = sumaFila(datos, 0);
    return {
      type: 'bar',
      data: {
        labels: datos.etiquetas,
        datasets: datos.series.map((s) => ({
          label: s.nombre,
          data: s.valores,
          backgroundColor: colorToken(s.color),
          borderColor: superficie,
          borderWidth: (contexto) => (extremoDePila(contexto, true) ? 0 : { right: 2 }),
          borderSkipped: false,
          borderRadius: (contexto) => {
            const primero = extremoDePila(contexto, false) ? 4 : 0;
            const ultimo = extremoDePila(contexto, true) ? 4 : 0;
            return { topLeft: primero, bottomLeft: primero, topRight: ultimo, bottomRight: ultimo };
          },
          barThickness: 24
        }))
      },
      options: {
        indexAxis: 'y',
        layout: { padding: 0 },
        interaction: { mode: 'nearest', axis: 'x', intersect: true },
        plugins: {
          legend: { display: false },
          tooltip: {
            ...estiloTooltip(),
            displayColors: true,
            callbacks: {
              title: () => '',
              label: (item) => ` ${item.dataset.label}: ${conUnidad(item.raw, datos.unidad)} (${porcentajeGrafico(item.raw, total)})`
            }
          }
        },
        scales: {
          x: { stacked: true, display: false, min: 0, max: total },
          y: { stacked: true, display: false }
        }
      }
    };
  }

  // Dibuja cada <canvas data-grafico> con los datos del <script> JSON que
  // nombra. Se vuelve a llamar al cambiar de tema, porque los colores salen de
  // las variables CSS.
  function dibujarGraficos() {
    if (!window.Chart) return;
    graficos.forEach((g) => g.destroy());
    graficos.length = 0;
    const sinMovimiento = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    window.Chart.defaults.font.family = FUENTE_GRAFICO;
    window.Chart.defaults.font.size = 12;
    window.Chart.defaults.color = colorToken('--md-sys-color-on-surface-variant');

    $$('canvas[data-grafico]').forEach((lienzo) => {
      const fuente = document.getElementById(lienzo.dataset.grafico);
      if (!fuente) return;
      let datos;
      try { datos = JSON.parse(fuente.textContent); } catch (e) { return; }
      if (!datos || !Array.isArray(datos.series) || !Array.isArray(datos.etiquetas)) return;
      const configuracion = datos.tipo === 'proporcion' ? configuracionProporcion(datos) : configuracionBarras(datos, lienzo);
      configuracion.options.responsive = true;
      configuracion.options.maintainAspectRatio = false;
      // Al cambiar de tema se redibuja sin animar: solo cambian los colores.
      configuracion.options.animation = sinMovimiento || graficosDibujados ? false : { duration: 400, easing: 'easeOutQuart' };
      graficos.push(new window.Chart(lienzo, configuracion));
    });
    graficosDibujados = true;
  }

  dibujarGraficos();
  document.addEventListener('tema-cambiado', dibujarGraficos);
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', dibujarGraficos);

  // Barras de datos en las tablas: el ancho es la proporción de la fila.
  $$('[data-proporcion]').forEach((barra) => {
    const proporcion = Math.min(1, Math.max(0, Number(barra.dataset.proporcion) || 0));
    barra.style.width = `${proporcion * 100}%`;
  });

  // ------------------------------------------------------------------
  // Sesión: se renueva con la actividad y avisa 2 minutos antes de vencer
  // ------------------------------------------------------------------
  const duracionSesion = Number(document.body.dataset.sesionMs) || 0;
  const dialogoSesion = $('#dialogoSesion');
  const CLAVE_BORRADOR = `borrador:${location.pathname}`;

  // motivo: 'sesion' (venció la sesión) o 'envio' (se envió el formulario).
  function guardarBorradores(motivo) {
    const formularios = $$('form[data-conservar]');
    if (formularios.length === 0) return;
    const datos = {};
    formularios.forEach((form) => {
      $$('input, textarea, select', form).forEach((campo) => {
        if (!campo.name || !campo.id || ['hidden', 'password', 'file', 'submit'].includes(campo.type)) return;
        datos[campo.id] = campo.type === 'checkbox' ? campo.checked : campo.value;
      });
    });
    try { sessionStorage.setItem(CLAVE_BORRADOR, JSON.stringify({ motivo, datos })); } catch (e) { /* sin almacenamiento */ }
  }

  // Tras un envío solo se recupera si el servidor devolvió un error; tras
  // vencer la sesión, siempre.
  function restaurarBorradores() {
    let borrador = null;
    try {
      borrador = JSON.parse(sessionStorage.getItem(CLAVE_BORRADOR) || 'null');
      sessionStorage.removeItem(CLAVE_BORRADOR);
    } catch (e) { return; }
    if (!borrador || !borrador.datos) return;
    const huboError = Boolean($('[data-aviso-error]'));
    if (borrador.motivo === 'envio' && !huboError) return;
    Object.entries(borrador.datos).forEach(([id, valor]) => {
      const campo = document.getElementById(id);
      if (!campo) return;
      if (campo.type === 'checkbox') campo.checked = Boolean(valor); else campo.value = valor;
    });
    mostrarNotificacion(borrador.motivo === 'sesion'
      ? 'Recuperamos lo que estabas escribiendo antes de que se cerrara la sesión. Revísalo y guarda.'
      : 'Recuperamos lo que escribiste. Corrige lo que indica el error y guarda de nuevo.');
  }
  restaurarBorradores();

  if (duracionSesion > 0 && dialogoSesion) {
    const AVISO_MS = 2 * 60 * 1000;
    let vence = Date.now() + duracionSesion;
    let ultimaRenovacion = Date.now();
    let renovando = false;

    // Guarda lo escrito y lleva al login, que después devuelve a esta página.
    const expirar = () => {
      guardarBorradores('sesion');
      const volver = encodeURIComponent(location.pathname + location.search);
      window.location.href = `/login?aviso=sesion-vencida&volver=${volver}`;
    };

    async function renovar() {
      if (renovando) return;
      renovando = true;
      try {
        const respuesta = await fetch('/sesion/renovar', {
          method: 'POST',
          headers: { 'X-Requested-With': 'fetch', 'X-CSRF-Token': tokenCsrf, Accept: 'application/json' },
          credentials: 'same-origin'
        });
        if (respuesta.status === 401) return expirar();
        if (respuesta.ok) {
          vence = Date.now() + duracionSesion;
          ultimaRenovacion = Date.now();
          if (dialogoSesion.open) dialogoSesion.close();
        }
      } catch (e) {
        // Sin conexión: se intenta de nuevo con la próxima actividad.
      } finally {
        renovando = false;
      }
    }

    // Con actividad se renueva como máximo una vez por minuto.
    const alActuar = () => {
      if (Date.now() - ultimaRenovacion > 60 * 1000 && !dialogoSesion.open) renovar();
    };
    ['keydown', 'pointerdown', 'input', 'scroll'].forEach((evento) => {
      window.addEventListener(evento, alActuar, { passive: true });
    });

    $('#botonSeguirConectado').addEventListener('click', renovar);

    setInterval(() => {
      const restante = vence - Date.now();
      if (restante <= 0) return expirar();
      if (restante <= AVISO_MS && !dialogoSesion.open) {
        dialogoSesion.showModal();
        $('#botonSeguirConectado').focus();
      }
    }, 5000);
  }
})();
