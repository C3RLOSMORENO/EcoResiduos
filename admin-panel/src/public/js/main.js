/**
 * EcoManager - Sistema Global de Validaciones, Modales y Utilidades M3
 */

// ==========================================================================
// 1. MOTOR GLOBAL DE VALIDACIÓN EN TIEMPO REAL
// ==========================================================================
document.addEventListener('input', (e) => {
  const target = e.target;
  if (!target) return;
  
  // Solo números y guion (NIT)
  if (target.matches('[data-format="nit"]')) {
    target.value = target.value.replace(/[^0-9\-]/g, '');
  }
  
  // Solo números, espacios y símbolo + (Teléfono)
  if (target.matches('[data-format="phone"]')) {
    target.value = target.value.replace(/[^0-9\+\s]/g, '');
  }
  
  // Solo números enteros
  if (target.matches('[data-format="numeric"]')) {
    target.value = target.value.replace(/[^0-9]/g, '');
  }
  
  // Forzar mayúsculas (Códigos RESPEL, Siglas)
  if (target.matches('[data-format="uppercase"]')) {
    target.value = target.value.toUpperCase();
  }
});

// ==========================================================================
// 2. FUNCIÓN GLOBAL DE COLORES TONALES PARA RESIDUOS (M3)
// ==========================================================================
window.obtenerClaseResiduo = function(codigo) {
  if (!codigo) return 'chip-respel-neutral';
  const c = String(codigo).toUpperCase().trim();

  // 1. Biológicos / Hospitalarios / Patológicos
  if (c.startsWith('Y1') || c.startsWith('Y2') || c.startsWith('Y3') || c.includes('BIO') || c.includes('HOSP')) {
    return 'chip-respel-bio';
  }
  
  // 2. Aceites / Hidrocarburos / Solventes
  if (c.startsWith('Y8') || c.startsWith('Y9') || c.includes('ACEITE') || c.includes('HIDRO')) {
    return 'chip-respel-oil';
  }

  // 3. RAEE / Baterías / Mercurio / Plomo
  if (c.startsWith('RAEE') || c.startsWith('Y26') || c.startsWith('Y29') || c.includes('ELEC') || c.includes('METAL')) {
    return 'chip-respel-raee';
  }

  // 4. Aprovechables / Orgánicos / Reciclables
  if (c.startsWith('REC') || c.startsWith('ORG') || c.includes('PLAST') || c.includes('CART')) {
    return 'chip-respel-eco';
  }

  return 'chip-respel-neutral';
};

// ==========================================================================
// 3. CONTROLADORES GLOBALES DE MODALES
// ==========================================================================
window.abrirModalUI = function(id) {
  const modal = document.getElementById(id);
  if (modal) {
    modal.classList.remove('hidden');
    modal.classList.add('flex');
    document.body.classList.add('overflow-hidden');
  }
};

window.cerrarModalUI = function(id) {
  const modal = document.getElementById(id);
  if (modal) {
    modal.classList.add('hidden');
    modal.classList.remove('flex');
    document.body.classList.remove('overflow-hidden');
  }
};

// Listener global para cerrar modales al presionar la tecla Escape o hacer clic fuera (scrim)
document.addEventListener('DOMContentLoaded', () => {
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      const modalesAbiertos = document.querySelectorAll('.modal-scrim.flex');
      modalesAbiertos.forEach((m) => {
        m.classList.add('hidden');
        m.classList.remove('flex');
      });
      document.body.classList.remove('overflow-hidden');
    }
  });

  const scrims = document.querySelectorAll('.modal-scrim');
  scrims.forEach((scrim) => {
    scrim.addEventListener('click', (e) => {
      if (e.target === scrim) {
        scrim.classList.add('hidden');
        scrim.classList.remove('flex');
        document.body.classList.remove('overflow-hidden');
      }
    });
  });
});

// ==========================================================================
// 4. SISTEMA GLOBAL DE NOTIFICACIONES TOAST (SUPERIOR CENTRAL M3)
// ==========================================================================
window.mostrarNotificacion = function(mensaje, esError = false) {
  let container = document.getElementById('m3SnackbarContainer');
  if (!container) {
    container = document.createElement('div');
    container.id = 'm3SnackbarContainer';
    container.className = 'fixed top-6 left-1/2 -translate-x-1/2 z-50 flex flex-col items-center gap-2 pointer-events-none max-w-sm sm:max-w-md w-full px-4';
    document.body.appendChild(container);
  }

  const toast = document.createElement('div');
  toast.className = 'pointer-events-auto w-full flex items-center gap-3 rounded-2xl bg-white dark:bg-[#1E293B] border border-slate-200/90 dark:border-slate-700/80 px-4 py-3.5 text-slate-800 dark:text-slate-100 shadow-xl shadow-slate-900/10 dark:shadow-black/30 transition-all duration-300 transform -translate-y-4 opacity-0';
  toast.setAttribute('role', 'status');
  toast.setAttribute('aria-live', 'polite');

  const iconColor = esError ? 'bg-rose-50 text-rose-600 dark:bg-rose-950/40 dark:text-rose-400' : 'bg-emerald-50 text-emerald-600 dark:bg-emerald-950/40 dark:text-emerald-400';
  const iconName = esError ? 'error' : 'check_circle';

  toast.innerHTML = `
    <div class="flex h-7 w-7 shrink-0 items-center justify-center rounded-xl ${iconColor}">
      <span class="material-symbols-outlined text-lg" aria-hidden="true">${iconName}</span>
    </div>
    <p class="text-xs font-medium leading-snug flex-1">${mensaje}</p>
    <button type="button" aria-label="Cerrar notificación" class="inline-flex h-6 w-6 items-center justify-center rounded-full text-slate-400 hover:text-slate-700 dark:text-slate-500 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition">
      <span class="material-symbols-outlined text-base" aria-hidden="true">close</span>
    </button>
  `;

  toast.querySelector('button').addEventListener('click', () => window.cerrarSnackbar(toast));

  container.appendChild(toast);

  requestAnimationFrame(() => {
    toast.classList.remove('-translate-y-4', 'opacity-0');
    toast.classList.add('translate-y-0', 'opacity-100');
  });

  setTimeout(() => {
    window.cerrarSnackbar(toast);
  }, 4000);
};

window.cerrarSnackbar = function(el) {
  const snackbar = el || document.getElementById('m3Snackbar');
  if (snackbar) {
    snackbar.classList.remove('translate-y-0', 'opacity-100');
    snackbar.classList.add('-translate-y-4', 'opacity-0');
    setTimeout(() => snackbar.remove(), 300);
  }
};

