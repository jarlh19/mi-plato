import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../../core/formato.dart';
import '../modelos/modelos.dart';
import '../nutricion/sugerencias.dart';
import '../nutricion/tabla_local.dart';
import 'repos.dart';

/// Almacén en memoria para el modo demo. Todo vive en el proceso: al cerrar la
/// app no queda nada. Existe para poder recorrer la interfaz completa sin
/// credenciales de Supabase ni clave del modelo.
class AlmacenMemoria {
  AlmacenMemoria._();
  static final instancia = AlmacenMemoria._();

  final Map<String, Perfil> perfiles = {};
  final Map<String, String> clavesPorEmail = {};
  final Map<String, String> perfilPorEmail = {};
  final List<Comida> comidas = [];
  final List<RegistroPeso> pesos = [];

  int _secuencia = 0;
  String nuevoId(String prefijo) => '$prefijo-${++_secuencia}';

  /// Correo con el que se entra a la cuenta de ejemplo, ya con historial.
  static const emailDemo = 'demo@miplato.app';

  bool _sembrado = false;

  /// Crea la cuenta de ejemplo con una semana de comidas y pesajes, para que
  /// las pantallas de progreso tengan algo que enseñar desde el primer minuto.
  Perfil sembrarDemo() {
    if (_sembrado) return perfiles[perfilPorEmail[emailDemo]]!;
    _sembrado = true;

    final perfil = Perfil(
      id: nuevoId('perfil'),
      nombre: 'Cuenta de ejemplo',
      sexo: Sexo.masculino,
      edad: 32,
      alturaCm: 172,
      pesoKg: 84.5,
      actividad: NivelActividad.ligero,
      objetivo: Objetivo.bajarPeso,
      perfilCompleto: true,
    );
    perfiles[perfil.id] = perfil;
    perfilPorEmail[emailDemo] = perfil.id;
    clavesPorEmail[emailDemo] = 'demo1234';

    final hoy = Fmt.soloFecha(DateTime.now());
    for (var d = 6; d >= 1; d--) {
      final dia = hoy.subtract(Duration(days: d));
      pesos.add(
        RegistroPeso(
          id: nuevoId('peso'),
          perfilId: perfil.id,
          fecha: dia,
          // Baja lenta con un repunte: así el gráfico no sale sospechosamente
          // recto, que es como se ve una báscula de verdad.
          pesoKg: 86.0 - (6 - d) * 0.25 + (d == 3 ? 0.4 : 0),
        ),
      );
      for (final plato in _platosDelDia(d)) {
        comidas.add(
          Comida(
            id: nuevoId('comida'),
            perfilId: perfil.id,
            fecha: dia.add(Duration(hours: plato.hora)),
            tipo: plato.tipo,
            alimentos: plato.alimentos,
            descripcion: plato.descripcion,
          ),
        );
      }
    }
    pesos.add(
      RegistroPeso(
        id: nuevoId('peso'),
        perfilId: perfil.id,
        fecha: hoy,
        pesoKg: perfil.pesoKg,
      ),
    );

    return perfil;
  }

  List<_PlatoDemo> _platosDelDia(int diasAtras) {
    final r = Random(diasAtras);
    return [
      _PlatoDemo(8, TipoComida.desayuno, 'Pan con huevo y café', [
        _de('Pan francés', 60),
        _de('Huevo frito', 60),
        _de('Café sin azúcar', 200),
      ]),
      _PlatoDemo(13, TipoComida.almuerzo, 'Arroz con pollo y ensalada', [
        _de('Arroz blanco cocido', 180 + r.nextInt(60).toDouble()),
        _de(
          r.nextBool()
              ? 'Pollo frito con piel'
              : 'Pechuga de pollo a la plancha',
          130,
        ),
        _de('Ensalada de lechuga y tomate', 90),
      ]),
      _PlatoDemo(20, TipoComida.cena, 'Lentejas con arroz', [
        _de('Lentejas cocidas', 200),
        _de('Arroz blanco cocido', 120),
      ]),
    ];
  }

  static Alimento _de(String nombre, double cantidad) =>
      porNombre(nombre)!.aAlimento(cantidad: cantidad);
}

class _PlatoDemo {
  const _PlatoDemo(this.hora, this.tipo, this.descripcion, this.alimentos);
  final int hora;
  final TipoComida tipo;
  final String descripcion;
  final List<Alimento> alimentos;
}

class MemAuthRepo implements AuthRepo {
  MemAuthRepo(this._almacen);

  final AlmacenMemoria _almacen;
  final _ctrl = StreamController<Perfil?>.broadcast();
  Perfil? _actual;

