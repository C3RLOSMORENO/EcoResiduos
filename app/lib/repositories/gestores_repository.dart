import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/autoridad_ambiental.dart';
import '../models/gestor.dart';
import '../services/ubicacion_service.dart';

/// Consultas del directorio: gestores certificados y autoridades ambientales.
abstract class GestoresRepository {
  /// Gestores aprobados con sus materiales verificados, del más cercano al
  /// más lejano cuando se conoce la ubicación del usuario.
  Future<List<Gestor>> getDirectorio();

  /// Gestores que reciben [categoria], como máximo [limite], más cercanos primero.
  Future<List<Gestor>> getGestoresPorCategoria(String categoria, {int limite = 10});

  Future<List<AutoridadAmbiental>> getAutoridades();
}

class SupabaseGestoresRepository implements GestoresRepository {
  SupabaseGestoresRepository({this.client});

  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  @override
  Future<List<Gestor>> getDirectorio() async {
    List<dynamic> filas;
    try {
      filas = await _consultarAprobados('*, gestor_material(verificado, materiales_residuos(categoria))');
    } on PostgrestException catch (e) {
      // 42703: la columna `verificado` no existe mientras no se ejecute la migración de reglas de negocio.
      if (e.code != '42703') rethrow;
      filas = await _consultarAprobados('*, gestor_material(materiales_residuos(categoria))');
    }

    final posicion = await UbicacionService.actual();
    final gestores = [
      for (final fila in filas.whereType<Map<String, dynamic>>())
        () {
          final gestor = Gestor.fromMap(fila);
          return gestor.conDistancia(UbicacionService.distanciaKm(posicion, gestor.latitud, gestor.longitud));
        }(),
    ];
    gestores.sort((a, b) => (a.distanciaKm ?? double.infinity).compareTo(b.distanciaKm ?? double.infinity));
    return gestores;
  }

  Future<List<dynamic>> _consultarAprobados(String columnas) {
    return _supabase
        .from('perfiles_gestor')
        .select(columnas)
        .eq('estado_verificacion', 'APROBADO')
        .order('razon_social');
  }

  @override
  Future<List<Gestor>> getGestoresPorCategoria(String categoria, {int limite = 10}) async {
    final buscada = categoria.toUpperCase();
    final directorio = await getDirectorio();
    return directorio.where((g) => g.categorias.contains(buscada)).take(limite).toList();
  }

  @override
  Future<List<AutoridadAmbiental>> getAutoridades() async {
    final List<dynamic> filas = await _supabase.from('autoridades_ambientales').select().order('nombre');
    return filas.map((f) => AutoridadAmbiental.fromMap(f as Map<String, dynamic>)).toList();
  }
}
