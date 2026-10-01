/*
 * Comportamiento del panel. Todo es mejora progresiva: sin JavaScript los
 * formularios se envían igual y el servidor valida.
 */
(function () {
  'use strict';

  const $ = (selector, raiz) => (raiz || document).querySelector(selector);
  const $$ = (selector, raiz) => Array.from((raiz || document).querySelectorAll(selector));

  // ------------------------------------------------------------------
  // Formato de campos (data-format)
  // ------------------------------------------------------------------
  document.addEventListener('input', (e) => {
    const campo = e.target;
    if (!(campo instanceof HTMLInputElement)) return;
    if (campo.matches('[data-format="nit"]')) campo.value = campo.value.replace(/[^0-9-]/g, '');
    if (campo.matches('[data-format="phone"]')) campo.value = campo.value.replace(/[^0-9+\s]/g, '');
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
      return;
    }
    const region = $('#avisosEstado');
    if (!region) return;
    const aviso = document.createElement('div');
    aviso.className = 'aviso';
    const texto = document.createElement('p');
    texto.className = 'flex-1';
    texto.textContent = mensaje;
    const cerrar = document.createElement('button');
    cerrar.type = 'button';
    cerrar.className = 'btn-icono';
    cerrar.setAttribute('aria-label', 'Cerrar aviso');
    cerrar.innerHTML = '<span class="material-symbols-outlined icono-20" aria-hidden="true">close</span>';
    cerrar.addEventListener('click', () => cerrarAviso(aviso));
    aviso.append(texto, cerrar);
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
  // Tema claro u oscuro (interruptor manual que se recuerda)
  // ------------------------------------------------------------------
  const raiz = document.documentElement;
  const botonTema = $('#botonTema');

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
  // Esqueletos de carga: mientras el servidor arma la página siguiente,
  // <main> muestra la forma de esa vista en lugar del contenido anterior.
  // ------------------------------------------------------------------
  const principal = $('#contenido');
  const ESPERA_ESQUELETO_MS = 150;
  let temporizadorEsqueleto = null;

  // Rutas que descargan, abren un archivo o salen del panel: sin esqueleto.
  const RUTAS_SIN_ESQUELETO = [/^\/logout/, /^\/login/, /^\/restablecer-password/, /\/csv$/, /\/permiso$/];

  function tipoEsqueleto(url) {
    const ruta = url.pathname.replace(/\/+$/, '') || '/';
    if (RUTAS_SIN_ESQUELETO.some((patron) => patron.test(ruta))) return null;
    if (ruta === '/' || ruta === '/dashboard') return 'inicio';
    if (/\/(nuevo|edit|editar)(\/|$)/.test(ruta)) return 'formulario';
    if (/^\/(solicitudes|gestores)\/\d+$/.test(ruta)) return 'detalle';
    return 'lista';
  }

  function quitarEsqueleto() {
    clearTimeout(temporizadorEsqueleto);
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
      if (archivo.size > 10 * 1024 * 1024) return marcarError(campo, 'El PDF supera los 10 MB.');
      limpiarError(campo);

      const boton = $('button[type="submit"]', formPermiso);
      const etiqueta = $('[data-etiqueta]', boton) || boton;
      const textoOriginal = etiqueta.textContent;
      boton.disabled = true;
      etiqueta.textContent = 'Subiendo…';
      try {
        const respuesta = await fetch(formPermiso.action, {
          method: 'POST',
          headers: { 'Content-Type': 'application/pdf', 'X-Requested-With': 'fetch', Accept: 'application/json' },
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
  const graficos = [];

  function colorToken(nombre) {
    return getComputedStyle(raiz).getPropertyValue(nombre).trim() || '#000000';
  }

  function dibujarGraficos() {
    if (!window.Chart) return;
    graficos.forEach((g) => g.destroy());
    graficos.length = 0;
    const sinMovimiento = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    window.Chart.defaults.font.family = "'Public Sans', system-ui, sans-serif";
    window.Chart.defaults.color = colorToken('--md-sys-color-on-surface-variant');

    $$('canvas[data-grafico]').forEach((lienzo) => {
      const fuente = document.getElementById(lienzo.dataset.grafico);
      if (!fuente) return;
      let datos;
      try { datos = JSON.parse(fuente.textContent); } catch (e) { return; }
      const colores = (datos.colores || []).map(colorToken);
      const esDona = datos.tipo === 'doughnut';
      graficos.push(new window.Chart(lienzo, {
        type: datos.tipo,
        data: {
          labels: datos.etiquetas,
          datasets: [{
            label: datos.serie,
            data: datos.valores,
            backgroundColor: esDona ? colores : colores[0],
            borderColor: colorToken('--md-sys-color-surface-container-lowest'),
            borderWidth: esDona ? 2 : 0,
            borderRadius: esDona ? 0 : 8,
            maxBarThickness: 48
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          animation: sinMovimiento ? false : { duration: 300 },
          cutout: esDona ? '60%' : undefined,
          plugins: {
            legend: {
              display: esDona,
              position: 'bottom',
              labels: {
                // La leyenda lleva el valor: la serie no se distingue solo por color.
                generateLabels: (grafico) => window.Chart.overrides.doughnut.plugins.legend.labels.generateLabels(grafico)
                  .map((item, i) => Object.assign(item, { text: `${item.text}: ${datos.valores[i]}` }))
              }
            }
          },
          scales: esDona ? {} : {
            y: { beginAtZero: true, ticks: { precision: 0 }, grid: { color: colorToken('--md-sys-color-outline-variant') } },
            x: { grid: { display: false } }
          }
        }
      }));
    });
  }

  dibujarGraficos();
  document.addEventListener('tema-cambiado', dibujarGraficos);
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', dibujarGraficos);

  // ------------------------------------------------------------------
  // Sesión: se renueva con la actividad y avisa 2 minutos antes de vencer
  // ------------------------------------------------------------------
  const duracionSesion = Number(document.body.dataset.sesionMs) || 0;
  const dialogoSesion = $('#dialogoSesion');
  const CLAVE_BORRADOR = `borrador:${location.pathname}`;

  // motivo: 'sesion' (venció la sesión) o 'envio' (se envió el formulario).
  function guardarBorradores(motivo) {
    const formularios = $('form[data-conservar]');
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

    const expirar = () => {
      guardarBorradores('sesion');
      const volver = encodeURIComponent(location.pathname + location.search);
      window.location.href = `/login?msg=${encodeURIComponent('Tu sesión venció por inactividad. Inicia sesión para continuar donde ibas.')}&type=error&volver=${volver}`;
    };

    async function renovar() {
      if (renovando) return;
      renovando = true;
      try {
        const respuesta = await fetch('/sesion/renovar', {
          method: 'POST',
          headers: { 'X-Requested-With': 'fetch', Accept: 'application/json' },
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
