import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre el marcador del teléfono con [telefono].
Future<void> llamar(BuildContext context, String telefono) async {
  final numero = telefono.replaceAll(RegExp(r'[^0-9+]'), '');
  await _abrir(context, Uri(scheme: 'tel', path: numero), 'No pudimos abrir el marcador del teléfono.');
}

/// Abre Google Maps con la ruta hacia unas coordenadas o una dirección.
Future<void> comoLlegar(
  BuildContext context, {
  double? latitud,
  double? longitud,
  String? direccion,
  String? municipio,
}) async {
  final destino = latitud != null && longitud != null
      ? '$latitud,$longitud'
      : [direccion, municipio, 'Santander, Colombia'].where((p) => p != null && p.trim().isNotEmpty).join(', ');
  final uri = Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': destino});
  await _abrir(context, uri, 'No pudimos abrir Google Maps.');
}

/// Abre la app de correo con [correo] como destinatario.
Future<void> escribirCorreo(BuildContext context, String correo) async {
  await _abrir(context, Uri(scheme: 'mailto', path: correo), 'No pudimos abrir tu app de correo.');
}

Future<void> _abrir(BuildContext context, Uri uri, String mensajeError) async {
  final messenger = ScaffoldMessenger.of(context);
  final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!abierto) messenger.showSnackBar(SnackBar(content: Text(mensajeError)));
}
