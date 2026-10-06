import 'package:ecoresiduos/models/gestor.dart';
import 'package:ecoresiduos/services/foto_perfil_service.dart';
import 'package:ecoresiduos/utils/formato.dart';
import 'package:ecoresiduos/utils/sesion.dart';
import 'package:ecoresiduos/widgets/cuenta_bottom_sheet.dart';
import 'package:ecoresiduos/widgets/eco_top_app_bar.dart';
import 'package:ecoresiduos/widgets/gestor_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fakes.dart';

const _uid = '7d5c2a3e-1f4b-4c8d-9e6a-2b3c4d5e6f70';

User _usuario(Map<String, dynamic> metadatos) => User(
  id: _uid,
  appMetadata: const {},
  userMetadata: metadatos,
  aud: 'authenticated',
  createdAt: '2026-10-06T00:00:00Z',
);

/// Servicio que no toca Supabase: anota lo que se le pide.
class _FotosFalso extends FotoPerfilService {
  final llamadas = <String>[];

  @override
  Future<String> cambiar(String rutaLocal, ImagenPerfil imagen) async {
    llamadas.add('cambiar:${imagen.name}');
    return '$_uid/${imagen.carpeta}/1.jpg';
  }

  @override
  Future<void> quitar(ImagenPerfil imagen) async => llamadas.add('quitar:${imagen.name}');
}

