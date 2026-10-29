import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// La app guarda la sesión de alguien que anota lo que come: nada de eso debe
// viajar en el respaldo de Google ni pasar a otro celular al cambiar de
// equipo (estándar E6 del escudo).
void main() {
  final manifiesto = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test('el manifiesto apaga el respaldo automático', () {
    expect(manifiesto, contains('android:allowBackup="false"'));
    expect(manifiesto, contains('android:fullBackupContent="false"'));
    expect(
      manifiesto,
      contains('android:dataExtractionRules="@xml/reglas_respaldo"'),
    );
  });

  test('desde Android 12 tampoco pasa nada al cambiar de celular', () {
    // allowBackup="false" no frena la copia de un equipo a otro en Android
    // 12 o más: eso lo deciden estas reglas.
    final reglas = File(
      'android/app/src/main/res/xml/reglas_respaldo.xml',
    ).readAsStringSync();
    for (final seccion in ['cloud-backup', 'device-transfer']) {
      final bloque = RegExp(
        '<$seccion[^>]*>([\\s\\S]*?)</$seccion>',
      ).firstMatch(reglas)?.group(1);
      expect(bloque, isNotNull, reason: 'falta <$seccion>');
      for (final dominio in [
        'root',
        'file',
        'database',
        'sharedpref',
        'external',
      ]) {
        expect(
          bloque,
          contains('<exclude domain="$dominio" path="."/>'),
          reason: '$seccion deja pasar $dominio',
        );
      }
    }
  });

  test('Supabase guarda la sesión en el almacenamiento seguro', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('localStorage: SesionSegura('));
    expect(main, contains(RegExp(r'pkceAsyncStorage: (const )?PkceSeguro\(')));
  });
}
