import 'package:mi_plato/datos/sesion_segura.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const clave = 'sb-abcd-auth-token';
  const seguro = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('la clave es la misma que usaba Supabase por defecto', () {
    expect(claveSesion('https://abcd.supabase.co'), clave);
  });

  test(
    'la sesión vieja pasa una vez al almacenamiento seguro y sale de las preferencias',
    () async {
      SharedPreferences.setMockInitialValues({clave: '{"vieja":true}'});
      final sesion = SesionSegura(clave: clave);
      await sesion.initialize();

      expect(await sesion.hasAccessToken(), isTrue);
      expect(await sesion.accessToken(), '{"vieja":true}');
      expect(await seguro.read(key: clave), '{"vieja":true}');
      expect(
        (await SharedPreferences.getInstance()).containsKey(clave),
        isFalse,
      );
    },
  );

  test(
    'una sesión ya segura no la pisa una vieja que quedó en las preferencias',
    () async {
      FlutterSecureStorage.setMockInitialValues({clave: '{"nueva":true}'});
      SharedPreferences.setMockInitialValues({clave: '{"vieja":true}'});
      final sesion = SesionSegura(clave: clave);
      await sesion.initialize();

      expect(await sesion.accessToken(), '{"nueva":true}');
      expect(
        (await SharedPreferences.getInstance()).containsKey(clave),
        isFalse,
      );
    },
  );

  test('guardar y cerrar sesión no tocan las preferencias', () async {
    final sesion = SesionSegura(clave: clave);
    await sesion.initialize();

    await sesion.persistSession('{"token":"t"}');
    expect(await seguro.read(key: clave), '{"token":"t"}');
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);

    await sesion.removePersistedSession();
    expect(await sesion.hasAccessToken(), isFalse);
    expect(await seguro.read(key: clave), isNull);
  });

  test(
    'el verificador PKCE también queda en el almacenamiento seguro',
    () async {
      final pkce = PkceSeguro();
      await pkce.setItem(key: 'sb-abcd-auth-token-code-verifier', value: 'v');

      expect(await pkce.getItem(key: 'sb-abcd-auth-token-code-verifier'), 'v');
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);

      await pkce.removeItem(key: 'sb-abcd-auth-token-code-verifier');
      expect(
        await pkce.getItem(key: 'sb-abcd-auth-token-code-verifier'),
        isNull,
      );
    },
  );
}
