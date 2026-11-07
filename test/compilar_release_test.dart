import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/compilar_release.dart';

/// El release que se reparte sale ofuscado, con los símbolos guardados fuera
/// del repo, y firmado con la llave propia: con la de depuración, cualquiera
/// que tenga esa llave (viene con cada SDK) puede publicar una "actualización"
/// encima. `tool/compilar_release.dart` es el único camino y se niega si algo
/// de eso falta.
void main() {
  late Directory raiz;

  setUp(() {
    raiz = Directory.systemTemp.createTempSync('release_');
    Directory('${raiz.path}/android').createSync();
  });
  tearDown(() => raiz.deleteSync(recursive: true));

  test('compila ofuscado y deja los símbolos donde se le dice', () {
    expect(argumentosDeFlutter(tipo: 'appbundle', simbolos: r'C:\s\v1'), [
      'build',
      'appbundle',
      '--release',
      '--obfuscate',
      r'--split-debug-info=C:\s\v1',
    ]);
    expect(
      argumentosDeFlutter(
        tipo: 'apk',
        simbolos: 'x',
        extra: ['--dart-define-from-file=prod.json'],
      ).last,
      '--dart-define-from-file=prod.json',
    );
    expect(
      () => argumentosDeFlutter(tipo: 'ios', simbolos: 'x'),
      throwsArgumentError,
    );
  });

  test('los símbolos van fuera del repo, por app y por versión', () {
    final carpeta = carpetaSimbolos(
      inicio: r'C:\Users\ana',
      app: 'tienda_barrio',
      version: '1.2.0+7',
    );
    expect(
      carpeta,
      endsWith(
        'simbolos-flutter${Platform.pathSeparator}tienda_barrio${Platform.pathSeparator}1.2.0_7',
      ),
    );
    expect(versionDe('name: x\nversion: 1.2.0+7\n'), '1.2.0+7');
    expect(nombreDe('name: tienda_barrio\nversion: 1.0.0\n'), 'tienda_barrio');
  });

  test(
    'sin llave propia se niega: el release saldría firmado con la de depuración',
    () {
      final simbolos = '${raiz.path}/simbolos';
      expect(problemas(raiz: raiz.path, simbolos: simbolos), [
        contains('key.properties'),
      ]);
      File(
        '${raiz.path}/android/key.properties',
      ).writeAsStringSync('storeFile=x');
      expect(problemas(raiz: raiz.path, simbolos: simbolos), isEmpty);
    },
  );

  test('no pisa los símbolos de una versión ya compilada', () {
    File(
      '${raiz.path}/android/key.properties',
    ).writeAsStringSync('storeFile=x');
    final simbolos = Directory('${raiz.path}/simbolos')..createSync();
    File('${simbolos.path}/app.android-arm64.symbols').writeAsStringSync('');
    expect(problemas(raiz: raiz.path, simbolos: simbolos.path), [
      contains('pubspec.yaml'),
    ]);
  });

  test('Gradle firma con key.properties cuando existe', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('rootProject.file("key.properties")'));
    expect(gradle, contains('signingConfigs.findByName("publicacion")'));
  });
}
