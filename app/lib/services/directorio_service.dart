import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/autoridad_ambiental.dart';
import '../models/gestor.dart';

/// Servicio para consultar gestores y autoridades ambientales.
class DirectorioService {
  
  Future<List<Gestor>> gestores() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('perfiles_gestor').select();
      final List<dynamic> data = response;
      if (data.isEmpty) {
        throw Exception('Lista vacía');
      }

      // Obtener ubicación del usuario de forma segura
      Position? userPos;
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse || 
              permission == LocationPermission.always) {
            userPos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 5),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error obteniendo GPS: $e');
      }

      final gestores = data.map((json) {
        double distancia = 0.0;
        final double? gestorLat = json['latitud'] != null ? double.tryParse(json['latitud'].toString()) : null;
        final double? gestorLon = json['longitud'] != null ? double.tryParse(json['longitud'].toString()) : null;

        if (userPos != null && gestorLat != null && gestorLon != null) {
          final distanceMeters = Geolocator.distanceBetween(
            userPos.latitude, userPos.longitude, gestorLat, gestorLon);
          distancia = double.parse((distanceMeters / 1000).toStringAsFixed(1));
        }

        return Gestor(
          nombre: json['razon_social']?.toString() ?? '',
          categoria: json['municipio']?.toString() ?? 'Gestor Autorizado', 
          distanciaKm: distancia,
          direccion: json['direccion']?.toString() ?? '',
          telefono: json['telefono_contacto']?.toString() ?? '',
          correo: json['email_contacto']?.toString() ?? '',
          horario: json['estado_verificacion'] == 'verificado' ? 'Verificado' : 'Pendiente',
          latitud: gestorLat,
          longitud: gestorLon,
        );
      }).toList();

      // Ordenar por distancia de menor a mayor
      gestores.sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));
      return gestores;
    } catch (e) {
      // Fallback temporal si la tabla no existe o Supabase falla
      return const [
        Gestor(
          nombre: 'Recicladora Santander',
          categoria: 'Plásticos y papel',
          distanciaKm: 2.3,
          direccion: 'Cra 20 #45-12, Bucaramanga',
          telefono: '(607) 000 0000',
          correo: 'contacto@ejemplo.com',
          horario: 'Lun–Vie 8:00–17:00',
        ),
        Gestor(
          nombre: 'EcoGestión Oriente',
          categoria: 'Residuos peligrosos',
          distanciaKm: 4.1,
          direccion: 'Cra 20 #45-12, Bucaramanga',
          telefono: '(607) 000 0000',
          correo: 'contacto@ejemplo.com',
          horario: 'Lun–Vie 8:00–17:00',
        ),
        Gestor(
          nombre: 'Reciclaje Bucaramanga',
          categoria: 'Multimaterial',
          distanciaKm: 5.0,
          direccion: 'Cra 20 #45-12, Bucaramanga',
          telefono: '(607) 000 0000',
          correo: 'contacto@ejemplo.com',
          horario: 'Lun–Vie 8:00–17:00',
        ),
      ];
    }
  }

  Future<List<AutoridadAmbiental>> autoridades() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('autoridades_ambientales').select();
      final List<dynamic> data = response;
      if (data.isEmpty) {
        throw Exception('Lista vacía');
      }
      return data.map((json) => AutoridadAmbiental.fromJson(json)).toList();
    } catch (e) {
      // Fallback temporal
      return const [
        AutoridadAmbiental(
          nombre: 'CDMB',
          descripcion: 'Autoridad ambiental regional',
          direccion: 'Cra 20 #45-12, Bucaramanga',
          telefono: '(607) 000 0000',
          correo: 'contacto@ejemplo.com',
          sitioWeb: 'Lun–Vie 8:00–17:00',
        ),
        AutoridadAmbiental(
          nombre: 'Alcaldía de Bucaramanga',
          descripcion: 'Secretaría de Medio Ambiente',
          direccion: 'Cra 20 #45-12, Bucaramanga',
          telefono: '(607) 000 0000',
          correo: 'contacto@ejemplo.com',
          sitioWeb: 'Lun–Vie 8:00–17:00',
        ),
        AutoridadAmbiental(
          nombre: 'ANLA',
          descripcion: 'Autoridad Nacional de Licencias',
          direccion: 'Cra 20 #45-12, Bucaramanga',
          telefono: '(607) 000 0000',
          correo: 'contacto@ejemplo.com',
          sitioWeb: 'Lun–Vie 8:00–17:00',
        ),
      ];
    }
  }
}
