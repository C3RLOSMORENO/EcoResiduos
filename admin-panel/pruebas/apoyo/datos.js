// Filas de ejemplo para que todas las pantallas tengan qué mostrar.
const XSS = '</script><script>alert("xss")</script>';

const material = {
    id: 2,
    codigo: 'Y8',
    nombre_comun: 'Aceite usado',
    categoria: 'PELIGROSO',
    subcategoria: 'Aceites',
    descripcion: 'Aceite lubricante usado de motores.',
    guia_manejo: 'Recipiente cerrado.',
    advertencia_manejo: null
};

const gestor = {
    id: 1,
    nit: '900396512',
    razon_social: 'RECICLAJES DEL ORIENTE S.A.S.',
    municipio: 'GIRÓN',
    direccion: 'Calle 10 # 20-30',
    representante_legal: 'Ana Pérez',
    telefono_contacto: '6076768585',
    email_contacto: 'contacto@oriente.test',
    latitud: 7.07,
    longitud: -73.17,
    estado_verificacion: 'PENDIENTE',
    disponible: true,
    horario: 'Lun a vie 8 a 5',
    usuario_id: null,
    permiso_path: 'registro/abc.pdf',
    created_at: '2026-09-30T15:00:00Z',
    gestor_material: [
        { material_id: 2, verificado: true, materiales_residuos: material },
        { material_id: 3, verificado: false, materiales_residuos: { id: 3, codigo: 'RAEE-01', nombre_comun: 'Celulares', categoria: 'RAEE' } }
    ]
};

const solicitud = {
    id: 7,
    generador_id: 4,
    material_id: 2,
    cantidad_estimada: 120,
    unidad_medida: 'KG',
    estado: 'EN_NEGOCIACION',
    municipio: XSS,
    direccion_recoleccion: 'Carrera 27 # 45-10',
    telefono: '3001234567',
    foto_url: 'javascript:alert(1)',
    created_at: '2026-09-28T20:00:00Z',
    recolectado_at: null,
    confirmado_at: null,
    problema_reportado: true,
    problema_detalle: 'No vinieron a la hora acordada.',
    gestor_asignado_id: 1,
    certificado_url: 'https://almacenamiento.test/certificados/a.pdf',
    certificado_tipo: 'APROVECHAMIENTO',
    certificado_at: '2026-09-29T15:00:00Z',
    materiales_residuos: material
};

const autoridad = {
    id: 5,
    nombre: 'Corporación Autónoma Regional de Santander',
    sigla: 'CAS',
    jurisdiccion: '74 municipios',
    telefono: '6077242100',
    email: 'contactenos@cas.test',
    sitio_web: 'https://www.cas.gov.co',
    direccion: 'Carrera 12 # 9-06, San Gil',
    horario: null
};

const generador = {
    id: 4,
    usuario_id: '0b1c2d3e-0000-0000-0000-000000000000',
    nombre_completo_o_empresa: 'Laura Gómez',
    documento_nit: '1098000000',
    email: 'laura@correo.test',
    telefono: '3001234567',
    municipio: 'BUCARAMANGA',
    created_at: '2026-09-01T12:00:00Z'
};

const postulacion = {
    id: 9,
    gestor_id: 1,
    estado: 'PROPUESTA',
    propuesta: 'Paso mañana',
    tipo_valor: 'COBRO_RECOLECCION',
    valor: 1250000,
    created_at: '2026-09-28T21:00:00Z',
    perfiles_gestor: { id: 1, razon_social: gestor.razon_social, nit: gestor.nit }
};

// Responde cada consulta con las filas de ejemplo.
function responderConDatos(consulta) {
    if (consulta.tabla === 'usuarios') return { data: { rol: 'ADMIN' } };
    if (consulta.opciones.head) return { data: null, count: 3 };
    const uno = consulta.modo !== 'lista';
    const lista = (fila) => (uno ? { data: fila } : { data: [fila], count: 1 });
    switch (consulta.tabla) {
        case 'perfiles_gestor': return lista(gestor);
        case 'materiales_residuos': return lista(material);
        case 'autoridades_ambientales': return lista(autoridad);
        case 'solicitudes_recoleccion': return lista(solicitud);
        case 'perfiles_generador': return lista(generador);
        case 'postulaciones_recoleccion': return lista(postulacion);
        case 'solicitudes_historial_estados':
            return { data: [{ id: 1, estado: 'PUBLICADO', created_at: '2026-09-28T20:00:00Z' }, { id: 2, estado: 'EN_NEGOCIACION', created_at: '2026-09-28T22:00:00Z' }] };
        case 'gestor_material': return uno ? { data: { gestor_id: 1 } } : { data: [{ gestor_id: 1, material_id: 3 }] };
        default: return undefined;
    }
}

module.exports = { XSS, material, gestor, solicitud, autoridad, generador, postulacion, responderConDatos };
