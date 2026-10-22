// Mismas etiquetas y formatos que la app (app/lib/theme/eco_colors.dart y
// app/lib/utils/formato.dart), para que el panel y la app digan lo mismo.

const ZONA_HORARIA = 'America/Bogota';

const CATEGORIAS = {
    APROVECHABLE: 'Aprovechable',
    PELIGROSO: 'Peligroso (RESPEL)',
    RAEE: 'RAEE',
    RCD: 'Escombros (RCD)',
    RIESGO_BIOLOGICO: 'Riesgo biológico',
    ORGANICO: 'Orgánico',
    ORDINARIO: 'Ordinario'
};

// Las que el panel deja asignar a un material del catálogo.
const CATEGORIAS_CATALOGO = ['APROVECHABLE', 'PELIGROSO', 'RAEE', 'RCD', 'RIESGO_BIOLOGICO'];

const ESTADOS = {
    PUBLICADO: 'Publicado',
    EN_NEGOCIACION: 'En negociación',
    RECOLECTADO: 'Recolectado',
    CANCELADO: 'Cancelado',
    PROPUESTA: 'Propuesta enviada',
    ACEPTADA: 'Aceptada',
    RECHAZADA: 'Rechazada',
    NO_SELECCIONADA: 'Asignada a otro gestor',
    ASIGNADA_OTRO: 'Asignada a otro gestor'
};

const ESTADOS_SOLICITUD = ['PUBLICADO', 'EN_NEGOCIACION', 'RECOLECTADO', 'CANCELADO'];

const ESTADOS_VERIFICACION = {
    PENDIENTE: 'Por revisar',
    APROBADO: 'Aprobado',
    RECHAZADO: 'Rechazado',
    SUSPENDIDO: 'Suspendido'
};

// Estados de verificación de un gestor, en el orden de los selectores.
const ESTADOS_GESTOR = Object.keys(ESTADOS_VERIFICACION);

const TIPOS_VALOR = {
    COBRO_RECOLECCION: 'Valor cobrado por recolección externa',
    PAGO_APROVECHAMIENTO: 'Valor pagado por aprovechamiento'
};

const TIPOS_CERTIFICADO = {
    DISPOSICION_FINAL: 'Certificado o acta de disposición final',
    APROVECHAMIENTO: 'Certificado o acta de aprovechamiento'
};

const UNIDADES = {
    KG: 'kg',
    TON: 't',
    UNIDADES: 'unidades',
    LITROS: 'L',
    GALONES: 'galones',
    CANECAS: 'canecas',
    M3: 'm³'
};

const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

const clave = (valor) => String(valor || '').trim().toUpperCase();

/**
 * @param {?string} valor Código de la categoría (APROVECHABLE, RAEE…).
 * @returns {string} Nombre para mostrar; el valor tal cual si no es conocido.
 */
function etiquetaCategoria(valor) {
    if (!clave(valor)) return 'Sin categoría';
    return CATEGORIAS[clave(valor)] || String(valor);
}

/**
 * @param {?string} valor Estado de una solicitud o de una postulación.
 * @returns {string} Nombre para mostrar; el valor tal cual si no es conocido.
 */
function etiquetaEstado(valor) {
    if (!clave(valor)) return 'Sin dato';
    return ESTADOS[clave(valor)] || String(valor);
}

/**
 * @param {?string} valor Estado de verificación de un gestor.
 * @returns {string} Nombre para mostrar; el valor tal cual si no es conocido.
 */
function etiquetaVerificacion(valor) {
    if (!clave(valor)) return 'Sin dato';
    return ESTADOS_VERIFICACION[clave(valor)] || String(valor);
}

/**
 * @param {?string} valor COBRO_RECOLECCION o PAGO_APROVECHAMIENTO.
 * @returns {string}
 */
function etiquetaTipoValor(valor) {
    return TIPOS_VALOR[clave(valor)] || 'Sin valor propuesto';
}

/**
 * @param {?string} valor DISPOSICION_FINAL o APROVECHAMIENTO.
 * @returns {string}
 */
function etiquetaCertificado(valor) {
    return TIPOS_CERTIFICADO[clave(valor)] || 'Certificado';
}

/**
 * Sufijo de las variables CSS --eco-cat-* (app: categoriaFromString).
 *
 * @param {?string} valor Código de la categoría, incluidos los nombres antiguos.
 * @returns {string}
 */
function claseCategoria(valor) {
    switch (clave(valor)) {
        case 'PELIGROSO':
        case 'RESPEL':
            return 'peligroso';
        case 'RAEE':
            return 'raee';
        case 'RCD':
        case 'ESCOMBROS':
            return 'rcd';
        case 'RIESGO_BIOLOGICO':
        case 'BIOLOGICO':
            return 'riesgo-biologico';
        case 'ORGANICO':
            return 'organico';
        case 'ORDINARIO':
            return 'ordinario';
        case 'APROVECHABLE':
            return 'aprovechable';
        default:
            return 'neutro';
    }
}

/**
 * Sufijo de las variables CSS --eco-estado-* (app: estadoFromString).
 *
 * @param {?string} valor
 * @returns {string}
 */
