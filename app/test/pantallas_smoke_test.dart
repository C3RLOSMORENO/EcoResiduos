import 'package:ecoresiduos/models/autoridad_ambiental.dart';
import 'package:ecoresiduos/models/gestor.dart';
import 'package:ecoresiduos/models/waste_item.dart';
import 'package:ecoresiduos/repositories/gestores_repository.dart';
import 'package:ecoresiduos/screens/autoridad_detalle_screen.dart';
import 'package:ecoresiduos/screens/error_procesamiento_screen.dart';
import 'package:ecoresiduos/screens/gestor_detalle_screen.dart';
import 'package:ecoresiduos/screens/gestores_asociados_screen.dart';
import 'package:ecoresiduos/screens/guia_manejo_general_screen.dart';
import 'package:ecoresiduos/screens/informacion_residuo_screen.dart';
import 'package:ecoresiduos/screens/manejo_residuo_screen.dart';
import 'package:ecoresiduos/screens/residuo_no_identificado_screen.dart';
import 'package:ecoresiduos/screens/residuos_screen.dart';
import 'package:ecoresiduos/screens/resultado_screen.dart';
import 'package:ecoresiduos/screens/splash_screen.dart';
import 'package:ecoresiduos/theme/eco_theme.dart';
import 'package:ecoresiduos/widgets/eco_logo.dart';
import 'package:ecoresiduos/widgets/solicitud_card.dart';
import 'package:ecoresiduos/widgets/visor_foto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _gestor = Gestor(
  id: 1,
  nombre: 'Reciclajes del Oriente S.A.S.',
  municipio: 'GIRÓN',
  nit: '900456789',
  direccion: 'Cra 15 # 8-42, Zona Industrial Chimitá',
  telefono: '6076462210',
  correo: 'operaciones@reciclajes.co',
  horario: 'Lun a sáb 7:00–17:00',
  categorias: ['APROVECHABLE', 'RCD', 'RAEE'],
  distanciaKm: 2.4,
);

const _autoridad = AutoridadAmbiental(
  id: 1,
  nombre: 'Corporación Autónoma Regional para la Defensa de la Meseta de Bucaramanga',
  sigla: 'CDMB',
  jurisdiccion: 'Área metropolitana y municipios de la meseta',
  telefono: '6076346100',
  email: 'info@cdmb.gov.co',
  sitioWeb: 'https://www.cdmb.gov.co',
  direccion: 'Carrera 23 # 37-63, Bucaramanga',
);

class _FakeGestores implements GestoresRepository {
  @override
  Future<List<Gestor>> getDirectorio() async => [_gestor];

  @override
  Future<List<Gestor>> getGestoresPorCategoria(String categoria, {int limite = 10}) async => [_gestor];

  @override
  Future<List<AutoridadAmbiental>> getAutoridades() async => [_autoridad];
}

void main() {
  final gestores = _FakeGestores();
  final pantallas = <String, Widget>{
    'Residuos': ResiduosScreen(repository: FakeSolicitudesRepository()),
    'Información del residuo': InformacionResiduoScreen(material: luminarias, gestoresRepository: gestores),
    'Manejo seguro': const ManejoResiduoScreen(material: carton),
    'Manejo sin pasos': const ManejoResiduoScreen(material: luminarias),
    'Guía de manejo': const GuiaManejoGeneralScreen(categoriaInicial: Categoria.riesgoBiologico),
    'Directorio': GestoresAsociadosScreen(repository: gestores, incluirResiduos: true),
    'Autoridades': GestoresAsociadosScreen(repository: gestores, segmentoInicial: 1),
    'Ficha de gestor': const GestorDetalleScreen(
      gestor: _gestor,
      materialResaltado: 'Cartón corrugado',
      categoriaResaltada: 'APROVECHABLE',
    ),
    'Ficha de autoridad': const AutoridadDetalleScreen(autoridad: _autoridad),
    'Resultado publicable': ResultadoScreen(
      item: const WasteItem(nombre: 'Residuo peligroso', categoria: 'PELIGROSO', confianza: 78),
      imagePath: 'foto.jpg',
      gestoresRepository: gestores,
    ),
    'Resultado orgánico': ResultadoScreen(
      item: const WasteItem(nombre: 'Residuo orgánico', categoria: 'ORGANICO', confianza: 90),
      imagePath: 'foto.jpg',
      gestoresRepository: gestores,
    ),
    'No identificado': const ResiduoNoIdentificadoScreen(imagePath: 'foto.jpg', confianza: 41),
    'Error de análisis': const ErrorProcesamientoScreen(imagePath: 'foto.jpg'),
    'Splash': const SplashScreen(),
  };

  for (final brillo in Brightness.values) {
    for (final entrada in pantallas.entries) {
      testWidgets('${entrada.key} se dibuja sin errores (${brillo.name})', (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(theme: ecoTheme(brillo), home: entrada.value));
        // El splash tiene una barra indeterminada que nunca se detiene.
        entrada.value is SplashScreen ? await tester.pump(const Duration(seconds: 1)) : await tester.pumpAndSettle();
      });
    }
  }

  testWidgets('el directorio filtra gestores por texto', (tester) async {
    usarPantallaAlta(tester);
    await tester.pumpWidget(app(GestoresAsociadosScreen(repository: gestores)));
    await tester.pumpAndSettle();

    expect(find.text('Todos · 1'), findsOneWidget);
    await tester.enterText(find.byType(SearchBar), 'llantas');
    await tester.pumpAndSettle();
    expect(find.text('Ningún gestor coincide con «llantas»'), findsOneWidget);
  });

  testWidgets('la foto ampliable se abre a pantalla completa y se cierra', (tester) async {
    await tester.pumpWidget(
      app(
        const Center(
          child: FotoResiduo(url: 'fotos/carton.jpg', categoria: Categoria.aprovechable, ampliable: true),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Ver foto en grande'));
    await tester.pumpAndSettle();
    expect(find.byType(VisorFoto), findsOneWidget);
    expect(
      tester.getSize(find.descendant(of: find.byType(VisorFoto), matching: find.byType(InteractiveViewer))),
      tester.view.physicalSize / tester.view.devicePixelRatio,
      reason: 'la foto ocupa toda la pantalla',
    );

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(VisorFoto), findsNothing);
  });

  testWidgets('sin foto no se ofrece ampliar', (tester) async {
    await tester.pumpWidget(
      app(const Center(child: FotoResiduo(url: null, categoria: Categoria.aprovechable, ampliable: true))),
    );
    expect(find.bySemanticsLabel('Ver foto en grande'), findsNothing);
  });

  testWidgets('el logo de EcoResiduos se dibuja correctamente', (tester) async {
    await tester.pumpWidget(app(const Center(child: EcoLogo())));
    expect(find.byType(EcoLogo), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
