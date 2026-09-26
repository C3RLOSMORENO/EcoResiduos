import '../theme/eco_colors.dart';

/// Contenido técnico y normativo por categoría conforme al marco legal ambiental colombiano:
/// - Resolución 2184 de 2019 (Código Nacional de Colores para Separación en la Fuente)
/// - Decreto 1076 de 2015 (Decreto Único Reglamentario del Sector Ambiente - RESPEL)
/// - Ley 1252 de 2008 (Gestión Integral de Residuos Peligrosos)
/// - Ley 1672 de 2013 y Decreto 284 de 2018 (Gestión Integral de RAEE)
/// - Resolución 1257 de 2021 y Resolución 0472 de 2017 (Gestión Integral de RCD)
/// - Resolución 1164 de 2002 y Decreto 780 de 2016 (Manual MPGIRH - Residuos Hospitalarios)
class GuiaCategoria {
  const GuiaCategoria({
    required this.queEs,
    required this.reconocer,
    required this.hacer,
    required this.noHacer,
    required this.entregar,
    required this.consejoResultado,
    required this.normativa,
    required this.codigoColor,
    required this.articuloClave,
  });

  /// Definición técnica precisa del residuo.
  final String queEs;

  /// Criterios visuales y ejemplos para su identificación.
  final String reconocer;

  /// Prácticas obligatorias y recomendadas de manejo.
  final List<String> hacer;

  /// Restricciones y prohibiciones expresas de la norma.
  final List<String> noHacer;

  /// Destino final y canal de recolección formal autorizado.
  final String entregar;

  /// Orientación directa para el usuario tras el análisis de la IA.
  final String consejoResultado;

  /// Norma jurídica colombiana aplicable.
  final String normativa;

  /// Recipiente, bolsa o código de color según la norma técnica.
  final String codigoColor;

