import 'dart:typed_data';

import '../modelos/modelos.dart';
import '../nutricion/sugerencias.dart';

/// Contratos de datos. La app solo conoce estas interfaces; detrás puede estar
/// Supabase (producción) o el almacén en memoria (modo demo).

class ErrorApp implements Exception {
  ErrorApp(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

abstract class AuthRepo {
  /// Emite el perfil cada vez que cambia la sesión (`null` = sin sesión).
  Stream<Perfil?> get cambios;

  Perfil? get perfilActual;

  Future<Perfil> iniciarSesion({required String email, required String clave});

  Future<Perfil> registrar({
    required String nombre,
    required String email,
    required String clave,
  });

  Future<void> cerrarSesion();

  Future<Perfil> guardarPerfil(Perfil perfil);

  /// Borra la cuenta y todo lo que cuelga de ella, sin vuelta atrás.
  ///
  /// Esto guarda datos de salud, así que el borrado tiene que existir de
  /// verdad: no vale con marcar la cuenta como inactiva y dejar el diario en
  /// la base.
  Future<void> borrarCuenta();
}

abstract class DiarioRepo {
  /// Comidas de un día concreto, de la más antigua a la más reciente.
  Future<List<Comida>> comidasDe(String perfilId, DateTime dia);

  /// Inserta o actualiza. Devuelve la comida con el id definitivo.
  Future<Comida> guardar(Comida comida);

  Future<void> eliminar(String comidaId);

  /// Totales por día de los últimos [dias], incluidos los días sin registro
  /// (con [ResumenDia.sinRegistro] en `true`) para que el gráfico no tenga
  /// huecos.
  Future<List<ResumenDia>> resumen(String perfilId, {int dias = 7});

  /// Todas las comidas registradas, de la más antigua a la más reciente.
  /// Solo la usa la exportación: el diario nunca las pide todas de golpe.
  Future<List<Comida>> todasLasComidas(String perfilId);

  Future<List<RegistroPeso>> pesos(String perfilId);

  /// Un pesaje por día: volver a pesarse el mismo día pisa el anterior.
  Future<RegistroPeso> registrarPeso(String perfilId, double pesoKg);
}

/// Lo que devuelve el reconocimiento de una foto, antes de que la persona lo
/// corrija.
class AnalisisFoto {
  const AnalisisFoto({
    required this.alimentos,
    this.descripcion = '',
    this.aviso = '',
  });

  final List<Alimento> alimentos;

  /// Cómo describió el plato el modelo, en una frase.
  final String descripcion;

  /// Mensaje cuando la foto no da para más: mala luz, plato tapado, no es
  /// comida. Vacío si todo fue bien.
  final String aviso;

  bool get vacio => alimentos.isEmpty;
}

abstract class VisionRepo {
  /// Reconoce los alimentos de una foto y busca sus nutrientes.
  ///
  /// La clave del modelo vive en el servidor, nunca en el cliente: esta
  /// llamada solo manda la imagen y espera el JSON ya resuelto.
  Future<AnalisisFoto> analizar({
    required Uint8List foto,
    required String tipoMime,
  });
}

/// Pide qué comer en lo que queda del día.
///
/// Devuelve propuestas **sin evaluar**: quien las reciba tiene que pasarlas por
/// `evaluarSugerencias` antes de enseñarlas. La separación es deliberada, para
/// que no exista un camino en el que una sugerencia llegue a la pantalla sin
/// haberse contrastado con los topes de la persona.
abstract class SugerenciasRepo {
  Future<PropuestaSugerencias> sugerir({
    required Perfil perfil,
    required HuecoDelDia hueco,
  });
}

/// Lo que devuelve el servidor antes de pasar por las reglas.
class PropuestaSugerencias {
  const PropuestaSugerencias({required this.sugerencias, this.nota = ''});

  final List<Sugerencia> sugerencias;

  /// Comentario del modelo sobre el conjunto, en una frase.
  final String nota;
}

abstract class FotosRepo {
  /// Guarda la foto de la comida y devuelve la URL con la que se muestra.
  /// En modo demo devuelve cadena vacía: no hay dónde subirla.
  Future<String> subir({
    required String perfilId,
    required Uint8List bytes,
    required String extension,
  });

  /// Borra una foto concreta. Se llama al eliminar la comida: el bucket no
  /// participa en las cascadas de Postgres, así que sin esto la imagen
  /// sobreviviría al registro que la explicaba.
  Future<void> eliminar(String ruta);

  /// Borra todas las fotos de una persona. Solo la usa el borrado de cuenta.
  Future<void> eliminarTodas(String perfilId);
}
