const test = require('node:test');
const assert = require('node:assert/strict');
const { instalarSupabaseFalso } = require('./apoyo/supabaseFalso');
const datos = require('./apoyo/datos');

const { responderConDatos } = datos;

const supabase = instalarSupabaseFalso();
const geocodificador = require('../src/services/geocodificador');
const gestorService = require('../src/services/GestorService');
const materialService = require('../src/services/MaterialService');
const solicitudService = require('../src/services/SolicitudService');
const request = require('supertest');
const app = require('../src/crearApp')();

let geocodificaciones = 0;
geocodificador.geocodificar = async () => { geocodificaciones += 1; return { latitud: 7.1, longitud: -73.1 }; };

const { TOKEN_CSRF, COOKIE_CSRF } = require('./apoyo/csrf');

const SESION = `sb_access_token=token-admin; ${COOKIE_CSRF}`;

const datosFormulario = {
    nit: '900396512',
    razon_social: 'Reciclajes del Oriente S.A.S.',
    municipio: 'Bucaramanga',
    direccion: 'Calle 10 # 20-30',
    telefono_contacto: '6076768585',
    email_contacto: 'contacto@oriente.test'
};

function gestorActual(relaciones) {
    return (consulta) => {
        if (consulta.tabla === 'perfiles_gestor' && consulta.modo === 'maybeSingle') {
            return {
                data: {
                    id: 1,
                    direccion: 'Calle 10 # 20-30',
                    municipio: 'BUCARAMANGA',
                    latitud: 7.1,
                    longitud: -73.1,
                    estado_verificacion: 'APROBADO',
                    gestor_material: relaciones
                }
            };
        }
        return undefined;
    };
}

const consultas = (tabla, accion) => supabase.consultas.filter((c) => c.tabla === tabla && c.accion === accion);

test.beforeEach(() => {
    supabase.limpiar();
    geocodificaciones = 0;
});

test('editar un gestor conserva la verificación de sus materiales y verifica solo los nuevos', async () => {
    supabase.manejador = gestorActual([
        { material_id: 1, verificado: true },
        { material_id: 2, verificado: false }
    ]);

    await gestorService.updateGestor(1, {
        ...datosFormulario,
        materiales_ids: ['1', '2', '3'],
        materiales_presentes: ['1', '2']
    });

    const actualizaciones = consultas('gestor_material', 'update');
    assert.equal(actualizaciones.length, 0, 'no debe cambiar el verificado de los que ya existían');
    assert.equal(consultas('gestor_material', 'delete').length, 0, 'no debe borrar materiales marcados');
    const inserciones = consultas('gestor_material', 'insert');
    assert.equal(inserciones.length, 1);
    assert.deepEqual(inserciones[0].payload, [{ gestor_id: 1, material_id: 3, verificado: true }]);
    assert.equal(geocodificaciones, 0, 'no geocodifica si la dirección no cambió');
});

test('editar un gestor quita los materiales desmarcados y respeta los que no se mostraron', async () => {
    supabase.manejador = gestorActual([
        { material_id: 1, verificado: true },
        { material_id: 2, verificado: false },
        { material_id: 9, verificado: false }
    ]);

    await gestorService.updateGestor(1, {
        ...datosFormulario,
        materiales_ids: ['1'],
        materiales_presentes: ['1', '2']
    });

    const borrados = consultas('gestor_material', 'delete');
    assert.equal(borrados.length, 1);
    assert.deepEqual(borrados[0].valor('in', 'material_id'), [2]);
    assert.equal(consultas('gestor_material', 'insert').length, 0);
    assert.equal(consultas('gestor_material', 'update').length, 0);
});

test('cambiar la dirección al editar sí vuelve a geocodificar', async () => {
    supabase.manejador = gestorActual([]);
    await gestorService.updateGestor(1, { ...datosFormulario, direccion: 'Carrera 33 # 48-10', materiales_ids: [] });
    assert.equal(geocodificaciones, 1);
    const actualizacion = consultas('perfiles_gestor', 'update')[0];
    assert.equal(actualizacion.payload.latitud, 7.1);
});

