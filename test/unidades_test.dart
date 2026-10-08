import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plato/core/formato.dart';
import 'package:mi_plato/datos/modelos/modelos.dart';
import 'package:mi_plato/datos/nutricion/tabla_local.dart';

/// Un vaso de gaseosa se sirve en mililitros, no en gramos: nadie pesa una
/// bebida. Pero los nutrientes de cualquier base vienen por 100 g, así que la
/// porción se guarda en gramos y la densidad traduce entre las dos unidades.
///
/// Estas pruebas fijan esa frontera: que lo que la persona escribe le vuelva
/// igual, y que los gramos con los que se calcula sean los correctos.
void main() {
  group('sólidos', () {
    test('se miden en gramos y no llevan densidad', () {
      final arroz = porNombre('Arroz blanco cocido')!.aAlimento(cantidad: 150);

      expect(arroz.esLiquido, isFalse);
      expect(arroz.unidad, 'g');
      expect(arroz.gramos, 150);
      expect(arroz.cantidad, 150);
    });

    test('cambiar la cantidad cambia los gramos uno a uno', () {
      final arroz = porNombre('Arroz blanco cocido')!.aAlimento();
      expect(arroz.conCantidad(200).gramos, 200);
    });
  });

  group('líquidos', () {
    test('la cantidad escrita son mililitros, no gramos', () {
      // 350 ml de gaseosa: una lata. Pesa más que 350 g de agua porque el
      // azúcar disuelto la hace más densa.
      final gaseosa = porNombre('Gaseosa')!.aAlimento(cantidad: 350);

      expect(gaseosa.esLiquido, isTrue);
      expect(gaseosa.unidad, 'ml');
      expect(gaseosa.cantidad, closeTo(350, 0.001));
      expect(gaseosa.gramos, closeTo(364, 0.001));
    });

    test('las calorías se calculan sobre la masa, no sobre el volumen', () {
      final gaseosa = porNombre('Gaseosa')!.aAlimento(cantidad: 350);

      // 364 g * 42 kcal/100 g. Tomar el volumen por masa daría 147 kcal:
      // un 4% menos, que es justo el error que la densidad corrige.
      expect(gaseosa.total.kcal, closeTo(152.88, 0.01));
      expect(gaseosa.total.azucares, closeTo(38.58, 0.01));
    });

    test('la cantidad va y vuelve sin desviarse', () {
      final vaso = porNombre('Jugo de fruta natural')!.aAlimento(cantidad: 250);
      expect(vaso.conCantidad(400).cantidad, closeTo(400, 0.001));
      expect(vaso.conCantidad(400).gramos, closeTo(420, 0.001));
    });

    test('corregir la porción no convierte el líquido en sólido', () {
      // Es lo que hace la pantalla de revisión al mover el deslizador: si la
      // copia perdiera la densidad, el vaso volvería a pedirse en gramos.
      final leche = porNombre('Leche entera')!
          .aAlimento(cantidad: 200)
          .conCantidad(300)
          .copiar(fuente: FuenteDatos.manual);

      expect(leche.esLiquido, isTrue);
      expect(leche.unidad, 'ml');
      expect(leche.cantidad, closeTo(300, 0.001));
      expect(leche.fuente, FuenteDatos.manual);
    });

    test('el aceite es líquido y menos denso que el agua', () {
      final aceite = porNombre('Aceite vegetal')!.aAlimento(cantidad: 10);
      expect(aceite.unidad, 'ml');
      expect(aceite.gramos, closeTo(9.2, 0.001));
    });

    test('la densidad sobrevive al guardado', () {
      // Los alimentos se congelan como jsonb dentro de la comida (ADR-0002).
      // Si la densidad no viajara, al reabrir el diario una gaseosa de 350 ml
      // se leería como 364 ml.
      final original = porNombre('Gaseosa')!.aAlimento(cantidad: 350);
      final ida = jsonDecode(jsonEncode(original.aJson()));
      final vuelta = Alimento.desdeJson(Map<String, dynamic>.from(ida as Map));

      expect(vuelta.densidad, original.densidad);
      expect(vuelta.cantidad, closeTo(350, 0.001));
      expect(vuelta.unidad, 'ml');
    });
  });

  group('cómo se escribe', () {
    test('cada alimento se muestra en su unidad', () {
      expect(Fmt.cantidad(350, 'ml'), '350 ml');
      expect(Fmt.cantidad(150, 'g'), '150 g');
    });

    test('los nutrientes siguen siendo gramos, también en una bebida', () {
      // El azúcar de un jugo se pesa en gramos aunque el jugo se sirva en
      // mililitros: la unidad de la porción no arrastra a la de los nutrientes.
      expect(Fmt.gramos(38.6), '39 g');
      expect(Fmt.miligramos(4), '4 mg');
    });
  });

  group('la tabla local', () {
    test('las bebidas están marcadas como líquidas y el resto no', () {
      final liquidos = catalogoLocal
          .where((a) => a.densidad > 0)
          .map((a) => a.nombre)
          .toSet();

      expect(liquidos, {
        'Aceite vegetal',
        'Café sin azúcar',
        'Gaseosa',
        'Jugo de fruta natural',
        'Leche entera',
      });
    });

    test('ninguna densidad se sale de lo físicamente posible', () {
      // Nada comestible baja de la grasa ni pasa de un jarabe.
      for (final a in catalogoLocal.where((a) => a.densidad > 0)) {
        expect(a.densidad, greaterThanOrEqualTo(0.9), reason: a.nombre);
        expect(a.densidad, lessThanOrEqualTo(1.4), reason: a.nombre);
      }
    });
  });
}
