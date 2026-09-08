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
