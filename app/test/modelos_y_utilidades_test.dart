import 'package:ecoresiduos/features/auth/repositories/auth_repository.dart';
import 'package:ecoresiduos/features/solicitudes/models/material_residuo.dart';
import 'package:ecoresiduos/features/solicitudes/models/solicitud_recoleccion.dart';
import 'package:ecoresiduos/models/gestor.dart';
import 'package:ecoresiduos/models/postulacion_recoleccion.dart';
import 'package:ecoresiduos/services/certificados_service.dart';
import 'package:ecoresiduos/services/fotos_service.dart';
import 'package:ecoresiduos/theme/eco_theme.dart';
import 'package:ecoresiduos/utils/formato.dart';
import 'package:ecoresiduos/utils/municipios.dart';
import 'package:ecoresiduos/utils/sesion.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('Solicitud', () {
    test('no envía las columnas que solo escriben las funciones del servidor', () {
      final mapa = solicitud(estado: 'RECOLECTADO', recolectadoAt: DateTime(2026, 9, 1)).toMap(forInsert: true);
      expect(
        mapa.keys,
        isNot(anyOf(contains('recolectado_at'), contains('confirmado_at'), contains('problema_reportado'))),
      );
      expect(mapa.containsKey('gestor_asignado_id'), isFalse);
      expect(mapa.containsKey('id'), isFalse);
    });

    test('al editar solo envía los campos que el generador puede cambiar', () {
      final mapa = solicitud(estado: 'PUBLICADO').toMapEdicion();
      expect(mapa.keys, isNot(anyOf(contains('estado'), contains('generador_id'), contains('id'))));
      expect(mapa.containsKey('updated_at'), isFalse);
      expect(mapa['direccion_recoleccion'], isNotEmpty);
    });

    test('queda por confirmar cuando el gestor la marcó y el generador no respondió', () {
      expect(solicitud(estado: 'RECOLECTADO', recolectadoAt: DateTime.now()).pendienteConfirmacion, isTrue);
      expect(
        solicitud(
          estado: 'RECOLECTADO',
          recolectadoAt: DateTime.now(),
          confirmadoAt: DateTime.now(),
        ).pendienteConfirmacion,
        isFalse,
      );
      expect(solicitud(estado: 'EN_NEGOCIACION').pendienteConfirmacion, isFalse);
    });

    test('lee el certificado y nunca lo envía desde el generador', () {
      final s = SolicitudRecoleccion.fromMap({
        'id': 1,
        'certificado_url': 'https://x.supabase.co/storage/v1/object/public/certificados/u/1/9.pdf',
        'certificado_tipo': 'disposicion_final',
        'certificado_at': '2026-10-01T10:00:00Z',
      });
      expect(s.tieneCertificado, isTrue);
      expect(s.certificadoTipo, TipoCertificado.disposicionFinal);
      expect(s.toMap().keys, isNot(anyOf(contains('certificado_url'), contains('certificado_tipo'))));
      expect(CertificadosService.rutaEnBucket(s.certificadoUrl), 'u/1/9.pdf');
    });
  });

  group('Postulación', () {
    test('envía la propuesta solo si tiene texto', () {
      expect(postulacion(id: 1, propuesta: '  Paso el jueves  ').toMap()['propuesta'], 'Paso el jueves');
      expect(postulacion(id: 1, propuesta: '   ').toMap().containsKey('propuesta'), isFalse);
    });

    test('envía y lee el valor propuesto', () {
      final mapa = postulacion(id: 1, tipoValor: TipoValor.pagoAprovechamiento, valor: 120000).toMap(forInsert: true);
      expect(mapa['tipo_valor'], 'PAGO_APROVECHAMIENTO');
      expect(mapa['valor'], 120000);

      final leida = PostulacionRecoleccion.fromMap({...mapa, 'id': 1});
      expect(leida.tipoValor, TipoValor.pagoAprovechamiento);
      expect(leida.valor, 120000);
      expect(postulacion(id: 2).tieneValor, isFalse);
    });

    test('reconoce el estado «Asignada a otro gestor»', () {
      final p = PostulacionRecoleccion.fromMap({
        'id': 1,
        'solicitud_id': 2,
        'gestor_id': 3,
        'estado': 'no_seleccionada',
      });
      expect(p.esNoSeleccionada, isTrue);
      expect(estadoFromString('NO_SELECCIONADA'), EstadoSolicitud.noSeleccionada);
      expect(estadoLabel['NO_SELECCIONADA'], 'Asignada a otro gestor');
    });
  });

  group('Material', () {
    test('separa la guía de manejo en pasos sin la numeración', () {
      expect(carton.pasosManejo, ['Dóblalo', 'Amárralo']);
    });

    test('solo tiene advertencia si hay texto de advertencia', () {
      expect(luminarias.tieneAdvertencia, isTrue);
      expect(carton.tieneAdvertencia, isFalse);
      expect(
        MaterialResiduo.fromMap({
          'id': 3,
          'nombre_comun': 'Pilas',
          'categoria': 'PELIGROSO',
          'guia_manejo': 'Guárdalas',
        }).tieneAdvertencia,
        isFalse,
      );
    });
  });

  group('Gestor', () {
    test('solo muestra las categorías de materiales verificados', () {
      final gestor = Gestor.fromMap({
        'id': 1,
        'razon_social': 'EcoPilas',
        'municipio': 'Floridablanca',
        'gestor_material': [
          {
            'verificado': true,
            'materiales_residuos': {'categoria': 'peligroso'},
          },
          {
            'verificado': false,
            'materiales_residuos': {'categoria': 'RAEE'},
          },
        ],
      });
      expect(gestor.categorias, ['PELIGROSO']);
      expect(gestor.distanciaKm, isNull);
    });
  });

  group('Formato', () {
    test('pesos con punto de miles', () {
      expect(formatoPesos(0), '\$ 0');
      expect(formatoPesos(950), '\$ 950');
      expect(formatoPesos(50000), '\$ 50.000');
      expect(formatoPesos(1250000), '\$ 1.250.000');
    });

    test('cantidad con su propia unidad y sin decimales de más', () {
      expect(formatoCantidad(120, 'KG'), '120 kg');
      expect(formatoCantidad(2.5, 'M3'), '2,5 m³');
      expect(formatoCantidad(3, 'UNIDADES'), '3 unidades');
    });

    test('tiempo relativo', () {
      final ahora = DateTime(2026, 9, 23, 12);
      expect(tiempoRelativo(ahora.subtract(const Duration(minutes: 15)), ahora: ahora), 'hace 15 min');
      expect(tiempoRelativo(ahora.subtract(const Duration(hours: 2)), ahora: ahora), 'hace 2 h');
      expect(tiempoRelativo(ahora.subtract(const Duration(days: 1)), ahora: ahora), 'ayer');
    });

    test('iniciales de personas y empresas', () {
      expect(iniciales('Reciclajes del Oriente S.A.S.'), 'RO');
      expect(iniciales('Mariana Rueda Ardila'), 'MR');
      expect(iniciales(''), 'E');
    });

    test('etiquetas humanas en lugar de códigos', () {
      expect(etiquetaCategoria('RIESGO_BIOLOGICO'), 'Riesgo biológico');
      expect(etiquetaEstado('EN_NEGOCIACION'), 'En negociación');
      expect(capitalizar('SABANA DE TORRES'), 'Sabana de Torres');
    });
  });

  test('municipios admitidos sin importar mayúsculas ni tildes', () {
    expect(municipioAdmitido('GIRON'), 'Girón');
    expect(municipioAdmitido(' floridablanca '), 'Floridablanca');
    expect(municipioAdmitido('Medellín'), isNull);
  });

  test('ruta en el bucket a partir de la URL pública de la foto', () {
    expect(
      FotosService.rutaEnBucket('https://x.supabase.co/storage/v1/object/public/escaneos_ia/abc/solicitudes/1.jpg?t=1'),
      'abc/solicitudes/1.jpg',
    );
    expect(FotosService.rutaEnBucket('https://ejemplo.co/foto.jpg'), isNull);
    expect(FotosService.rutaEnBucket(null), isNull);
  });

  test('NIT sin puntos ni dígito de verificación', () {
    expect(normalizarNit('900.456.789-2'), '900456789');
    expect(normalizarNit('900456789'), '900456789');
  });

  test('sesión vacía cuando Supabase no está inicializado', () {
    final sesion = SesionUsuario.actual();
    expect(sesion.nombre, isEmpty);
    expect(sesion.esGestor, isFalse);
  });
}