test('desmarcar «disponible» en la edición sí se guarda', async () => {
    supabase.manejador = gestorActual([]);
    await gestorService.updateGestor(1, { ...datosFormulario, disponible_enviado: '1' });
    assert.equal(consultas('perfiles_gestor', 'update')[0].payload.disponible, false);
});

test('aprobar verifica los materiales, ubica al gestor y cambia el estado con la función del panel', async () => {
    supabase.manejador = () => ({ data: { direccion: 'Calle 1', municipio: 'BUCARAMANGA', latitud: 7.119349, longitud: -73.122741 } });
    await gestorService.updateEstadoVerificacion(1, 'APROBADO', null, 'admin@ecoresiduos.test');
    const verificacion = consultas('gestor_material', 'update')[0];
    assert.deepEqual(verificacion.payload, { verificado: true });
    assert.equal(verificacion.valor('eq', 'verificado'), false);
    assert.equal(consultas('perfiles_gestor', 'update')[0].payload.latitud, 7.1, 'ubica la dirección del registro nuevo');
    assert.deepEqual(supabase.rpcs, [{
        nombre: 'cambiar_verificacion_gestor_admin',
        params: { p_gestor_id: 1, p_estado: 'APROBADO', p_observacion: null, p_admin: 'admin@ecoresiduos.test' }
    }]);
    assert.ok(!consultas('perfiles_gestor', 'update').some((c) => 'estado_verificacion' in c.payload), 'el estado no se cambia con un update suelto');
});

test('rechazar envía el motivo a la función: no se guarda en perfiles_gestor', async () => {
    const resultado = await gestorService.updateEstadoVerificacion(1, 'RECHAZADO', '  El permiso está vencido  ', 'admin@ecoresiduos.test');
    assert.equal(resultado.motivoGuardado, true);
    assert.equal(supabase.rpcs[0].params.p_observacion, 'El permiso está vencido');
    assert.equal(supabase.rpcs[0].params.p_estado, 'RECHAZADO');
    assert.equal(consultas('perfiles_gestor', 'update').length, 0);
});

test('sin la migración, el estado se cambia directo y se avisa que el motivo no se guardó', async () => {
    supabase.manejadorRpc = () => ({ data: null, error: { code: 'PGRST202', message: 'Could not find the function public.cambiar_verificacion_gestor_admin' } });
    const resultado = await gestorService.updateEstadoVerificacion(1, 'SUSPENDIDO', 'Documentos vencidos');
    assert.equal(resultado.motivoGuardado, false);
    assert.deepEqual(consultas('perfiles_gestor', 'update')[0].payload, { estado_verificacion: 'SUSPENDIDO' });
});

test('el historial de decisiones se lee de gestor_decisiones y es null sin la migración', async () => {
    supabase.manejador = (c) => (c.tabla === 'gestor_decisiones' ? { data: [{ id: 1, estado: 'RECHAZADO', observacion: 'Vencido' }] } : undefined);
    assert.equal((await gestorService.getDecisiones(1))[0].observacion, 'Vencido');
    supabase.manejador = (c) => (c.tabla === 'gestor_decisiones' ? { error: { code: '42P01', message: 'relation does not exist' } } : undefined);
    assert.equal(await gestorService.getDecisiones(1), null);
});

test('el detalle del gestor muestra el historial de decisiones con el motivo escapado', async () => {
    supabase.manejador = (c) => (c.tabla === 'gestor_decisiones'
        ? { data: [{ id: 1, estado: 'RECHAZADO', observacion: 'Permiso <vencido>', creado_por: 'admin@ecoresiduos.test', created_at: '2026-10-01T15:00:00Z' }] }
        : responderConDatos(c));
    const res = await request(app).get('/gestores/1').set('Cookie', SESION);
    assert.equal(res.status, 200);
    assert.match(res.text, /Historial de decisiones/);
    assert.match(res.text, /Permiso &lt;vencido&gt;/);
});

