import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plato/datos/modelos/modelos.dart';
import 'package:mi_plato/datos/nutricion/calculos.dart';
import 'package:mi_plato/datos/nutricion/sugerencias.dart';
import 'package:mi_plato/datos/nutricion/tabla_local.dart';

/// El botón de sugerencias deja que un modelo proponga comida. Lo que impide
/// que eso se convierta en consejo médico sin control es el filtro de este
/// archivo: nada llega a la pantalla sin haber pasado por los topes reales de
/// la persona.
///
/// Por eso las pruebas que importan aquí no son las que comprueban que una
/// sugerencia buena pasa, sino las que comprueban que las malas se caen.
void main() {
  const ana = Perfil(
    id: 'p1',
    nombre: 'Ana',
    sexo: Sexo.femenino,
    edad: 29,
    alturaCm: 162,
    pesoKg: 68,
    actividad: NivelActividad.moderado,
    objetivo: Objetivo.bajarPeso,
    condiciones: {Condicion.hipertension},
    perfilCompleto: true,
  );

  final meta = metaDiaria(ana);

  /// Un hueco cómodo: media tarde, con la cena por registrar.
  HuecoDelDia huecoAmplio() => huecoDelDia(
        meta: meta,
        comido: const Nutrientes(kcal: 600, proteina: 30, sodio: 400),
        tiposRegistrados: {TipoComida.desayuno, TipoComida.almuerzo},
        ahora: DateTime(2026, 9, 29, 17),
      );

  Sugerencia deLaTabla(String nombre, {double? cantidad, String porque = 'x'}) =>
      Sugerencia(
        alimento: porNombre(nombre)!.aAlimento(cantidad: cantidad),
        porque: porque,
      );

  Sugerencia inventada({
    String nombre = 'Cosa',
    double gramos = 100,
    Nutrientes por100g = const Nutrientes(kcal: 100, proteina: 5),
  }) =>
      Sugerencia(
        alimento: Alimento(nombre: nombre, gramos: gramos, por100g: por100g),
        porque: 'x',
      );

  group('el hueco del día', () {
    test('resta lo comido a la meta', () {
      final h = huecoAmplio();
      expect(h.kcal, closeTo(meta.kcal - 600, 0.001));
      expect(h.proteina, closeTo(meta.proteina - 30, 0.001));
    });

    test('pasarse de un macro no crea hueco negativo', () {
      final h = huecoDelDia(
        meta: meta,
        comido: Nutrientes(proteina: meta.proteina + 50),
        tiposRegistrados: const {},
        ahora: DateTime(2026, 9, 29, 9),
      );
      expect(h.proteina, 0);
    });

    test('el margen de un tope se agota, no se vuelve negativo', () {
      final h = huecoDelDia(
        meta: meta,
        comido: Nutrientes(sodio: meta.sodioMax * 2),
        tiposRegistrados: const {},
        ahora: DateTime(2026, 9, 29, 9),
      );
      expect(h.sodioLibre, 0);
    });

    test('no propone una comida que ya se registró', () {
      final h = huecoAmplio();
      expect(h.comidasPendientes, isNot(contains(TipoComida.desayuno)));
      expect(h.comidasPendientes, contains(TipoComida.cena));
    });

    test('a las nueve de la noche ya no propone desayuno', () {
      final h = huecoDelDia(
        meta: meta,
        comido: Nutrientes.cero,
        tiposRegistrados: const {},
        ahora: DateTime(2026, 9, 29, 21),
      );
      expect(h.comidasPendientes, isNot(contains(TipoComida.desayuno)));
      expect(h.comidasPendientes, isNot(contains(TipoComida.almuerzo)));
      expect(h.comidasPendientes, contains(TipoComida.cena));
    });

    test('el snack no caduca: se pica a cualquier hora', () {
      final h = huecoDelDia(
        meta: meta,
        comido: Nutrientes.cero,
        tiposRegistrados: const {},
        ahora: DateTime(2026, 9, 29, 23),
      );
      expect(h.comidasPendientes, contains(TipoComida.snack));
    });

    test('sin calorías que quedar no hay hueco que llenar', () {
      final h = huecoDelDia(
        meta: meta,
        comido: Nutrientes(kcal: meta.kcal),
        tiposRegistrados: const {},
        ahora: DateTime(2026, 9, 29, 12),
      );
      expect(h.hayHueco, isFalse);
    });
  });

  group('el filtro de sugerencias', () {
    test('deja pasar algo que encaja', () {
      final r = evaluarSugerencias(
        [deLaTabla('Pechuga de pollo a la plancha')],
        huecoAmplio(),
      );
      expect(r.single.aceptada, isTrue);
    });

    test('rechaza lo que se pasa de las calorías que quedan', () {
      final h = huecoAmplio();
      final r = evaluarSugerencias(
        [inventada(gramos: 1000, por100g: const Nutrientes(kcal: 500))],
        h,
      );
      expect(r.single.rechazo, MotivoRechazo.pasaKcal);
    });

    test('rechaza el sodio aunque las calorías cuadren', () {
      // Es el caso que justifica todo el filtro: Ana declara hipertensión, así
      // que su tope baja a 1500 mg. Una sopa de sobre entra de sobra en las
      // calorías del día y aun así no debe aparecer.
      final h = huecoAmplio();
      final r = evaluarSugerencias(
        [
          inventada(
            nombre: 'Sopa instantánea',
            gramos: 300,
            por100g: const Nutrientes(kcal: 40, sodio: 700),
          ),
        ],
        h,
      );
      expect(r.single.rechazo, MotivoRechazo.pasaSodio);
    });

    test('rechaza lo que revienta el tope de azúcar', () {
      final r = evaluarSugerencias(
        [deLaTabla('Gaseosa', cantidad: 1000)],
        huecoAmplio(),
      );
      expect(r.single.rechazo, MotivoRechazo.pasaAzucar);
    });

    test('rechaza lo que revienta la grasa saturada', () {
      final r = evaluarSugerencias(
        [
          inventada(
            nombre: 'Chorizo',
            gramos: 200,
            por100g: const Nutrientes(kcal: 100, grasa: 40, saturada: 30),
          ),
        ],
        huecoAmplio(),
      );
      expect(r.single.rechazo, MotivoRechazo.pasaSaturada);
    });

    test('no se cree un alimento imposible', () {
      // 4000 kcal por 100 g no existe: la grasa pura son 884. Un número así
      // solo puede venir de un error o de alguien empujando texto.
      final r = evaluarSugerencias(
        [inventada(por100g: const Nutrientes(kcal: 4000))],
        huecoAmplio(),
      );
      expect(r.single.rechazo, MotivoRechazo.datosImposibles);
    });

    test('no se cree más azúcar que carbohidrato', () {
      final r = evaluarSugerencias(
        [
          inventada(
            por100g: const Nutrientes(kcal: 100, carbohidratos: 10, azucares: 40),
          ),
        ],
        huecoAmplio(),
      );
      expect(r.single.rechazo, MotivoRechazo.datosImposibles);
    });

    test('con el día cubierto no sugiere nada, por bueno que sea', () {
      final lleno = huecoDelDia(
        meta: meta,
        comido: Nutrientes(kcal: meta.kcal),
        tiposRegistrados: const {},
        ahora: DateTime(2026, 9, 29, 20),
      );
      final r = evaluarSugerencias(
        [deLaTabla('Brócoli cocido')],
        lleno,
      );
      expect(r.single.rechazo, MotivoRechazo.sinHueco);
    });

    test('un margen del 10% evita rechazar por unas pocas calorías', () {
      final h = huecoAmplio();
      // Justo por encima de lo que queda, pero dentro del margen. La ración
      // se reparte en 500 g para que el valor por 100 g siga siendo creíble:
      // si no, se caería antes por imposible y esto no probaría el margen.
      final r = evaluarSugerencias(
        [
          inventada(
            gramos: 500,
            por100g: Nutrientes(kcal: h.kcal * 1.05 / 5),
          ),
        ],
        h,
      );
      expect(r.single.aceptada, isTrue);
    });
  });

  group('el conjunto que llega a la pantalla', () {
    test('separa lo aceptado de lo descartado', () {
      final h = huecoAmplio();
      final s = Sugerencias(
        hueco: h,
        evaluadas: evaluarSugerencias(
          [
            deLaTabla('Pechuga de pollo a la plancha'),
            inventada(gramos: 900, por100g: const Nutrientes(kcal: 600)),
          ],
          h,
        ),
      );

      expect(s.aceptadas, hasLength(1));
      expect(s.descartadas, hasLength(1));
      expect(s.vacio, isFalse);
      expect(s.descartadas.single.rechazo, MotivoRechazo.pasaKcal);
    });

    test('si se cae todo, el conjunto queda vacío y se nota', () {
      final h = huecoAmplio();
      final s = Sugerencias(
        hueco: h,
        evaluadas: evaluarSugerencias(
          [inventada(por100g: const Nutrientes(kcal: 4000))],
          h,
        ),
      );
      expect(s.vacio, isTrue);
      expect(s.aceptadas, isEmpty);
    });
  });
}