function claseEstado(valor) {
    switch (clave(valor)) {
        case 'EN_NEGOCIACION':
            return 'en-negociacion';
        case 'PROPUESTA':
            return 'propuesta';
        case 'RECOLECTADO':
            return 'recolectado';
        case 'ACEPTADA':
            return 'aceptada';
        case 'CANCELADO':
            return 'cancelado';
        case 'RECHAZADA':
            return 'rechazada';
        case 'NO_SELECCIONADA':
        case 'ASIGNADA_OTRO':
            return 'no-seleccionada';
        case 'PUBLICADO':
            return 'publicado';
        default:
            return 'cancelado';
    }
}

/**
 * Sufijo de --eco-estado-* para el estado de verificación de un gestor: se
 * reutilizan los colores de los estados de solicitud.
 *
 * @param {?string} valor
 * @returns {string}
 */
function claseVerificacion(valor) {
    switch (clave(valor)) {
        case 'APROBADO':
            return 'recolectado';
        case 'PENDIENTE':
            return 'en-negociacion';
        case 'RECHAZADO':
            return 'error';
        default:
            return 'cancelado';
    }
}

const ICONOS_ESTADO = {
    PUBLICADO: 'campaign',
    EN_NEGOCIACION: 'handshake',
    RECOLECTADO: 'local_shipping',
    CANCELADO: 'block',
    PROPUESTA: 'schedule_send',
    ACEPTADA: 'check_circle',
    RECHAZADA: 'cancel',
    NO_SELECCIONADA: 'person_off',
    ASIGNADA_OTRO: 'person_off',
    PENDIENTE: 'hourglass_top',
    APROBADO: 'verified',
    RECHAZADO: 'cancel',
    SUSPENDIDO: 'pause_circle'
};

const iconoEstado = (valor) => ICONOS_ESTADO[clave(valor)] || 'radio_button_unchecked';

/**
 * @param {?string} unidad Código de la unidad (KG, TON, M3…).
 * @returns {string} Abreviatura para mostrar junto a la cantidad.
 */
function unidadCorta(unidad) {
    return UNIDADES[clave(unidad)] || String(unidad || '').toLowerCase();
}

/**
 * Cifra sin decimales innecesarios, coma decimal y punto de miles.
 *
 * @param {number|string} valor
 * @param {number} [decimales] Decimales máximos cuando la cifra no es entera.
 * @returns {string}
 */
function formatoNumero(valor, decimales = 1) {
    const n = Number(valor);
    if (!Number.isFinite(n)) return '0';
    return new Intl.NumberFormat('es-CO', {
        maximumFractionDigits: Number.isInteger(n) ? 0 : decimales,
        minimumFractionDigits: 0
    }).format(n);
}

/**
 * «34,5 %», con espacio antes del signo (norma de la RAE y del SI) y un
 * decimal como máximo. Sin total no hay proporción que mostrar.
 *
 * @param {number} parte
 * @param {number} total
 * @returns {string}
 */
function formatoPorcentaje(parte, total) {
    const p = Number(parte);
    const t = Number(total);
    if (!Number.isFinite(p) || !Number.isFinite(t) || t <= 0) return '0 %';
    return `${formatoNumero(Math.round((p / t) * 1000) / 10)} %`;
}

/**
 * @param {?number} cantidad
 * @param {?string} unidad Código de la unidad.
 * @returns {string} «12,5 kg», o «Sin dato» si no hay cantidad.
 */
function formatoCantidad(cantidad, unidad) {
    if (cantidad === null || cantidad === undefined || cantidad === '') return 'Sin dato';
    return `${formatoNumero(cantidad)} ${unidadCorta(unidad)}`.trim();
}

/**
 * @param {number|string} valor Se descartan los decimales.
 * @returns {string} El entero con punto de miles: 1250000 → «1.250.000».
 */
function separarMiles(valor) {
    const entero = Math.trunc(Number(valor) || 0);
    const digitos = String(Math.abs(entero)).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
    return entero < 0 ? `-${digitos}` : digitos;
}

/**
 * «$ 1.250.000», igual que formatoPesos en la app.
 *
 * @param {?number} valor
 * @returns {string}
 */
function formatoPesos(valor) {
    if (valor === null || valor === undefined || valor === '') return 'Sin valor';
    return `$ ${separarMiles(valor)}`;
}

/**
 * Año, mes, día, hora y minuto de una fecha en hora de Colombia, sin depender
 * de la zona horaria del servidor.
 *
 * @param {Date|string} fecha
 * @returns {?{anio: number, mes: number, dia: number, hora: number, minuto: number}}
 *     null si la fecha no es válida.
 */
function partesBogota(fecha) {
    const d = fecha instanceof Date ? fecha : new Date(fecha);
    if (Number.isNaN(d.getTime())) return null;
    const partes = new Intl.DateTimeFormat('en-CA', {
        timeZone: ZONA_HORARIA,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        hourCycle: 'h23'
    }).formatToParts(d);
    const valor = (tipo) => Number(partes.find((p) => p.type === tipo).value);
    return { anio: valor('year'), mes: valor('month'), dia: valor('day'), hora: valor('hour'), minuto: valor('minute') };
}