  /// Resumen del principio regulatorio aplicable.
  final String articuloClave;
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
    normativa: 'Resolución 2184 de 2019 (MinAmbiente) / Decreto 1077 de 2015',
    codigoColor: 'Caneca o Bolsa Blanca (Aprovechables limpios)',
    articuloClave:
        'Separación en la fuente obligatoria de materiales limpios y secos para reincorporación al ciclo productivo.',
    queEs:
        'Residuos sólidos no biodegradables con potencial de reincorporación a cadenas de reciclaje o reutilización industrial (plásticos, metales, vidrio, papel y cartón). Deben presentarse siempre limpios y secos.',
    reconocer:
        'Botellas plásticas (PET, PEAD), envases tetra pak, cajas de cartón, papel de archivo, periódicos, envases de vidrio, latas de aluminio y chatarra metálica.',
    hacer: [
      'Enjuaga y escurre los envases para eliminar cualquier residuo de líquido o grasa.',
      'Aplasta botellas plásticas y pliega cajas de cartón para optimizar el volumen de almacenamiento.',
      'Mantén el papel y cartón protegidos de la intemperie y la humedad.',
      'Entrega tus materiales a recicladores de oficio organizados o gestores autorizados.',
    ],
    noHacer: [
      'No deposites servilletas usadas, papel higiénico, papeles encerados ni plastificados.',
      'No mezcles vidrios planos rotos (ventanas/espejos) sin embalaje seguro protector.',
      'No entregues envases que hayan contenido agroquímicos, aceites o sustancias tóxicas.',
    ],
    entregar:
        'En la caneca o bolsa blanca, a la organización de recicladores de oficio de tu sector o a un gestor ambiental registrado en EcoResiduos.',
    consejoResultado:
        'Clasificado como APROVECHABLE (Res. 2184/2019). Deposítalo limpio y seco en la caneca blanca o solicita recolección con un gestor.',
  ),
  Categoria.peligroso: GuiaCategoria(
    normativa: 'Decreto 1076 de 2015 (Título 6 - RESPEL) / Ley 1252 de 2008',
    codigoColor: 'Canal Posconsumo / Gestor Licenciado (CRETIB)',
    articuloClave:
        'Prohibición estricta de disposición en rellenos sanitarios o espacio público; manejo exclusivo por gestores autorizados.',
    queEs:
        'Residuos que por sus propiedades corrosivas, reactivas, explosivas, tóxicas, inflamables o infecciosas (características CRETIB) representan un riesgo grave e inminente para la salud humana y el medio ambiente.',
    reconocer:
        'Pilas alcalinas y de botón, baterías de plomo-ácido, aceites usados de motor, solventes, pinturas, plaguicidas, envases a presión (aerosoles) y bombillos ahorradores o tubos fluorescentes (con mercurio).',
    hacer: [
      'Consérvalo en su recipiente original, herméticamente cerrado y con la etiqueta de advertencia legible.',
      'Almacena en un lugar seco, techado, bien ventilado y alejado de fuentes de ignición o calor.',
      'Manipula con guantes de nitrilo o neopreno y elementos de protección personal.',
      'Llévalo a los puntos de recolección de los programas posconsumo aprobados por la ANLA o solicita recolección a gestores RESPEL certificados.',
    ],
    noHacer: [
      'Prohibido verter líquidos químicos, combustibles o aceites en sumideros, alcantarillados o cuerpos de agua.',
      'Prohibido mezclar diferentes tipos de sustancias químicas o residuos peligrosos entre sí.',
      'Prohibido botar en bolsas convencionales de basura domiciliaria o quemar a cielo abierto.',
    ],
    entregar:
        'En puntos de recolección posconsumo autorizados (Lúmina, Pilas con el Ambiente, Recoenergy, CampoLimpio) o a un gestor con Licencia Ambiental emitida por la autoridad competente (CDMB, AMB, CAS, ANLA).',
    consejoResultado:
        'Clasificado como RESIDUO PELIGROSO (Decreto 1076/2015). No lo arrojes a la basura ni lo viertas por el desagüe. Requiere entrega a gestor RESPEL autorizado.',
  ),
  Categoria.raee: GuiaCategoria(
    normativa: 'Ley 1672 de 2013 (Gestión Integral de RAEE) / Decreto 284 de 2018',
    codigoColor: 'Punto Posconsumo RAEE / Desensamble Técnico',
    articuloClave:
        'Principio de Responsabilidad Extendida del Productor (REP) y prohibición de disposición en rellenos sanitarios.',
    queEs:
        'Residuos de Aparatos Eléctricos y Electrónicos (RAEE) que han alcanzado el fin de su vida útil. Contienen metales preciosos recuperables y metales pesados (plomo, mercurio, cadmio) que requieren desmantelamiento técnico controlado.',
    reconocer:
        'Teléfonos móviles, cargadores, computadores, periféricos, tarjetas de circuitos, tabletas, televisores, pantallas LED/LCD, electrodomésticos, herramientas eléctricas y juguetes electrónicos.',
    hacer: [
      'Elimina toda información personal o cuentas vinculadas en dispositivos antes de entregarlos.',
      'Entrega los aparatos íntegros con sus respectivos cables, accesorios y adaptadores.',
      'Almacena bajo techo para evitar la corrosión de componentes y la lixiviación de metales pesados por lluvia.',
      'Deposita en contenedores de programas posconsumo (EcoCómputo, Red Verde) o con gestores autorizados.',
    ],
    noHacer: [
      'Prohibido desarmar, romper pantallas, fracturar tubos o extraer componentes sin tecnología de captura.',
      'Prohibido quemar cables o piezas para extraer cobre u otros metales.',
      'No entregues a recicladores informales no certificados para el tratamiento de RAEE.',
    ],
    entregar:
        'A través de puntos posconsumo de fabricantes (Red Verde, EcoCómputo), jornadas de recolección de las autoridades ambientales o gestores de RAEE autorizados.',
    consejoResultado:
        'Clasificado como RAEE (Ley 1672/2013). Debe entregarse completo, sin desarmar, en puntos posconsumo autorizados o con gestores especializados.',
  ),
  Categoria.rcd: GuiaCategoria(
    normativa: 'Resolución 1257 de 2021 (Modifica Res. 0472/2017 MinAmbiente)',
    codigoColor: 'Acopio en Obra / Escombrera o Planta RCD Autorizada',
    articuloClave:
        'Obligación del generador de garantizar transporte en volquetas registradas y entrega exclusiva en Sitios de Disposición Final o Plantas RCD con Licencia.',
    queEs:
        'Residuos de Construcción y Demolición (RCD) generados en actividades de excavación, cimentación, construcción, remodelación o desmonte de obras civiles, divididos en fracciones aprovechables (pétreos) y no aprovechables.',
    reconocer:
        'Concreto, mortero, ladrillo, teja, cerámica, arena, gravas, drywall, maderas de formaleta, restos de excavación y asfalto.',
    hacer: [
      'Separa en obra los materiales pétreos limpios de metales, maderas, plásticos y papel.',
      'Protege los acopios temporales con lonas o geomallas para evitar dispersión de partículas al aire.',
      'Contrata transporte en volquetas debidamente identificadas, con carpa protectora y Registro Único de Transporte.',
      'Exige y archiva el Certificado de Disposición Final o Aprovechamiento emitido por la escombrera o planta autorizada.',
    ],
    noHacer: [
      'Prohibido arrojar escombros en espacio público, vías, separadores, lotes desocupados, rondas hídricas o humedales.',
      'Prohibido mezclar RCD con residuos peligrosos (asbesto-cemento, solventes, pinturas) o basura común.',
      'No entregues a carretilleros o transportadores no registrados ante la autoridad de tránsito y ambiental.',
    ],
    entregar:
        'En plantas de aprovechamiento de RCD o sitios de disposición final autorizados (escombreras con Licencia Ambiental) mediante transportadores habilitados.',
    consejoResultado:
        'Clasificado como RCD (Res. 1257/2021). No apto para el servicio de aseo ordinario. Requiere acopio en obra y transporte a escombrera o planta autorizada.',
  ),
  Categoria.riesgoBiologico: GuiaCategoria(
    normativa: 'Resolución 1164 de 2002 (Manual MPGIRH) / Decreto 780 de 2016 y Decreto 1076 de 2015',
    codigoColor: 'Bolsa y Caneca Roja / Guardián de Seguridad para Cortopunzantes',
    articuloClave:
        'Manejo riguroso de bioseguridad, rotulado obligatorio de riesgo biológico y tratamiento mediante autoclave o incineración autorizada.',
    queEs:
        'Residuos con presencia potencial o comprobada de microorganismos patógenos (virus, bacterias, hongos) con capacidad de transmitir enfermedades infecciosas a humanos o animales. Requiere ruta hospitalaria estéril.',
    reconocer:
        'Agujas hipodérmicas, jeringas, lancetas, hojas de bisturí, gasas, apósitos, algodones con fluidos corporales, guantes de procedimiento y elementos de bioseguridad contaminados.',
    hacer: [
      'Deposita todos los elementos cortopunzantes de inmediato en un recipiente rígido tipo Guardián de Seguridad (máximo 3/4 de su capacidad).',
      'Utiliza bolsas rojas de alta densidad para biosanitarios, rotuladas con tipo de residuo, fecha y entidad generadora.',
      'Realiza la desactivación o inactivación previa en sitio según el protocolo institucional.',
      'Entrega exclusivamente a empresas gestoras autorizadas con ruta hospitalaria para termodestrucción o esterilización.',
    ],
    noHacer: [
      'Prohibido reencapuchar agujas manualmente con ambas manos o doblarlas antes de desecharlas.',
      'Prohibido arrojar residuos biológicos a bolsas negras o al servicio domiciliario de aseo.',
      'No rebosar los guardianes ni forzar la entrada de material cortopunzante.',
    ],
    entregar:
        'A un gestor autorizado de residuos hospitalarios e infecciosos con vehículo recolector acondicionado y planta de tratamiento térmico certificada.',
    consejoResultado:
        'Clasificado como RIESGO BIOLÓGICO (Res. 1164/2002). Usa bolsa roja y deposita agujas en guardián rígido. Entrega obligatoria a ruta hospitalaria.',
  ),
  Categoria.organico: GuiaCategoria(
    normativa: 'Resolución 2184 de 2019 (Código Nacional de Colores)',
    codigoColor: 'Caneca o Bolsa Verde (Orgánicos aprovechables)',
    articuloClave: 'Aprovechamiento biológico mediante compostaje, lombricultura o generación de biomasa.',
    queEs:
        'Residuos biodegradables de origen vegetal y animal que se descomponen naturalmente mediante procesos biológicos, aptos para transformación en enmiendas orgánicas del suelo (compost o abono) y biogás.',
    reconocer:
        'Restos de verduras, cáscaras de frutas, hortalizas, cuncho/borra de café, bolsitas de té, hojas secas, pasto y podas de jardín.',
    hacer: [
      'Deposita en la caneca o bolsa verde debidamente identificada.',
      'Escurre los líquidos excedentes de los restos de comida antes de su disposición.',
      'Aprovecha en compostaje doméstico o huertas si dispones de espacio adecuado.',
      'Presenta en los días y horarios fijados para la ruta orgánica del servicio de aseo municipal.',
    ],
    noHacer: [
      'No mezcles con plásticos, bolsas metalizadas, icopor ni vidrios.',
      'No incluyas servilletas usadas, papel higiénico ni colillas de cigarrillo en la caneca verde.',
      'No agregues heces de mascotas ni carnes/huesos en composteras domésticas sin tratamiento térmico.',
    ],
    entregar:
        'En la caneca verde para la ruta municipal de orgánicos o en proyectos locales de compostaje comunitario.',
    consejoResultado:
        'Clasificado como ORGÁNICO APROVECHABLE (Res. 2184/2019). Deposítalo en la caneca verde o utilízalo en compostaje.',
  ),
  Categoria.ordinario: GuiaCategoria(
    normativa: 'Resolución 2184 de 2019 / Decreto 1077 de 2015 (Servicio Público de Aseo)',
    codigoColor: 'Caneca o Bolsa Negra (No aprovechables)',
    articuloClave:
        'Disposición final técnica y sanitaria en relleno sanitario autorizado (ej. Parque Tecnológico El Carrasco).',
    queEs:
        'Residuos sólidos que no tienen posibilidad técnica o económica de aprovechamiento o valorización en el mercado actual, cuyo destino final es la disposición en celda de relleno sanitario.',
    reconocer:
        'Papel higiénico, toallas de mano usadas, servilletas sucias, pañales desechables, toallas sanitarias, empaques metalizados de golosinas/snacks, papel carbón y vajilla rota no reciclable.',
    hacer: [
      'Deposita únicamente los materiales no aprovechables en la caneca o bolsa negra.',
      'Cierra firmemente las bolsas para evitar roturas, derrames y proliferación de vectores.',
      'Saca la basura únicamente en los horarios y días autorizados por la empresa prestadora de aseo.',
    ],
    noHacer: [
      'No mezcles materiales aprovechables limpios (plástico, cartón, vidrio) en la bolsa negra.',
      'Prohibido introducir residuos peligrosos, bombillos, medicamentos vencidos o baterías.',
      'No quemes basura ni la abandones en esquinas, separadores o lotes baldíos.',
    ],
    entregar: 'En la caneca o bolsa negra para el camión compactador del servicio público de aseo domiciliario.',
    consejoResultado:
        'Clasificado como NO APROVECHABLE (Res. 2184/2019). Deposítalo en la bolsa negra para el servicio regular de aseo urbano.',
  ),
};