test('resolver «no se recogió» usa resolver_problema_no_recogido con la nota recortada', async () => {
    supabase.manejadorRpc = () => ({ data: { success: true }, error: null });
    await solicitudService.resolverNoRecogido('7', `  ${'x'.repeat(400)}`);
    assert.equal(supabase.rpcs[0].nombre, 'resolver_problema_no_recogido');
    assert.equal(supabase.rpcs[0].params.p_solicitud_id, 7);
    assert.equal(supabase.rpcs[0].params.p_nota.length, 300);
    await solicitudService.resolverNoRecogido(7, '');
    assert.equal(supabase.rpcs[1].params.p_nota, null);
    assert.equal(supabase.consultas.filter((c) => c.accion === 'update').length, 0);
});

test('sin la migración, resolver el problema explica qué migración correr', async () => {
    supabase.manejadorRpc = () => ({ data: null, error: { code: 'PGRST202', message: 'Could not find the function public.resolver_problema_no_recogido' } });
    await assert.rejects(() => solicitudService.resolverNoRecogido(7, null), /20261003000200_resolucion_problemas_reportados/);
});

test('la ruta de resolver redirige con aviso y el botón aparece solo si se puede resolver', async () => {
    supabase.manejador = (c) => (c.tabla === 'solicitudes_recoleccion' && c.modo !== 'lista'
        ? { data: { ...datos.solicitud, estado: 'RECOLECTADO', recolectado_at: '2026-09-29T10:00:00Z' } }
        : responderConDatos(c));
    supabase.manejadorRpc = () => ({ data: { success: true }, error: null });
    const detalle = await request(app).get('/solicitudes/7').set('Cookie', SESION);
    assert.ok(detalle.text.includes('action="/solicitudes/7/problema/no-recogido"'));
    assert.ok(detalle.text.includes('data-confirmar-nota'));

    const res = await request(app).post('/solicitudes/7/problema/no-recogido').set('X-CSRF-Token', TOKEN_CSRF).set('Cookie', SESION).type('form').send({ nota: 'Se acordó nueva fecha' });
    assert.equal(res.status, 302);
    assert.ok(decodeURIComponent(res.headers.location).startsWith('/solicitudes/7?msg=Problema resuelto'));
    assert.deepEqual(supabase.rpcs[0].params, { p_solicitud_id: 7, p_nota: 'Se acordó nueva fecha' });

    supabase.manejador = responderConDatos;
    const enNegociacion = await request(app).get('/solicitudes/7').set('Cookie', SESION);
    assert.ok(!enNegociacion.text.includes('problema/no-recogido'));
});

test('sin resolver = problema_reportado verdadero (filtro de la lista)', async () => {
    supabase.manejador = responderConDatos;
    await request(app).get('/solicitudes?problema=1').set('Cookie', SESION);
    const lista = supabase.consultas.find((c) => c.tabla === 'solicitudes_recoleccion' && c.opciones.count === 'exact' && !c.opciones.head);
    assert.equal(lista.valor('eq', 'problema_reportado'), true);
    assert.ok(!lista.filtros.some((filtro) => filtro[1] === 'problema_resuelto_at'));
});

test('cancelar una solicitud usa la función cancelar_solicitud_admin en una sola llamada', async () => {
    supabase.manejadorRpc = () => ({ data: { success: true, postulaciones_rechazadas: 2 }, error: null });
    const resultado = await solicitudService.cancelar('7');
    assert.deepEqual(supabase.rpcs, [{ nombre: 'cancelar_solicitud_admin', params: { p_solicitud_id: 7 } }]);
    assert.equal(resultado.postulaciones_rechazadas, 2);
    assert.equal(supabase.consultas.filter((c) => c.accion === 'update').length, 0, 'no hace updates sueltos desde Node');
});

test('si falta la migración, cancelar explica qué hay que aplicar', async () => {
    supabase.manejadorRpc = () => ({ data: null, error: { code: 'PGRST202', message: 'Could not find the function public.cancelar_solicitud_admin' } });
    await assert.rejects(() => solicitudService.cancelar(7), /20261003000000_cancelar_solicitud_admin/);
});

