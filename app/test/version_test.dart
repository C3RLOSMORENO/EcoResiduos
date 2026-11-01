import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la versión de pubspec.yaml tiene sus novedades en CHANGELOG.md', () {
    // El release del APK publica esa sección (.github/workflows/build-apk.yml).
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true).firstMatch(pubspec)!.group(1)!;

    final lineas = File('CHANGELOG.md').readAsLinesSync();
    final inicio = lineas.indexWhere((l) => l == '## $version' || l.startsWith('## $version '));
    expect(inicio, isNot(-1), reason: 'Falta «## $version» en app/CHANGELOG.md');

    final seccion = lineas.skip(inicio + 1).takeWhile((l) => !l.startsWith('## '));
    expect(seccion.any((l) => l.startsWith('- ')), isTrue, reason: 'La sección $version no tiene novedades');
  });
}