/**
 * «12 sep 2026» en hora de Colombia.
 *
 * @param {?(Date|string)} fecha
 * @returns {string}
 */
function fechaCorta(fecha) {
    if (!fecha) return 'Sin fecha';
    const p = partesBogota(fecha);
    if (!p) return 'Sin fecha';
    return `${p.dia} ${MESES[p.mes - 1]} ${p.anio}`;
}

/**
 * «12 sep 2026, 8:05 p. m.» en hora de Colombia.
 *
 * @param {?(Date|string)} fecha
 * @returns {string}
 */
function fechaHora(fecha) {
    if (!fecha) return 'Sin fecha';
    const p = partesBogota(fecha);
    if (!p) return 'Sin fecha';
    const sufijo = p.hora < 12 ? 'a. m.' : 'p. m.';
    const hora12 = p.hora % 12 === 0 ? 12 : p.hora % 12;
    return `${fechaCorta(fecha)}, ${hora12}:${String(p.minuto).padStart(2, '0')} ${sufijo}`;
}

/**
 * Fecha ISO (AAAA-MM-DD) del día en Colombia.
 *
 * @param {Date|string} [fecha] Por defecto, el momento actual.
 * @returns {string} Vacío si la fecha no es válida.
 */
function fechaIsoBogota(fecha = new Date()) {
    const p = partesBogota(fecha);
    if (!p) return '';
    return `${p.anio}-${String(p.mes).padStart(2, '0')}-${String(p.dia).padStart(2, '0')}`;
}

/**
 * «FLORIDABLANCA» → «Floridablanca», «SABANA DE TORRES» → «Sabana de Torres».
 *
 * @param {?string} texto
 * @returns {string}
 */
function capitalizar(texto) {
    if (!texto) return '';
    return String(texto)
        .toLowerCase()
        .split(' ')
        .map((p) => (!p || ['de', 'del', 'y'].includes(p) ? p : p[0].toUpperCase() + p.slice(1)))
        .join(' ');
}

/**
 * Nombre dentro de una frase que termina en punto, sin duplicarlo
 * («… S.A.S.» no queda «S.A.S..»).
 *
 * @param {?string} texto
 * @returns {string}
 */
function finFrase(texto) {
    return `${String(texto || '').replace(/[.\s]+$/, '')}.`;
}

/**
 * @param {number} cantidad
 * @param {string} singular Palabra para una unidad.
 * @param {string} varios Palabra para cero o más de una.
 * @returns {string} «1 solicitud», «3 solicitudes».
 */
function plural(cantidad, singular, varios) {
    return `${formatoNumero(cantidad)} ${Number(cantidad) === 1 ? singular : varios}`;
}

/**
 * @param {*} valor
 * @returns {string} El valor sin espacios sobrantes, o «Sin dato» si está vacío.
 */
function textoODato(valor) {
    const limpio = valor === null || valor === undefined ? '' : String(valor).trim();
    return limpio || 'Sin dato';
}

/**
 * Solo enlaces http(s): evita que una URL guardada como «javascript:» se
 * convierta en un enlace ejecutable.
 *
 * @param {?string} url
 * @returns {?string}
 */
function urlSegura(url) {
    const texto = String(url || '').trim();
    return /^https?:\/\//i.test(texto) ? texto : null;
}

/**
 * Iniciales para el avatar: las mismas que muestra la app (utils/formato.dart).
 * Se saltan los conectores y lo que no empieza por letra (S.A.S., números).
 *
 * @param {?string} nombre
 * @returns {string} Una o dos letras en mayúscula; «E» si no hay ninguna.
 */
function iniciales(nombre) {
    const palabras = String(nombre || '')
        .split(/\s+/)
        .filter((p) => p && p[0].toUpperCase() !== p[0].toLowerCase())
        .filter((p) => !['de', 'del', 'la', 'las', 'los', 'y'].includes(p.toLowerCase()));
    if (palabras.length === 0) return 'E';
    if (palabras.length === 1) return palabras[0][0].toUpperCase();
    return (palabras[0][0] + palabras[1][0]).toUpperCase();
}

module.exports = {
    CATEGORIAS,
    CATEGORIAS_CATALOGO,
    ESTADOS,
    ESTADOS_SOLICITUD,
    ESTADOS_VERIFICACION,
    ESTADOS_GESTOR,
    UNIDADES,
    etiquetaCategoria,
    etiquetaEstado,
    etiquetaVerificacion,
    etiquetaTipoValor,
    etiquetaCertificado,
    claseCategoria,
    claseEstado,
    claseVerificacion,
    iconoEstado,
    unidadCorta,
    formatoNumero,
    formatoCantidad,
    formatoPorcentaje,
    formatoPesos,
    fechaCorta,
    fechaHora,
    fechaIsoBogota,
    capitalizar,
    finFrase,
    plural,
    textoODato,
    urlSegura,
    iniciales
};
