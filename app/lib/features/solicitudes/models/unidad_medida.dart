/// Representa una opción de unidad de medida para recolección de residuos.
class UnidadMedidaOpcion {
  final String codigo;
  final String nombre;

  const UnidadMedidaOpcion({required this.codigo, required this.nombre});
}

/// Opciones normalizadas de unidades de medida estándar de la industria.
const List<UnidadMedidaOpcion> unidadesMedidaDisponibles = [
  UnidadMedidaOpcion(codigo: 'KG', nombre: 'KG (Kilogramos)'),
  UnidadMedidaOpcion(codigo: 'TON', nombre: 'TON (Toneladas)'),
  UnidadMedidaOpcion(codigo: 'UNIDADES', nombre: 'UNIDADES (Unidades / Piezas)'),
  UnidadMedidaOpcion(codigo: 'LITROS', nombre: 'LITROS (Litros)'),
  UnidadMedidaOpcion(codigo: 'GALONES', nombre: 'GALONES (Galones)'),
  UnidadMedidaOpcion(codigo: 'CANECAS', nombre: 'CANECAS (Canecas de 55 galones)'),
  UnidadMedidaOpcion(codigo: 'M3', nombre: 'M3 (Metros cúbicos)'),
];