test('la ruta antigua de estado solo permite cancelar', async () => {
    supabase.manejador = responderConDatos;
    supabase.manejadorRpc = () => ({ data: { success: true, postulaciones_rechazadas: 1 }, error: null });

    const otro = await request(app).post('/solicitudes/7/estado').set('X-CSRF-Token', TOKEN_CSRF).set('Cookie', SESION).type('form').send({ estado: 'RECOLECTADO' });
    assert.equal(otro.status, 302);
    assert.match(decodeURIComponent(otro.headers.location), /solo se puede cancelar/);
    assert.equal(supabase.rpcs.length, 0);

    const cancelar = await request(app).post('/solicitudes/7/estado').set('X-CSRF-Token', TOKEN_CSRF).set('Cookie', SESION).type('form').send({ estado: 'CANCELADO' });
    assert.equal(cancelar.status, 302);
    assert.equal(supabase.rpcs[0].nombre, 'cancelar_solicitud_admin');
});

test('no se elimina un gestor con historia', async () => {
    supabase.manejador = (consulta) => {
        if (consulta.tabla === 'postulaciones_recoleccion' && consulta.opciones.head) return { count: 2 };
        if (consulta.tabla === 'perfiles_gestor' && consulta.modo === 'maybeSingle') return { data: { usuario_id: null } };
        return undefined;
    };
    await assert.rejects(() => gestorService.deleteGestor(1), (err) => err.codigo === 'TIENE_HISTORIA');
    assert.equal(supabase.consultas.filter((c) => c.accion === 'delete').length, 0);
});

test('un gestor con cuenta en la app tampoco se elimina', async () => {
    supabase.manejador = (consulta) => {
        if (consulta.tabla === 'perfiles_gestor' && consulta.modo === 'maybeSingle') return { data: { usuario_id: 'uuid-1' } };
        return undefined;
    };
    await assert.rejects(() => gestorService.deleteGestor(1), (err) => err.codigo === 'TIENE_HISTORIA');
});

test('un gestor sin historia sí se elimina', async () => {
    supabase.manejador = (consulta) => {
        if (consulta.tabla === 'perfiles_gestor' && consulta.modo === 'maybeSingle') return { data: { usuario_id: null } };
        return undefined;
    };
    await gestorService.deleteGestor(1);
    assert.deepEqual(supabase.consultas.filter((c) => c.accion === 'delete').map((c) => c.tabla), ['gestor_material', 'perfiles_gestor']);
});

test('no se elimina un material que tiene solicitudes', async () => {
    supabase.manejador = (consulta) => {
        if (consulta.tabla === 'solicitudes_recoleccion' && consulta.opciones.head) return { count: 3 };
        return undefined;
    };
    await assert.rejects(() => materialService.deleteMaterial(2), /3 solicitud/);
    assert.equal(supabase.consultas.filter((c) => c.accion === 'delete').length, 0);
});

test('subir el permiso exige un PDF real y lo guarda en admin/<id>/', async () => {
    supabase.manejador = (consulta) => {
        if (consulta.tabla === 'perfiles_gestor' && consulta.modo === 'maybeSingle') return { data: { id: 1, permiso_path: 'admin/1/viejo.pdf' } };
        return undefined;
    };
    await assert.rejects(() => gestorService.subirPermiso(1, Buffer.from('no es pdf')), /no es un PDF/);
    const ruta = await gestorService.subirPermiso(1, Buffer.from('%PDF-1.7 contenido'));
    assert.match(ruta, /^admin\/1\/[0-9a-f-]{36}\.pdf$/);
    const subida = supabase.storageOps.find((o) => o.op === 'subir');
    assert.equal(subida.bucket, 'permisos');
    assert.equal(subida.opciones.contentType, 'application/pdf');
    assert.deepEqual(supabase.storageOps.find((o) => o.op === 'borrar').rutas, ['admin/1/viejo.pdf']);
});

test('el panel no muestra valores inventados cuando falta el dato', () => {
    const g = gestorService.mapearGestor({ id: 1, razon_social: 'X' });
    assert.equal(g.estado_verificacion, null);
    assert.equal(g.municipio, null);
});
