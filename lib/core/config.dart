/// Configuración de entorno.
///
/// Las credenciales entran por `--dart-define` para no quedar escritas en el
/// repositorio:
///
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///
/// Si faltan, la app arranca en **modo demo**: los datos viven en memoria y el
/// análisis de la foto lo simula un plato de ejemplo. Sirve para recorrer toda
/// la interfaz sin backend, pero nada se guarda al cerrar y el reconocimiento
/// no es real.
///
/// La clave de Anthropic **nunca** entra aquí: vive en la Edge Function
/// `analizar-comida` (ver `supabase/functions/`). Si estuviera en el cliente,
/// cualquiera que descompile el APK podría extraerla.
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get hayBackend =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get modoDemo => !hayBackend;

  static const nombreApp = 'Mi Plato';

  /// Nombre de la Edge Function que reconoce el plato y devuelve los nutrientes.
  static const funcionAnalisis = 'analizar-comida';
  static const funcionSugerencias = 'sugerir-comidas';

  /// Bucket de Storage donde quedan las fotos de las comidas.
  static const bucketFotos = 'comidas';
}
