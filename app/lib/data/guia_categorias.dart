import '../theme/eco_colors.dart';

/// Contenido fijo por categoría (Res. 2184 de 2019 y Res. 1164 de 2002).
/// `materiales_residuos` no tiene descripción por categoría, así que vive en la app.
class GuiaCategoria {
  const GuiaCategoria({
    required this.queEs,
    required this.reconocer,
    required this.hacer,
    required this.noHacer,
    required this.entregar,
    required this.consejoResultado,
  });

  /// Explicación corta para la ficha del residuo (11).
  final String queEs;
  final String reconocer;
  final List<String> hacer;
  final List<String> noHacer;
  final String entregar;

  /// Frase bajo la confianza en el resultado de la IA (22).
  final String consejoResultado;
}

/// Categorías que reciben los gestores de la app, con ejemplos para quien
/// no conoce el nombre técnico.
const categoriasPublicables = {
  'APROVECHABLE': 'Cartón, PET, vidrio, metales',
  'PELIGROSO': 'Pilas, aceites, químicos, luminarias',
  'RAEE': 'Celulares, computadores, electrodomésticos',
  'RCD': 'Concreto, ladrillo, madera de obra',
  'RIESGO_BIOLOGICO': 'Hospitalarios, corto-punzantes',
};

const guiasPorCategoria = <Categoria, GuiaCategoria>{
  Categoria.aprovechable: GuiaCategoria(
    queEs: 'Se puede reciclar. Va en la caneca blanca, limpio y seco, o se le entrega a un gestor.',
    reconocer: 'Cartón, papel, botellas y envases de plástico, vidrio, latas y otros metales.',
    hacer: ['Enjuágalo y déjalo secar.', 'Aplasta cajas y botellas para que ocupen menos espacio.'],
    noHacer: ['No lo mezcles con restos de comida.', 'No lo entregues mojado o con grasa.'],
    entregar: 'En la caneca blanca, a un reciclador de oficio o a un gestor de aprovechables.',
    consejoResultado: 'Va en la caneca blanca, limpio y seco. También puedes entregarlo a un gestor.',
  ),
  Categoria.peligroso: GuiaCategoria(
    queEs:
        'Un residuo peligroso puede dañar la salud o el ambiente. No va en ninguna caneca del hogar: '
        'se le entrega a un gestor autorizado o a un punto posconsumo.',
    reconocer: 'Pilas, baterías, aceites de motor, pinturas, solventes, plaguicidas y bombillos fluorescentes.',
    hacer: ['Guárdalo en su envase original y bien tapado.', 'Mantenlo lejos de niños, mascotas y fuentes de calor.'],
    noHacer: ['No lo mezcles con otros residuos ni con agua.', 'No lo botes al sifón ni a la caneca.'],
    entregar: 'A un gestor de RESPEL certificado o a un punto posconsumo.',
    consejoResultado: 'No lo botes a la caneca ni lo mezcles con otros residuos. Manipúlalo con guantes.',
  ),
  Categoria.raee: GuiaCategoria(
    queEs:
        'Son aparatos eléctricos y electrónicos que ya no se usan. Tienen metales pesados, así que no van '
        'en la caneca: se entregan a un gestor de RAEE o a un punto posconsumo.',
    reconocer: 'Celulares, computadores, pantallas, cargadores, electrodomésticos y sus cables.',
    hacer: ['Borra tus datos personales antes de entregarlo.', 'Entrégalo completo, sin desarmarlo.'],
    noHacer: ['No rompas pantallas ni tarjetas.', 'No lo botes con la basura común.'],
    entregar: 'A un gestor de RAEE certificado o a un punto posconsumo como los de Red Verde.',
    consejoResultado: 'Entrégalo completo, sin desarmarlo, a un gestor de RAEE o a un punto posconsumo.',
  ),
  Categoria.rcd: GuiaCategoria(
    queEs:
        'Son los residuos de construcción y demolición. No van en la caneca: se llevan a una escombrera '
        'autorizada.',
    reconocer: 'Concreto, ladrillo, baldosa, arena, madera de obra y restos de demolición.',
    hacer: ['Acópialo en un sitio seco y delimitado.', 'Sepáralo de otros residuos de la obra.'],
    noHacer: ['No lo dejes en la calle, en lotes ni en quebradas.', 'No lo mezcles con residuos peligrosos.'],
    entregar: 'A un gestor de RCD certificado o a una escombrera autorizada, en volqueta habilitada.',
    consejoResultado: 'No va en la caneca. Acópialo aparte y entrégalo a un gestor de escombros.',
  ),
  Categoria.riesgoBiologico: GuiaCategoria(
    queEs:
        'Pueden tener microorganismos que causan enfermedades. Van en bolsa roja y los recoge un gestor '
        'de residuos hospitalarios.',
    reconocer: 'Agujas, lancetas, jeringas, gasas con sangre y residuos de curaciones.',
    hacer: [
      'Echa las agujas en un recipiente rígido con tapa (guardián).',
      'Usa bolsa roja para lo demás y ciérrala bien.',
    ],
    noHacer: ['No reencapuches las agujas.', 'No lo mezcles con la basura común.'],
    entregar: 'A un gestor de residuos hospitalarios o de riesgo biológico.',
    consejoResultado: 'Ciérralo en bolsa roja. Si son agujas, échalas en un recipiente rígido con tapa.',
  ),
  Categoria.organico: GuiaCategoria(
    queEs: 'Restos de comida y de jardín. Van en la caneca verde o se pueden compostar.',
    reconocer: 'Cáscaras, restos de frutas y verduras, cuncho de café, hojas y pasto.',
    hacer: ['Sepáralo en la caneca verde.', 'Si tienes espacio, úsalo para hacer compost.'],
    noHacer: ['No lo mezcles con plásticos ni servilletas.'],
    entregar: 'En la caneca verde, para la ruta de orgánicos del servicio de aseo.',
    consejoResultado:
        'Va en la caneca verde (Res. 2184 de 2019). Los gestores de la app no recogen orgánicos, '
        'así que no hace falta publicarlo.',
  ),
  Categoria.ordinario: GuiaCategoria(
    queEs: 'No se puede aprovechar. Va en la caneca negra y se lo lleva el servicio de aseo.',
    reconocer: 'Servilletas y papel higiénico usados, icopor sucio, empaques metalizados.',
    hacer: ['Revisa que no tenga nada que se pueda reciclar.', 'Ciérralo bien en bolsa negra.'],
    noHacer: ['No mezcles residuos peligrosos con los ordinarios.'],
    entregar: 'En la caneca negra, para el camión del servicio de aseo.',
    consejoResultado:
        'Va en la caneca negra. Los gestores de la app no recogen ordinarios, así que no hace falta publicarlo.',
  ),
};
