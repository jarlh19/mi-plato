import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sesión de Supabase en el almacenamiento seguro del sistema (Keystore en
/// Android, Keychain en iOS), no en `shared_preferences`, que la deja en
/// texto claro dentro de los datos de la app: con root, con un respaldo o
/// con el celular un rato en la mano, el token de renovación entra a la
/// cuenta sin contraseña (estándar E6 del escudo).
///
/// `_this_device`: la sesión no viaja al Keychain de otro iPhone.
const _almacen = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

/// La clave con la que Supabase guardaba la sesión por defecto. Se conserva
/// para encontrar la de quienes ya habían entrado antes de este cambio.
String claveSesion(String url) =>
    'sb-${Uri.parse(url).host.split('.').first}-auth-token';

class SesionSegura extends LocalStorage {
  SesionSegura({required this.clave});

  final String clave;

  /// Mueve una vez la sesión que dejó la versión anterior en
  /// `shared_preferences`, para no sacar a nadie de su cuenta. Si ya hay una
  /// sesión segura, manda esa: la vieja solo se borra.
  @override
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vieja = prefs.getString(clave);
      if (vieja == null) return;
      if (!await _almacen.containsKey(key: clave)) {
        await _almacen.write(key: clave, value: vieja);
      }
      await prefs.remove(clave);
    } catch (e) {
      // La vieja se queda donde estaba y se reintenta al próximo arranque;
      // mientras tanto la persona vuelve a entrar. Solo el tipo: el mensaje
      // podría traer parte de la sesión.
      if (kDebugMode) debugPrint('sesionSegura.mover: ${e.runtimeType}');
    }
  }

  @override
  Future<bool> hasAccessToken() => _almacen.containsKey(key: clave);

  @override
  Future<String?> accessToken() => _almacen.read(key: clave);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _almacen.write(key: clave, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _almacen.delete(key: clave);
}

/// El verificador PKCE de los inicios de sesión que vuelven por redirección.
/// Vive minutos, pero quien lo lea a tiempo puede canjear el código.
class PkceSeguro extends GotrueAsyncStorage {
  const PkceSeguro();

  @override
  Future<String?> getItem({required String key}) => _almacen.read(key: key);

  @override
  Future<void> setItem({required String key, required String value}) =>
      _almacen.write(key: key, value: value);

  @override
  Future<void> removeItem({required String key}) => _almacen.delete(key: key);
}
