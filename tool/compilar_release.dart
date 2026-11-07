// Compila el release de Android que se reparte o se sube a Play Store.
//
//   dart run tool/compilar_release.dart appbundle [--dart-define-from-file=...]
//   dart run tool/compilar_release.dart apk [...]
//
// Sale ofuscado (--obfuscate) y con los símbolos aparte (--split-debug-info),
// guardados fuera del repo en ~/simbolos-flutter/<app>/<versión>: sin ellos
// no se puede leer un error que llegue de un celular, y en el repo público
// estarían de más. Para leer uno:
//
//   flutter symbolize -i error.txt -d ~/simbolos-flutter/<app>/<versión>/app.android-arm64.symbols
//
// Se niega si falta android/key.properties, porque entonces Gradle firma con
// la llave de depuración, que viene con cada SDK; y si ya hay símbolos de esa
// versión, para no pisarlos: primero se sube `version` en pubspec.yaml.
import 'dart:io';

const tipos = {'apk', 'appbundle'};

List<String> argumentosDeFlutter({
  required String tipo,
  required String simbolos,
  List<String> extra = const [],
}) {
  if (!tipos.contains(tipo)) {
    throw ArgumentError.value(tipo, 'tipo', 'usa apk o appbundle');
  }
  return [
    'build',
    tipo,
    '--release',
    '--obfuscate',
    '--split-debug-info=$simbolos',
    ...extra,
  ];
}

String carpetaSimbolos({
  required String inicio,
  required String app,
  required String version,
}) {
  final s = Platform.pathSeparator;
  return '$inicio${s}simbolos-flutter$s$app$s${version.replaceAll('+', '_')}';
}

String versionDe(String pubspec) =>
    RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1) ??
    '0.0.0';

String nombreDe(String pubspec) =>
    RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspec)?.group(1) ??
    'app';

/// Lo que impide compilar; vacío si se puede.
List<String> problemas({required String raiz, required String simbolos}) => [
  if (!File('$raiz/android/key.properties').existsSync())
    'Falta android/key.properties: el release saldría firmado con la llave de '
        'depuración. Crea la llave propia (ver README) antes de repartir un APK.',
  if (Directory(simbolos).existsSync() &&
      Directory(simbolos).listSync().isNotEmpty)
    'Ya hay símbolos de esta versión en $simbolos. Sube `version` en '
        'pubspec.yaml antes de compilar otra vez.',
];

Future<void> main(List<String> args) async {
  if (args.isEmpty || !tipos.contains(args.first)) {
    stderr.writeln(
      'Uso: dart run tool/compilar_release.dart apk|appbundle [opciones de flutter build]',
    );
    exit(64);
  }
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final inicio =
      Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      '.';
  final simbolos = carpetaSimbolos(
    inicio: inicio,
    app: nombreDe(pubspec),
    version: versionDe(pubspec),
  );

  final frenos = problemas(raiz: '.', simbolos: simbolos);
  if (frenos.isNotEmpty) {
    for (final f in frenos) {
      stderr.writeln('No se compila: $f');
    }
    exit(1);
  }

  final argumentos = argumentosDeFlutter(
    tipo: args.first,
    simbolos: simbolos,
    extra: args.skip(1).toList(),
  );
  stdout.writeln('flutter ${argumentos.join(' ')}');
  final proceso = await Process.start(
    'flutter',
    argumentos,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  final salida = await proceso.exitCode;
  if (salida == 0) {
    stdout.writeln(
      'Símbolos guardados en $simbolos (fuera del repo; no los borres).',
    );
  }
  exit(salida);
}