  @override
  Stream<Perfil?> get cambios => _ctrl.stream;

  @override
  Perfil? get perfilActual => _actual;

  @override
  Future<Perfil> iniciarSesion({
    required String email,
    required String clave,
  }) async {
    final correo = email.trim().toLowerCase();
    if (correo == AlmacenMemoria.emailDemo) {
      return _entrar(_almacen.sembrarDemo());
    }
    final id = _almacen.perfilPorEmail[correo];
    if (id == null) throw ErrorApp('No hay ninguna cuenta con ese correo');
    if (_almacen.clavesPorEmail[correo] != clave) {
      throw ErrorApp('La contraseña no coincide');
    }
    return _entrar(_almacen.perfiles[id]!);
  }

  @override
  Future<Perfil> registrar({
    required String nombre,
    required String email,
    required String clave,
  }) async {
    final correo = email.trim().toLowerCase();
    if (_almacen.perfilPorEmail.containsKey(correo)) {
      throw ErrorApp('Ese correo ya está registrado');
    }
    final perfil = Perfil(
      id: _almacen.nuevoId('perfil'),
      nombre: nombre.trim(),
    );
    _almacen.perfiles[perfil.id] = perfil;
    _almacen.perfilPorEmail[correo] = perfil.id;
    _almacen.clavesPorEmail[correo] = clave;
    return _entrar(perfil);
  }

  @override
  Future<void> cerrarSesion() async {
    _actual = null;
    _ctrl.add(null);
  }

  @override
  Future<void> borrarCuenta() async {
    final id = _actual?.id;
    if (id == null) return;
    _almacen.comidas.removeWhere((c) => c.perfilId == id);
    _almacen.pesos.removeWhere((p) => p.perfilId == id);
    _almacen.perfiles.remove(id);
    _almacen.perfilPorEmail.removeWhere((_, v) => v == id);
    _actual = null;
    _ctrl.add(null);
  }

  @override
  Future<Perfil> guardarPerfil(Perfil perfil) async {
    _almacen.perfiles[perfil.id] = perfil;
    return _entrar(perfil);
  }

  Perfil _entrar(Perfil p) {
    _actual = p;
    _ctrl.add(p);
    return p;
  }
}

class MemDiarioRepo implements DiarioRepo {
  MemDiarioRepo(this._almacen);

  final AlmacenMemoria _almacen;

  @override
  Future<List<Comida>> comidasDe(String perfilId, DateTime dia) async {
    final d = Fmt.soloFecha(dia);
    final lista =
        _almacen.comidas
            .where((c) => c.perfilId == perfilId && Fmt.soloFecha(c.fecha) == d)
            .toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));
    return lista;
  }

  @override
  Future<Comida> guardar(Comida comida) async {
    final i = _almacen.comidas.indexWhere((c) => c.id == comida.id);
    if (i >= 0) {
      _almacen.comidas[i] = comida;
      return comida;
    }
    final nueva = comida.id.isEmpty
        ? Comida(
            id: _almacen.nuevoId('comida'),
            perfilId: comida.perfilId,
            fecha: comida.fecha,
            tipo: comida.tipo,
            alimentos: comida.alimentos,
            fotoUrl: comida.fotoUrl,
            descripcion: comida.descripcion,
          )
        : comida;
    _almacen.comidas.add(nueva);
    return nueva;
  }

  @override
  Future<void> eliminar(String comidaId) async {
    _almacen.comidas.removeWhere((c) => c.id == comidaId);
  }

  @override
  Future<List<ResumenDia>> resumen(String perfilId, {int dias = 7}) async {
    final hoy = Fmt.soloFecha(DateTime.now());
    return List.generate(dias, (i) {
      final dia = hoy.subtract(Duration(days: dias - 1 - i));
      final delDia = _almacen.comidas.where(
        (c) => c.perfilId == perfilId && Fmt.soloFecha(c.fecha) == dia,
      );
      return ResumenDia(
        fecha: dia,
        total: delDia.fold(Nutrientes.cero, (acc, c) => acc + c.total),
        comidas: delDia.length,
      );
    });
  }

  @override
  Future<List<Comida>> todasLasComidas(String perfilId) async {
    final lista = _almacen.comidas.where((c) => c.perfilId == perfilId).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    return lista;
  }

  @override
  Future<List<RegistroPeso>> pesos(String perfilId) async {
    final lista = _almacen.pesos.where((p) => p.perfilId == perfilId).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    return lista;
  }

  @override
  Future<RegistroPeso> registrarPeso(String perfilId, double pesoKg) async {
    final hoy = Fmt.soloFecha(DateTime.now());
    _almacen.pesos.removeWhere(
      (p) => p.perfilId == perfilId && Fmt.soloFecha(p.fecha) == hoy,
    );
    final registro = RegistroPeso(
      id: _almacen.nuevoId('peso'),
      perfilId: perfilId,
      fecha: hoy,
      pesoKg: pesoKg,
    );
    _almacen.pesos.add(registro);
    return registro;
  }
}

