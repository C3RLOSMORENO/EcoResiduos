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

const TIPOS_VALOR = {
    COBRO_RECOLECCION: 'Valor cobrado por recolección externa',
    PAGO_APROVECHAMIENTO: 'Valor pagado por aprovechamiento'
};

const TIPOS_CERTIFICADO = {
    DISPOSICION_FINAL: 'Certificado de disposición final',
    APROVECHAMIENTO: 'Certificado de aprovechamiento'
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

function etiquetaCategoria(valor) {
    if (!clave(valor)) return 'Sin categoría';
    return CATEGORIAS[clave(valor)] || String(valor);
}

function etiquetaEstado(valor) {
    if (!clave(valor)) return 'Sin dato';
    return ESTADOS[clave(valor)] || String(valor);
}

function etiquetaVerificacion(valor) {
    if (!clave(valor)) return 'Sin dato';
    return ESTADOS_VERIFICACION[clave(valor)] || String(valor);
}

function etiquetaTipoValor(valor) {
    return TIPOS_VALOR[clave(valor)] || 'Sin valor propuesto';
}

function etiquetaCertificado(valor) {
    return TIPOS_CERTIFICADO[clave(valor)] || 'Certificado';
}

// Sufijo de las variables CSS --eco-cat-* (app: categoriaFromString).
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

// Sufijo de las variables CSS --eco-estado-* (app: estadoFromString).
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

function unidadCorta(unidad) {
    return UNIDADES[clave(unidad)] || String(unidad || '').toLowerCase();
}

// Cifra sin decimales innecesarios, coma decimal y punto de miles.
function formatoNumero(valor, decimales = 1) {
    const n = Number(valor);
    if (!Number.isFinite(n)) return '0';
    return new Intl.NumberFormat('es-CO', {
        maximumFractionDigits: Number.isInteger(n) ? 0 : decimales,
        minimumFractionDigits: 0
    }).format(n);
}

function formatoCantidad(cantidad, unidad) {
    if (cantidad === null || cantidad === undefined || cantidad === '') return 'Sin dato';
    return `${formatoNumero(cantidad)} ${unidadCorta(unidad)}`.trim();
}

function separarMiles(valor) {
    const entero = Math.trunc(Number(valor) || 0);
    const digitos = String(Math.abs(entero)).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
    return entero < 0 ? `-${digitos}` : digitos;
}

// «$ 1.250.000», igual que formatoPesos en la app.
function formatoPesos(valor) {
    if (valor === null || valor === undefined || valor === '') return 'Sin valor';
    return `$ ${separarMiles(valor)}`;
}

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

// «12 sep 2026» en hora de Colombia.
function fechaCorta(fecha) {
    if (!fecha) return 'Sin fecha';
    const p = partesBogota(fecha);
    if (!p) return 'Sin fecha';
    return `${p.dia} ${MESES[p.mes - 1]} ${p.anio}`;
}

// «12 sep 2026, 8:05 p. m.» en hora de Colombia.
function fechaHora(fecha) {
    if (!fecha) return 'Sin fecha';
    const p = partesBogota(fecha);
    if (!p) return 'Sin fecha';
    const sufijo = p.hora < 12 ? 'a. m.' : 'p. m.';
    const hora12 = p.hora % 12 === 0 ? 12 : p.hora % 12;
    return `${fechaCorta(fecha)}, ${hora12}:${String(p.minuto).padStart(2, '0')} ${sufijo}`;
}

// Fecha ISO (AAAA-MM-DD) del día en Colombia.
function fechaIsoBogota(fecha = new Date()) {
    const p = partesBogota(fecha);
    if (!p) return '';
    return `${p.anio}-${String(p.mes).padStart(2, '0')}-${String(p.dia).padStart(2, '0')}`;
}

// «FLORIDABLANCA» → «Floridablanca», «SABANA DE TORRES» → «Sabana de Torres».
function capitalizar(texto) {
    if (!texto) return '';
    return String(texto)
        .toLowerCase()
        .split(' ')
        .map((p) => (!p || ['de', 'del', 'y'].includes(p) ? p : p[0].toUpperCase() + p.slice(1)))
        .join(' ');
}

// Nombre dentro de una frase que termina en punto, sin duplicarlo
// («… S.A.S.» no queda «S.A.S..»).
function finFrase(texto) {
    return `${String(texto || '').replace(/[.\s]+$/, '')}.`;
}

function plural(cantidad, singular, varios) {
    return `${formatoNumero(cantidad)} ${Number(cantidad) === 1 ? singular : varios}`;
}

function textoODato(valor) {
    const limpio = valor === null || valor === undefined ? '' : String(valor).trim();
    return limpio || 'Sin dato';
}

// Solo enlaces http(s): evita que una URL guardada como «javascript:» se
// convierta en un enlace ejecutable.
function urlSegura(url) {
    const texto = String(url || '').trim();
    return /^https?:\/\//i.test(texto) ? texto : null;
}

module.exports = {
    ZONA_HORARIA,
    CATEGORIAS,
    CATEGORIAS_CATALOGO,
    ESTADOS,
    ESTADOS_SOLICITUD,
    ESTADOS_VERIFICACION,
    TIPOS_VALOR,
    TIPOS_CERTIFICADO,
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
    separarMiles,
    formatoPesos,
    fechaCorta,
    fechaHora,
    fechaIsoBogota,
    capitalizar,
    finFrase,
    plural,
    textoODato,
    urlSegura
};
