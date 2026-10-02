import '../modelos/modelos.dart';
import 'repos.dart';

/// Operaciones que tocan dos almacenes a la vez.
///
/// Viven fuera de los repositorios porque ninguno de los dos manda sobre el
/// otro: la fila está en Postgres y la imagen en Storage. Y viven fuera de los
/// providers porque reciben las interfaces en vez de un `Ref`, que es lo que
/// permite probarlas con dobles sin levantar un widget.

/// Borra una comida y la foto que la acompaña.
///
/// El orden importa: primero la foto. Si el borrado de la imagen falla, la
/// comida sigue en el diario y se puede reintentar entera; al revés quedaría
/// una foto huérfana en el bucket sin ningún registro que la explique, y nada
/// volvería a apuntar a ella para borrarla.
Future<void> borrarComidaYFoto({
  required DiarioRepo diario,
  required FotosRepo fotos,
  required Comida comida,
}) async {
  if (comida.fotoUrl.isNotEmpty) {
    await fotos.eliminar(comida.fotoUrl);
  }
  await diario.eliminar(comida.id);
}

/// Borra la cuenta y todo lo que cuelga de ella.
///
/// Las fotos van primero por la misma razón, agravada: al desaparecer la cuenta
/// las políticas de Storage dejan de reconocer al dueño, así que después ya no
/// habría permiso para borrarlas. Quedarían imágenes de comida de una persona
/// que pidió que no quedara nada.
Future<void> borrarCuentaYFotos({
  required AuthRepo auth,
  required FotosRepo fotos,
  required String perfilId,
}) async {
  await fotos.eliminarTodas(perfilId);
  await auth.borrarCuenta();
}