/// Reconocimiento simulado. **No mira la foto**: devuelve uno de tres platos de
/// ejemplo por turnos. Está solo para que el flujo completo (cámara, revisión,
/// veredicto, guardado) se pueda probar sin clave del modelo.
class VisionDemo implements VisionRepo {
  int _turno = 0;

  static final _platos =
      <({String descripcion, List<(String, double)> partes})>[
        (
          descripcion: 'Arroz con pollo frito y ensalada criolla',
          partes: [
            ('Arroz blanco cocido', 220),
            ('Pollo frito con piel', 140),
            ('Ensalada de lechuga y tomate', 80),
          ],
        ),
        (
          descripcion: 'Avena con plátano y café',
          partes: [
            ('Avena cocida', 250),
            ('Plátano o banano', 110),
            ('Café sin azúcar', 200),
          ],
        ),
        (
          descripcion: 'Hamburguesa con papas fritas y gaseosa',
          partes: [
            ('Hamburguesa', 200),
            ('Papas fritas', 130),
            ('Gaseosa', 350),
          ],
        ),
      ];

  @override
  Future<AnalisisFoto> analizar({
    required Uint8List foto,
    required String tipoMime,
  }) async {
    // Latencia parecida a la real, para que la pantalla de carga se vea igual
    // que en producción.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final plato = _platos[_turno++ % _platos.length];
    return AnalisisFoto(
      descripcion: plato.descripcion,
      alimentos: [
        for (final (nombre, cantidad) in plato.partes)
          porNombre(nombre)!.aAlimento(cantidad: cantidad),
      ],
      aviso:
          'Modo demo: este resultado es un ejemplo fijo, no se analizó tu '
          'foto. Configura Supabase para el reconocimiento real.',
    );
  }
}

/// Sugerencias sin backend.
///
/// No hay modelo detrás: elige de la tabla local lo que mejor tapa el hueco.
/// Sirve para recorrer la pantalla entera en modo demo, y de paso deja ver que
/// la validación es real, porque estas propuestas pasan por el mismo filtro que
/// las del modelo.
class SugerenciasDemo implements SugerenciasRepo {
  @override
  Future<PropuestaSugerencias> sugerir({
    required Perfil perfil,
    required HuecoDelDia hueco,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    // Lo que más falta manda: primero proteína, luego fibra, y si ninguna
    // aprieta, algo ligero que no gaste el presupuesto del día.
    final porProteina = hueco.proteina > 25;
    final porFibra = hueco.fibra > 8;

    double puntua(AlimentoBase a) {
      final n = a.por100g;
      if (porProteina) return n.proteina - n.kcal / 100;
      if (porFibra) return n.fibra - n.kcal / 150;
      return -n.kcal;
    }

    final elegidos = [...catalogoLocal]
      ..sort((a, b) => puntua(b).compareTo(puntua(a)));

    final comida = hueco.comidasPendientes.isEmpty
        ? TipoComida.snack
        : hueco.comidasPendientes.first;

    return PropuestaSugerencias(
      nota:
          'Modo demo: estas propuestas salen de la tabla local, no de un '
          'modelo. Configura Supabase para las sugerencias reales.',
      sugerencias: [
        for (final base in elegidos.take(3))
          Sugerencia(
            alimento: base.aAlimento(),
            comida: comida,
            porque: porProteina
                ? 'Aporta proteína sin gastar muchas calorías, que es lo que '
                      'más te falta hoy.'
                : porFibra
                ? 'Suma fibra, que es lo que peor vas cubriendo hoy.'
                : 'Llena sin gastarte las calorías que te quedan.',
          ),
      ],
    );
  }
}

/// Sin backend no hay dónde subir la foto: la comida se guarda sin imagen.
class FotosDemo implements FotosRepo {
  @override
  Future<String> subir({
    required String perfilId,
    required Uint8List bytes,
    required String extension,
  }) async => '';

  @override
  Future<void> eliminar(String ruta) async {}

  @override
  Future<void> eliminarTodas(String perfilId) async {}
}
