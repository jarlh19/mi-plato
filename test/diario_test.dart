import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plato/core/formato.dart';
import 'package:mi_plato/datos/modelos/modelos.dart';
import 'package:mi_plato/datos/nutricion/tabla_local.dart';
import 'package:mi_plato/datos/repos/memoria.dart';
import 'package:mi_plato/datos/repos/repos.dart';

void main() {
  group('tabla local', () {
    test('busca ignorando tildes y mayúsculas', () {
      expect(
        buscarLocal('platano').map((a) => a.nombre),
        contains('Plátano o banano'),
      );
      expect(buscarLocal('BRÓCOLI'), isNotEmpty);
    });

    test('encuentra por nombre parcial', () {
      expect(porNombre('arroz blanco cocido')?.nombre, 'Arroz blanco cocido');
      expect(porNombre('pizza')?.nombre, 'Pizza');
      expect(porNombre('sushi de erizo'), isNull);
    });

    test('la porción se escala desde los valores por 100 g', () {
      final arroz = porNombre('Arroz blanco cocido')!;
      final medio = arroz.aAlimento(cantidad: 50);
      expect(medio.total.kcal, closeTo(arroz.por100g.kcal / 2, 0.01));
      expect(medio.fuente, FuenteDatos.base);
    });
  });

  group('nutrientes', () {
    test('se suman y se escalan campo a campo', () {
      const a = Nutrientes(kcal: 100, proteina: 10, sodio: 200);
      const b = Nutrientes(kcal: 50, proteina: 5, fibra: 3);
      final suma = a + b;
      expect(suma.kcal, 150);
      expect(suma.proteina, 15);
      expect(suma.fibra, 3);
      expect(suma.sodio, 200);
      expect((a * 0.5).kcal, 50);
    });
  });

  group('almacén en memoria', () {
    late AlmacenMemoria almacen;
    late MemDiarioRepo diario;
    late MemAuthRepo auth;

    setUp(() {
      almacen = AlmacenMemoria.instancia
        ..comidas.clear()
        ..pesos.clear()
        ..perfiles.clear()
        ..perfilPorEmail.clear()
        ..clavesPorEmail.clear();
      diario = MemDiarioRepo(almacen);
      auth = MemAuthRepo(almacen);
    });

    test('registrar y leer una comida del día', () async {
      final ahora = DateTime.now();
      await diario.guardar(
        Comida(
          id: '',
          perfilId: 'p1',
          fecha: ahora,
          tipo: TipoComida.almuerzo,
          alimentos: [porNombre('Pizza')!.aAlimento(cantidad: 200)],
        ),
      );

      final hoy = await diario.comidasDe('p1', ahora);
      expect(hoy, hasLength(1));
      expect(hoy.first.total.kcal, closeTo(266 * 2, 0.1));

      // Otra persona no ve esa comida.
      expect(await diario.comidasDe('p2', ahora), isEmpty);
      // Y ayer sigue vacío.
      expect(
        await diario.comidasDe('p1', ahora.subtract(const Duration(days: 1))),
        isEmpty,
      );
    });

    test('el resumen incluye los días sin registro', () async {
      await diario.guardar(
        Comida(
          id: '',
          perfilId: 'p1',
          fecha: DateTime.now(),
          tipo: TipoComida.cena,
          alimentos: [porNombre('Manzana')!.aAlimento()],
        ),
      );

      final semana = await diario.resumen('p1', dias: 7);
      expect(semana, hasLength(7));
      expect(semana.last.fecha, Fmt.soloFecha(DateTime.now()));
      expect(semana.last.sinRegistro, isFalse);
      expect(semana.take(6).every((d) => d.sinRegistro), isTrue);
    });

    test('pesarse dos veces el mismo día sustituye el registro', () async {
      await diario.registrarPeso('p1', 84.0);
      await diario.registrarPeso('p1', 83.5);
      final pesos = await diario.pesos('p1');
      expect(pesos, hasLength(1));
      expect(pesos.single.pesoKg, 83.5);
    });

    test('el registro deja el perfil pendiente de completar', () async {
      final perfil = await auth.registrar(
        nombre: 'Ana',
        email: 'ana@ejemplo.com',
        clave: 'secreta',
      );
      expect(perfil.perfilCompleto, isFalse);
      expect(auth.perfilActual?.id, perfil.id);
    });

    test('no deja entrar con la contraseña equivocada', () async {
      await auth.registrar(
        nombre: 'Ana',
        email: 'ana@ejemplo.com',
        clave: 'secreta',
      );
      expect(
        () => auth.iniciarSesion(email: 'ana@ejemplo.com', clave: 'otra'),
        throwsA(isA<ErrorApp>()),
      );
    });

    test('la cuenta demo llega con historial para las gráficas', () async {
      final perfil = await auth.iniciarSesion(
        email: AlmacenMemoria.emailDemo,
        clave: 'demo1234',
      );
      expect(perfil.perfilCompleto, isTrue);
      expect(await diario.pesos(perfil.id), hasLength(greaterThan(2)));
      final semana = await diario.resumen(perfil.id, dias: 7);
      expect(semana.where((d) => !d.sinRegistro), isNotEmpty);
    });
  });

  group('tipo de comida', () {
    test('se sugiere por la hora', () {
      expect(tipoComidaPorHora(DateTime(2026, 8, 31, 8)), TipoComida.desayuno);
      expect(tipoComidaPorHora(DateTime(2026, 8, 31, 13)), TipoComida.almuerzo);
      expect(tipoComidaPorHora(DateTime(2026, 8, 31, 17)), TipoComida.snack);
      expect(tipoComidaPorHora(DateTime(2026, 8, 31, 21)), TipoComida.cena);
    });

    test('las porciones esperadas del día suman uno', () {
      final suma = TipoComida.values.fold(
        0.0,
        (acc, t) => acc + t.porcionDelDia,
      );
      expect(suma, closeTo(1.0, 0.001));
    });
  });
}
