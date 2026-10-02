import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/formato.dart';
import '../datos/modelos/modelos.dart';
import '../datos/exportar.dart';
import '../datos/nutricion/calculos.dart';
import '../datos/nutricion/sugerencias.dart';
import '../datos/nutricion/veredicto.dart';
import '../datos/repos/memoria.dart';
import '../datos/repos/operaciones.dart';
import '../datos/repos/repos.dart';
import '../datos/repos/supabase_repos.dart';

// --- Repositorios ---------------------------------------------------------
// Un único punto decide si la app habla con Supabase o con el almacén demo.

final _almacenProvider = Provider((ref) => AlmacenMemoria.instancia);

SupabaseClient get _sb => Supabase.instance.client;

final authRepoProvider = Provider<AuthRepo>(
  (ref) => Config.hayBackend
      ? SbAuthRepo(_sb)
      : MemAuthRepo(ref.watch(_almacenProvider)),
);

final diarioRepoProvider = Provider<DiarioRepo>(
  (ref) => Config.hayBackend
      ? SbDiarioRepo(_sb)
      : MemDiarioRepo(ref.watch(_almacenProvider)),
);

final visionRepoProvider = Provider<VisionRepo>(
  (ref) => Config.hayBackend ? SbVisionRepo(_sb) : VisionDemo(),
);

final fotosRepoProvider = Provider<FotosRepo>(
  (ref) => Config.hayBackend ? SbFotosRepo(_sb) : FotosDemo(),
);

final sugerenciasRepoProvider = Provider<SugerenciasRepo>(
  (ref) => Config.hayBackend ? SbSugerenciasRepo(_sb) : SugerenciasDemo(),
);

/// Enlace temporal para ver la foto de una comida. En modo demo no hay foto.
final fotoUrlProvider = FutureProvider.family<String, String>((ref, ruta) {
  if (!Config.hayBackend || ruta.isEmpty) return Future.value('');
  return urlFirmada(_sb, ruta);
});

// --- Sesión ---------------------------------------------------------------

class SesionNotifier extends Notifier<Perfil?> {
  StreamSubscription<Perfil?>? _sub;

  @override
  Perfil? build() {
    final repo = ref.watch(authRepoProvider);
    _sub = repo.cambios.listen((p) => state = p);
    ref.onDispose(() => _sub?.cancel());
    return repo.perfilActual;
  }

  Future<void> iniciarSesion(String email, String clave) async {
    state = await ref
        .read(authRepoProvider)
        .iniciarSesion(email: email, clave: clave);
  }

  Future<void> registrar({
    required String nombre,
    required String email,
    required String clave,
  }) async {
    state = await ref
        .read(authRepoProvider)
        .registrar(nombre: nombre, email: email, clave: clave);
  }

  Future<void> guardar(Perfil perfil) async {
    state = await ref.read(authRepoProvider).guardarPerfil(perfil);
    ref.invalidate(pesosProvider);
  }

  Future<void> cerrarSesion() async {
    await ref.read(authRepoProvider).cerrarSesion();
    state = null;
  }

  /// Borra la cuenta y todo lo que cuelga de ella.
  ///
  /// Las fotos van primero: si se borrara la cuenta antes, las políticas de
  /// Storage dejarían de reconocer al dueño y las imágenes quedarían huérfanas
  /// en el bucket, que es justo lo que un borrado de datos de salud no puede
  /// permitirse.
  Future<void> borrarCuenta() async {
    final perfil = state;
    if (perfil == null) return;
    await borrarCuentaYFotos(
      auth: ref.read(authRepoProvider),
      fotos: ref.read(fotosRepoProvider),
      perfilId: perfil.id,
    );
    state = null;
  }
}

final sesionProvider = NotifierProvider<SesionNotifier, Perfil?>(
  SesionNotifier.new,
);

/// Meta del día derivada del perfil. `null` mientras no haya sesión: es la
/// señal de que todavía no hay nada que calcular.
final metaProvider = Provider<MetaDiaria?>((ref) {
  final perfil = ref.watch(sesionProvider);
  return perfil == null ? null : metaDiaria(perfil);
});

// --- Diario ---------------------------------------------------------------

/// Día que se está mirando. Permite revisar ayer sin salir de la pantalla.
final diaProvider = StateProvider<DateTime>(
  (ref) => Fmt.soloFecha(DateTime.now()),
);

final comidasDelDiaProvider = FutureProvider<List<Comida>>((ref) {
  final perfil = ref.watch(sesionProvider);
  if (perfil == null) return Future.value(const []);
  return ref
      .watch(diarioRepoProvider)
      .comidasDe(perfil.id, ref.watch(diaProvider));
});

final resumenSemanaProvider = FutureProvider<List<ResumenDia>>((ref) {
  final perfil = ref.watch(sesionProvider);
  if (perfil == null) return Future.value(const []);
  return ref.watch(diarioRepoProvider).resumen(perfil.id, dias: 7);
});