Future<void> _abrirCuenta(WidgetTester tester, SesionUsuario sesion, {FotoPerfilService? fotos}) async {
  await tester.pumpWidget(
    app(
      Scaffold(
        body: CuentaBottomSheet(authRepository: FakeAuthRepository(), sesion: sesion, fotoPerfilService: fotos),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('rutas de las fotos', () {
    // La misma regla que la restricción de la migración 20261006000000.
    RegExp regla(String carpeta) => RegExp('^$_uid/$carpeta/[0-9]+\\.(jpg|jpeg|png|webp)\$');
    final ahora = DateTime(2026, 10, 6, 9);

    test('la ruta nueva cumple la restricción de la base', () {
      expect(FotoPerfilService.rutaNueva(_uid, ImagenPerfil.foto, '/tmp/a.PNG', ahora), matches(regla('perfil')));
      expect(FotoPerfilService.rutaNueva(_uid, ImagenPerfil.portada, '/tmp/b.jpeg', ahora), matches(regla('portada')));
    });

    test('una extensión que el bucket no acepta se guarda como .jpg', () {
      expect(FotoPerfilService.rutaNueva(_uid, ImagenPerfil.foto, '/tmp/c.heic', ahora), endsWith('.jpg'));
    });

    test('sin ruta o sin Supabase no hay URL', () {
      expect(FotoPerfilService.url(null), isNull);
      expect(FotoPerfilService.url(''), isNull);
      expect(FotoPerfilService.url('$_uid/perfil/1.jpg'), isNull);
    });
  });

  group('datos', () {
    test('la sesión lee la foto y, solo al gestor, la portada', () {
      final gestor = SesionUsuario.desdeUsuario(
        _usuario({'rol': 'GESTOR', 'foto_perfil_path': '$_uid/perfil/1.jpg', 'portada_path': '$_uid/portada/2.jpg'}),
      );
      expect(gestor.fotoPerfilPath, '$_uid/perfil/1.jpg');
      expect(gestor.portadaPath, '$_uid/portada/2.jpg');

      final generador = SesionUsuario.desdeUsuario(
        _usuario({'rol': 'GENERADOR', 'foto_perfil_path': '$_uid/perfil/1.jpg', 'portada_path': '$_uid/portada/2.jpg'}),
      );
      expect(generador.fotoPerfilPath, '$_uid/perfil/1.jpg');
      expect(generador.portadaPath, isNull);
    });

    test('el gestor del directorio trae sus fotos y las conserva al calcular la distancia', () {
      final gestor = Gestor.fromMap({
        'id': 3,
        'razon_social': 'Reciclajes del Oriente',
        'municipio': 'GIRÓN',
        'foto_perfil_path': '$_uid/perfil/1.jpg',
        'portada_path': '  ',
      });
      expect(gestor.fotoPerfilPath, '$_uid/perfil/1.jpg');
      expect(gestor.portadaPath, isNull);
      expect(gestor.conDistancia(2.5).fotoPerfilPath, '$_uid/perfil/1.jpg');
    });
  });

  group('avatar', () {
    testWidgets('sin foto muestra las iniciales y no las anuncia: el nombre va al lado', (tester) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(app(const Center(child: AvatarEntidad(nombre: 'Reciclajes del Oriente'))));
      expect(find.text(iniciales('Reciclajes del Oriente')), findsOneWidget);
      expect(find.bySemanticsLabel(iniciales('Reciclajes del Oriente')), findsNothing);
      semantica.dispose();
    });

    testWidgets('con foto, mientras carga se ven las iniciales en el mismo tamaño', (tester) async {
      await tester.pumpWidget(
        app(
          const Center(
            child: AvatarEntidad(nombre: 'Reciclajes del Oriente', size: 72, fotoUrl: 'https://ejemplo.co/logo.png'),
          ),
        ),
      );
      expect(find.text(iniciales('Reciclajes del Oriente')), findsOneWidget);
      expect(tester.getSize(find.byType(AvatarEntidad)), const Size(72, 72));
    });
  });

  group('forma y tamaño', () {
    ShapeBorder? forma(WidgetTester tester) {
      final caja = tester.widget<Container>(
        find.descendant(of: find.byType(AvatarEntidad), matching: find.byType(Container)).first,
      );
      return (caja.decoration as ShapeDecoration?)?.shape;
    }

    testWidgets('una persona va en círculo y una empresa en recuadro', (tester) async {
      await tester.pumpWidget(app(const Center(child: AvatarEntidad(nombre: 'Laura Gómez', circular: true))));
      expect(forma(tester), isA<CircleBorder>());
      await tester.pumpWidget(app(const Center(child: AvatarEntidad(nombre: 'Reciclajes del Oriente'))));
      expect(forma(tester), isA<RoundedRectangleBorder>());
    });

    testWidgets('el avatar de la barra se toca en 48 dp y se llama «Tu cuenta»', (tester) async {
      await tester.pumpWidget(app(const Scaffold(appBar: EcoTopAppBar(titulo: 'Inicio'))));
      expect(tester.getSize(find.byTooltip('Tu cuenta')).width, greaterThanOrEqualTo(48));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
  });

  group('hoja de cuenta', () {
    testWidgets('el generador puede agregar foto de perfil, pero no portada', (tester) async {
      usarPantallaAlta(tester);
      await _abrirCuenta(tester, const SesionUsuario(nombre: 'Laura Gómez'));
      expect(find.byTooltip('Agregar foto de perfil'), findsOneWidget);
      expect(find.textContaining('portada'), findsNothing);
    });

    testWidgets('el gestor con foto puede cambiarla y agregar portada', (tester) async {
      usarPantallaAlta(tester);
      await _abrirCuenta(
        tester,
        const SesionUsuario(nombre: 'Reciclajes del Oriente', esGestor: true, fotoPerfilPath: '$_uid/perfil/1.jpg'),
      );
      expect(find.byTooltip('Cambiar foto de perfil'), findsOneWidget);
      expect(find.text('Agregar portada'), findsOneWidget);
      expect(find.text('Se ve detrás de tu foto en el directorio'), findsOneWidget);
    });

    testWidgets('«Quitar» solo aparece si hay foto y la quita del perfil', (tester) async {
      usarPantallaAlta(tester);
      final fotos = _FotosFalso();
      await _abrirCuenta(
        tester,
        const SesionUsuario(nombre: 'Laura Gómez', fotoPerfilPath: '$_uid/perfil/1.jpg'),
        fotos: fotos,
      );

      await tester.tap(find.byTooltip('Cambiar foto de perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Elegir de la galería'), findsOneWidget);
      expect(find.text('Tomar foto'), findsOneWidget);
      await tester.tap(find.text('Quitar foto'));
      await tester.pumpAndSettle();

      expect(fotos.llamadas, ['quitar:foto']);
      expect(find.text('Foto de perfil quitada.'), findsOneWidget);
      expect(find.byTooltip('Agregar foto de perfil'), findsOneWidget);

      await tester.tap(find.byTooltip('Agregar foto de perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Quitar foto'), findsNothing);
    });

    testWidgets('las opciones tienen tamaño táctil suficiente y nombre accesible', (tester) async {
      usarPantallaAlta(tester);
      await _abrirCuenta(tester, const SesionUsuario(nombre: 'Reciclajes del Oriente', esGestor: true));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(find.text('Agregar portada'));
      await tester.pumpAndSettle();
      expect(find.text('Portada'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });
  });
}
