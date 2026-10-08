import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plato/datos/modelos/modelos.dart';
import 'package:mi_plato/datos/nutricion/calculos.dart';

/// La meta diaria es el número del que cuelga todo lo demás: si sale mal, cada
/// veredicto de la app sale mal. Estos tests fijan las fórmulas.
void main() {
  const jorge = Perfil(
    id: 'p1',
    nombre: 'Prueba',
    sexo: Sexo.masculino,
    edad: 32,
    alturaCm: 172,
    pesoKg: 84.5,
    actividad: NivelActividad.ligero,
    objetivo: Objetivo.bajarPeso,
    perfilCompleto: true,
  );

  group('IMC', () {
    test('sale del peso y la altura', () {
      expect(imc(84.5, 172), closeTo(28.56, 0.01));
    });

    test('devuelve 0 con datos incompletos, sin dividir por cero', () {
      expect(imc(70, 0), 0);
      expect(imc(0, 170), 0);
    });

    test('clasifica según los cortes de la OMS', () {
      expect(categoriaImc(17.0), CategoriaImc.bajoPeso);
      expect(categoriaImc(22.0), CategoriaImc.normal);
      expect(categoriaImc(24.9), CategoriaImc.normal);
      expect(categoriaImc(25.0), CategoriaImc.sobrepeso);
      expect(categoriaImc(31.0), CategoriaImc.obesidad1);
      expect(categoriaImc(41.0), CategoriaImc.obesidad3);
    });

    test('el rango saludable corresponde a IMC 18.5-24.9', () {
      final r = rangoPesoSaludable(172);
      expect(r.min, closeTo(54.7, 0.1));
      expect(r.max, closeTo(73.7, 0.1));
      expect(imc(r.min, 172), closeTo(18.5, 0.01));
      expect(imc(r.max, 172), closeTo(24.9, 0.01));
    });
  });

  group('gasto energético', () {
    test('Mifflin-St Jeor con el término masculino', () {
      // 10·84.5 + 6.25·172 − 5·32 + 5
      expect(tmb(jorge), closeTo(1765, 0.5));
    });

    test('el término femenino resta 161 en vez de sumar 5', () {
      final ella = jorge.copiar(sexo: Sexo.femenino);
      expect(tmb(jorge) - tmb(ella), 166);
    });

    test('el nivel de actividad multiplica la basal', () {
      expect(gastoDiario(jorge), closeTo(1765 * 1.375, 0.5));
    });
  });

  group('meta diaria', () {
    test('bajar peso aplica un déficit del 20%', () {
      final meta = metaDiaria(jorge);
      expect(meta.kcal, closeTo(meta.gasto * 0.8, 0.5));
      expect(meta.deficit, closeTo(meta.gasto * 0.2, 0.5));
    });

    test('mantener iguala meta y gasto', () {
      final meta = metaDiaria(jorge.copiar(objetivo: Objetivo.mantener));
      expect(meta.kcal, closeTo(meta.gasto, 0.5));
      expect(meta.deficit, closeTo(0, 0.5));
    });

    test('subir masa deja superávit', () {
      final meta = metaDiaria(jorge.copiar(objetivo: Objetivo.subirMasa));
      expect(meta.kcal, greaterThan(meta.gasto));
    });

    test('nunca baja del suelo calórico', () {
      // Mujer menuda y sedentaria: el 80% de su gasto queda por debajo de 1200.
      const menuda = Perfil(
        id: 'p2',
        nombre: 'Prueba',
        sexo: Sexo.femenino,
        edad: 60,
        alturaCm: 150,
        pesoKg: 50,
        actividad: NivelActividad.sedentario,
        objetivo: Objetivo.bajarPeso,
      );
      final meta = metaDiaria(menuda);
      expect(gastoDiario(menuda) * 0.8, lessThan(1200));
      expect(meta.kcal, 1200);
    });

    test('la proteína se topa en el peso saludable, no en el real', () {
      final meta = metaDiaria(jorge);
      // 73.7 kg (tope del rango) × 1.6 g/kg, no 84.5 × 1.6.
      expect(meta.proteina, closeTo(73.66 * 1.6, 0.5));
      expect(meta.proteina, lessThan(84.5 * 1.6));
    });

    test('los macros suman las calorías de la meta', () {
      final meta = metaDiaria(jorge);
      final suma =
          meta.proteina * kcalPorGramoProteina +
          meta.carbohidratos * kcalPorGramoCarbohidrato +
          meta.grasa * kcalPorGramoGrasa;
      expect(suma, closeTo(meta.kcal, 1));
    });

    test('las condiciones endurecen los topes', () {
      final base = metaDiaria(jorge);
      final conTodo = metaDiaria(
        jorge.copiar(
          condiciones: {
            Condicion.hipertension,
            Condicion.diabetes,
            Condicion.colesterolAlto,
          },
        ),
      );
      expect(base.sodioMax, 2000);
      expect(conTodo.sodioMax, 1500);
      expect(conTodo.azucarMax, lessThan(base.azucarMax));
      expect(conTodo.saturadaMax, lessThan(base.saturadaMax));
    });

    test('el ritmo semanal traduce el déficit a kilos', () {
      final meta = metaDiaria(jorge);
      expect(
        meta.ritmoSemanalKg,
        closeTo(meta.deficit * 7 / kcalPorKiloDeGrasa, 0.001),
      );
      // Un déficit del 20% sobre ~2400 kcal ronda el medio kilo semanal.
      expect(meta.ritmoSemanalKg, inInclusiveRange(0.3, 0.6));
    });
  });
}