final pesosProvider = FutureProvider<List<RegistroPeso>>((ref) {
  final perfil = ref.watch(sesionProvider);
  if (perfil == null) return Future.value(const []);
  return ref.watch(diarioRepoProvider).pesos(perfil.id);
});

/// Veredicto del día que se está mirando. `null` mientras cargan las comidas.
final veredictoDiaProvider = Provider<Veredicto?>((ref) {
  final perfil = ref.watch(sesionProvider);
  final meta = ref.watch(metaProvider);
  final comidas = ref.watch(comidasDelDiaProvider).valueOrNull;
  if (perfil == null || meta == null || comidas == null) return null;
  return evaluarDia(comidas: comidas, perfil: perfil, meta: meta);
});

// --- Qué comer en lo que queda del día ------------------------------------

/// El hueco del día sale de datos que la app ya tiene. No cuesta nada, no
/// llama a nadie y está disponible aunque nunca se pulse el botón.
final huecoProvider = Provider<HuecoDelDia?>((ref) {
  final meta = ref.watch(metaProvider);
  final comidas = ref.watch(comidasDelDiaProvider).valueOrNull;
  if (meta == null || comidas == null) return null;

  return huecoDelDia(
    meta: meta,
    comido: comidas.fold(Nutrientes.cero, (acc, c) => acc + c.total),
    tiposRegistrados: {for (final c in comidas) c.tipo},
  );
});

/// Las sugerencias no se piden solas: cuestan dinero y solo tienen sentido
/// cuando alguien las pide. Por eso esto arranca vacío y solo se llena al
/// pulsar el botón.
class SugerenciasNotifier extends AsyncNotifier<Sugerencias?> {
  @override
  FutureOr<Sugerencias?> build() {
    // Al cambiar de día lo sugerido deja de corresponder a lo que se ve.
    ref.watch(diaProvider);
    return null;
  }

  Future<void> generar() async {
    final perfil = ref.read(sesionProvider);
    final hueco = ref.read(huecoProvider);
    if (perfil == null || hueco == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final propuesta = await ref
          .read(sugerenciasRepoProvider)
          .sugerir(perfil: perfil, hueco: hueco);

      // El filtro va aquí y no en la pantalla: así no existe una forma de
      // pintar una sugerencia que no haya pasado por las reglas.
      return Sugerencias(
        evaluadas: evaluarSugerencias(propuesta.sugerencias, hueco),
        hueco: hueco,
        nota: propuesta.nota,
      );
    });
  }

  /// Al cambiar de día o registrar una comida, lo sugerido deja de valer.
  void limpiar() => state = const AsyncData(null);
}

final sugerenciasProvider =
    AsyncNotifierProvider<SugerenciasNotifier, Sugerencias?>(
  SugerenciasNotifier.new,
);

// --- Borrador de comida ---------------------------------------------------

/// Comida a medio registrar: la foto ya analizada, con las correcciones que la
/// persona vaya haciendo antes de guardar.
class Borrador {
  const Borrador({
    required this.alimentos,
    required this.tipo,
    required this.fecha,
    this.foto,
    this.extension = 'jpg',
    this.descripcion = '',
    this.aviso = '',
  });

  final List<Alimento> alimentos;
  final TipoComida tipo;
  final DateTime fecha;
  final Uint8List? foto;
  final String extension;
  final String descripcion;

  /// Advertencia del análisis, si la hubo.
  final String aviso;

  Nutrientes get total =>
      alimentos.fold(Nutrientes.cero, (acc, a) => acc + a.total);

  Borrador copiar({
    List<Alimento>? alimentos,
    TipoComida? tipo,
    DateTime? fecha,
  }) => Borrador(
    alimentos: alimentos ?? this.alimentos,
    tipo: tipo ?? this.tipo,
    fecha: fecha ?? this.fecha,
    foto: foto,
    extension: extension,
    descripcion: descripcion,
    aviso: aviso,
  );

  /// Vista previa del veredicto mientras se corrigen las porciones.
  Comida comidaProvisional(String perfilId) => Comida(
    id: '',
    perfilId: perfilId,
    fecha: fecha,
    tipo: tipo,
    alimentos: alimentos,
    descripcion: descripcion,
  );
}

class BorradorNotifier extends AsyncNotifier<Borrador?> {
  /// Devuelve el valor directamente, sin `async`. Con un `build` asíncrono el
  /// estado nace en `AsyncLoading` y su futuro, al resolverse, pisa el borrador
  /// que `empezarAMano` o `analizar` acababan de dejar puesto.
  @override
  FutureOr<Borrador?> build() => null;

