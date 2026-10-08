import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plato/datos/exportar.dart';
import 'package:mi_plato/datos/modelos/modelos.dart';
import 'package:mi_plato/datos/nutricion/tabla_local.dart';
import 'package:mi_plato/datos/repos/memoria.dart';
import 'package:mi_plato/datos/repos/operaciones.dart';
import 'package:mi_plato/datos/repos/repos.dart';

/// Esta app guarda datos de salud. Llevarse los datos y borrarlos son
/// funciones, no promesas: aquí se comprueba que hacen lo que dicen.

/// Doble de [FotosRepo] que anota lo que se le pide, para poder afirmar sobre
/// el *orden* de las operaciones y no solo sobre el resultado.
class FotosEspia implements FotosRepo {
  final List<String> borradas = [];
  final List<String> carpetasBorradas = [];
  bool fallarAlBorrar = false;

  @override
  Future<String> subir({
    required String perfilId,
    required Uint8List bytes,
    required String extension,
  }) async => '$perfilId/foto.jpg';

  @override
  Future<void> eliminar(String ruta) async {
    if (fallarAlBorrar) throw ErrorApp('Storage caído');
    borradas.add(ruta);
  }

  @override
  Future<void> eliminarTodas(String perfilId) async {
    carpetasBorradas.add(perfilId);
  }
}

/// Doble de [AuthRepo] que solo registra si se llegó a borrar la cuenta.
class AuthEspia implements AuthRepo {
  bool cuentaBorrada = false;
  List<String> orden = [];

  AuthEspia(this.orden);

  @override
  Future<void> borrarCuenta() async {
    cuentaBorrada = true;
    orden.add('cuenta');
  }

  @override
  Stream<Perfil?> get cambios => const Stream.empty();
  @override
  Perfil? get perfilActual => null;
  @override
  Future<void> cerrarSesion() async {}
  @override
  Future<Perfil> guardarPerfil(Perfil perfil) async => perfil;
  @override
  Future<Perfil> iniciarSesion({
    required String email,
    required String clave,
  }) async => throw UnimplementedError();
  @override
  Future<Perfil> registrar({
    required String nombre,
    required String email,
    required String clave,
  }) async => throw UnimplementedError();
}