  /// Manda la foto al reconocimiento y deja el resultado listo para revisar.
  Future<void> analizar(Uint8List foto, {String extension = 'jpg'}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final analisis = await ref
          .read(visionRepoProvider)
          .analizar(foto: foto, tipoMime: 'image/$extension');
      if (analisis.vacio) {
        throw ErrorApp(
          analisis.aviso.isEmpty
              ? 'No se reconoció ningún alimento en la foto.'
              : analisis.aviso,
        );
      }
      final ahora = DateTime.now();
      return Borrador(
        alimentos: analisis.alimentos,
        tipo: tipoComidaPorHora(ahora),
        fecha: ahora,
        foto: foto,
        extension: extension,
        descripcion: analisis.descripcion,
        aviso: analisis.aviso,
      );
    });
  }

  /// Arranca un registro sin foto, para añadir a mano.
  void empezarAMano() {
    final ahora = DateTime.now();
    state = AsyncData(
      Borrador(
        alimentos: const [],
        tipo: tipoComidaPorHora(ahora),
        fecha: ahora,
      ),
    );
  }

  void limpiar() => state = const AsyncData(null);

  Borrador? get _actual => state.valueOrNull;

  void cambiarTipo(TipoComida tipo) {
    final b = _actual;
    if (b != null) state = AsyncData(b.copiar(tipo: tipo));
  }

  /// [cantidad] llega en la unidad del alimento: mililitros si es líquido.
  void cambiarCantidad(int indice, double cantidad) {
    final b = _actual;
    if (b == null) return;
    final lista = [...b.alimentos];
    // Un ajuste manual deja de ser una estimación del modelo.
    lista[indice] = lista[indice]
        .conCantidad(cantidad)
        .copiar(fuente: FuenteDatos.manual);
    state = AsyncData(b.copiar(alimentos: lista));
  }

  void quitar(int indice) {
    final b = _actual;
    if (b == null) return;
    state = AsyncData(b.copiar(alimentos: [...b.alimentos]..removeAt(indice)));
  }

  void agregar(Alimento alimento) {
    final b = _actual;
    if (b == null) return;
    state = AsyncData(b.copiar(alimentos: [...b.alimentos, alimento]));
  }

  /// Sube la foto (si hay backend) y guarda la comida en el diario.
  Future<void> guardar() async {
    final b = _actual;
    final perfil = ref.read(sesionProvider);
    if (b == null || perfil == null) return;
    if (b.alimentos.isEmpty) {
      throw ErrorApp('Añade al menos un alimento antes de guardar.');
    }

    var ruta = '';
    if (b.foto != null) {
      ruta = await ref
          .read(fotosRepoProvider)
          .subir(perfilId: perfil.id, bytes: b.foto!, extension: b.extension);
    }

    await ref
        .read(diarioRepoProvider)
        .guardar(
          Comida(
            id: '',
            perfilId: perfil.id,
            fecha: b.fecha,
            tipo: b.tipo,
            alimentos: b.alimentos,
            fotoUrl: ruta,
            descripcion: b.descripcion,
          ),
        );

    // El diario solo se refresca si la comida cae en el día que se está viendo.
    if (Fmt.soloFecha(b.fecha) == ref.read(diaProvider)) {
      ref.invalidate(comidasDelDiaProvider);
      ref.invalidate(sugerenciasProvider);
    }
    ref.invalidate(resumenSemanaProvider);
    state = const AsyncData(null);
  }
}

final borradorProvider = AsyncNotifierProvider<BorradorNotifier, Borrador?>(
  BorradorNotifier.new,
);

/// Refresca todo lo que depende del backend tras una escritura.
/// Hay dos entradas porque `Ref` (providers) y `WidgetRef` (widgets) no
/// comparten tipo, pero sí la firma de `invalidate`.
void _invalidarTodo(void Function(ProviderOrFamily) invalidar) {
  invalidar(comidasDelDiaProvider);
  invalidar(resumenSemanaProvider);
  invalidar(pesosProvider);
  // Con una comida más o menos, el hueco es otro y lo sugerido ya no encaja.
  invalidar(sugerenciasProvider);
}

void refrescarTodo(WidgetRef ref) => _invalidarTodo(ref.invalidate);

/// Elimina una comida junto con su foto y refresca lo que dependía de ella.
Future<void> eliminarComida(WidgetRef ref, Comida comida) async {
  await borrarComidaYFoto(
    diario: ref.read(diarioRepoProvider),
    fotos: ref.read(fotosRepoProvider),
    comida: comida,
  );
  refrescarTodo(ref);
}

/// Reúne todo el historial en un JSON que la persona puede llevarse.
Future<String> exportarDatos(WidgetRef ref) async {
  final perfil = ref.read(sesionProvider);
  if (perfil == null) throw ErrorApp('No hay sesión.');
  final diario = ref.read(diarioRepoProvider);
  final comidas = await diario.todasLasComidas(perfil.id);
  final pesos = await diario.pesos(perfil.id);
  return exportarJson(perfil: perfil, comidas: comidas, pesos: pesos);
}