void main() {
  const perfil = Perfil(
    id: 'p1',
    nombre: 'Ana Ejemplo',
    sexo: Sexo.femenino,
    edad: 29,
    alturaCm: 162,
    pesoKg: 68,
    actividad: NivelActividad.moderado,
    objetivo: Objetivo.bajarPeso,
    condiciones: {Condicion.hipertension},
    perfilCompleto: true,
  );

  Comida comida(String id, {String foto = ''}) => Comida(
    id: id,
    perfilId: 'p1',
    fecha: DateTime(2026, 8, 30, 13),
    tipo: TipoComida.almuerzo,
    alimentos: [porNombre('Arroz blanco cocido')!.aAlimento(cantidad: 150)],
    fotoUrl: foto,
  );

  group('exportar mis datos', () {
    test('produce JSON válido con perfil, comidas y pesos', () {
      final texto = exportarJson(
        perfil: perfil,
        comidas: [comida('c1')],
        pesos: [
          RegistroPeso(
            id: 'w1',
            perfilId: 'p1',
            fecha: DateTime(2026, 8, 30),
            pesoKg: 68,
          ),
        ],
        generadoEn: DateTime.utc(2026, 8, 31, 10),
      );

      final datos = jsonDecode(texto) as Map<String, dynamic>;
      expect(datos['app'], 'Mi Plato');
      expect(datos['version_formato'], 1);
      expect((datos['comidas'] as List), hasLength(1));
      expect((datos['pesos'] as List), hasLength(1));
      expect(datos['perfil']['nombre'], 'Ana Ejemplo');
      expect(datos['perfil']['condiciones'], ['hipertension']);
    });

    test('incluye los cálculos derivados, no solo los datos crudos', () {
      final datos =
          jsonDecode(
                exportarJson(
                  perfil: perfil,
                  comidas: const [],
                  pesos: const [],
                ),
              )
              as Map<String, dynamic>;

      final calculado = datos['calculado'] as Map<String, dynamic>;
      expect(calculado['categoria_imc'], 'sobrepeso');
      expect(calculado['meta_kcal'], greaterThan(1200));
      // Con hipertensión declarada el tope de sodio baja de 2000 a 1500.
      expect(calculado['tope_sodio_mg'], 1500);
    });

    test('no filtra identificadores internos ni rutas de fotos', () {
      final texto = exportarJson(
        perfil: perfil,
        comidas: [comida('c1', foto: 'p1/1234.jpg')],
        pesos: const [],
      );
      expect(texto, isNot(contains('perfil_id')));
      expect(texto, isNot(contains('p1/1234.jpg')));
      expect(texto, contains('guardada en la app'));
    });

    test('anota cada porción en su unidad, no solo en gramos', () {
      final datos =
          jsonDecode(
                exportarJson(
                  perfil: perfil,
                  comidas: [
                    Comida(
                      id: 'c1',
                      perfilId: 'p1',
                      fecha: DateTime(2026, 8, 30, 13),
                      tipo: TipoComida.almuerzo,
                      alimentos: [
                        porNombre('Gaseosa')!.aAlimento(cantidad: 350),
                      ],
                    ),
                  ],
                  pesos: const [],
                ),
              )
              as Map<String, dynamic>;

      final bebida =
          ((datos['comidas'] as List).first['alimentos'] as List).first;
      // Lo que escribió: 350 ml. Lo que se calculó: 364 g. Ambos constan.
      expect(bebida['unidad'], 'ml');
      expect(bebida['cantidad'], closeTo(350, 0.001));
      expect(bebida['gramos'], closeTo(364, 0.001));
    });

    test('ordena las comidas de la más antigua a la más reciente', () {
      final tarde = comida('c2');
      final temprano = Comida(
        id: 'c1',
        perfilId: 'p1',
        fecha: DateTime(2026, 8, 30, 8),
        tipo: TipoComida.desayuno,
        alimentos: const [],
      );
      final datos =
          jsonDecode(
                exportarJson(
                  perfil: perfil,
                  comidas: [tarde, temprano],
                  pesos: const [],
                ),
              )
              as Map<String, dynamic>;

      final ids = (datos['comidas'] as List).map((c) => c['id']).toList();
      expect(ids, ['c1', 'c2']);
    });
  });

  group('borrar una comida', () {
    late AlmacenMemoria almacen;
    late MemDiarioRepo diario;
    late FotosEspia fotos;

    setUp(() {
      almacen = AlmacenMemoria.instancia..comidas.clear();
      diario = MemDiarioRepo(almacen);
      fotos = FotosEspia();
    });

    test('borra también la foto', () async {
      final c = comida('c1', foto: 'p1/1234.jpg');
      almacen.comidas.add(c);

      await borrarComidaYFoto(diario: diario, fotos: fotos, comida: c);

      expect(fotos.borradas, ['p1/1234.jpg']);
      expect(almacen.comidas, isEmpty);
    });

    test('sin foto no toca el almacén de imágenes', () async {
      final c = comida('c1');
      almacen.comidas.add(c);

      await borrarComidaYFoto(diario: diario, fotos: fotos, comida: c);

      expect(fotos.borradas, isEmpty);
      expect(almacen.comidas, isEmpty);
    });

    test(
      'si falla el borrado de la foto, la comida sigue en el diario',
      () async {
        // Es el orden que queremos: así se puede reintentar entero. Al revés
        // quedaría una foto huérfana sin nada que apuntara a ella.
        final c = comida('c1', foto: 'p1/1234.jpg');
        almacen.comidas.add(c);
        fotos.fallarAlBorrar = true;

        await expectLater(
          borrarComidaYFoto(diario: diario, fotos: fotos, comida: c),
          throwsA(isA<ErrorApp>()),
        );
        expect(almacen.comidas, hasLength(1));
      },
    );
  });

  group('borrar la cuenta', () {
    test('borra las fotos antes que la cuenta', () async {
      // Después de borrar la cuenta, las políticas de Storage ya no reconocen
      // al dueño: si el orden se invirtiera, las fotos quedarían para siempre.
      final orden = <String>[];
      final auth = AuthEspia(orden);
      final fotos = _FotosOrdenadas(orden);

      await borrarCuentaYFotos(auth: auth, fotos: fotos, perfilId: 'p1');

      expect(orden, ['fotos', 'cuenta']);
      expect(auth.cuentaBorrada, isTrue);
    });

    test('el almacén demo deja la sesión vacía y sin rastro', () async {
      final almacen = AlmacenMemoria.instancia
        ..comidas.clear()
        ..pesos.clear()
        ..perfiles.clear()
        ..perfilPorEmail.clear()
        ..clavesPorEmail.clear();
      final auth = MemAuthRepo(almacen);
      final diario = MemDiarioRepo(almacen);

      final nuevo = await auth.registrar(
        nombre: 'Ana',
        email: 'ana@ejemplo.com',
        clave: 'secreta',
      );
      await diario.guardar(comida(''));
      await diario.registrarPeso(nuevo.id, 68);

      await auth.borrarCuenta();

      expect(auth.perfilActual, isNull);
      expect(almacen.perfiles, isEmpty);
      expect(almacen.pesos.where((p) => p.perfilId == nuevo.id), isEmpty);
      // Y el correo queda libre para volver a registrarse.
      expect(almacen.perfilPorEmail, isEmpty);
    });
  });
}

/// Variante de [FotosEspia] que anota en la lista compartida, para comprobar
/// el orden frente al borrado de la cuenta.
class _FotosOrdenadas extends FotosEspia {
  _FotosOrdenadas(this.orden);
  final List<String> orden;

  @override
  Future<void> eliminarTodas(String perfilId) async {
    orden.add('fotos');
    await super.eliminarTodas(perfilId);
  }
}
