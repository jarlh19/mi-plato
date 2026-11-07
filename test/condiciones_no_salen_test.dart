import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plato/datos/modelos/modelos.dart';
import 'package:mi_plato/datos/nutricion/calculos.dart';
import 'package:mi_plato/datos/nutricion/sugerencias.dart';

/// Las condiciones de salud (diabetes, hipertensión…) son datos sensibles: la
/// Ley 29733 pide consentimiento expreso para mandarlas a un tercero. No hace
/// falta pedirlo porque no se mandan (ADR-0007): el pedido de sugerencias
/// lleva el hueco del día, cuyos topes ya vienen ajustados por esas
/// condiciones, y las reglas locales descartan lo que se pase.
void main() {
  Perfil ana(Set<Condicion> condiciones) => Perfil(
    id: 'p1',
    nombre: 'Ana',
    edad: 52,
    pesoKg: 70,
    objetivo: Objetivo.mantener,
    condiciones: condiciones,
    perfilCompleto: true,
  );

  Map<String, Object> pedidoPara(Set<Condicion> condiciones) {
    final perfil = ana(condiciones);
    final hueco = huecoDelDia(
      meta: metaDiaria(perfil),
      comido: const Nutrientes(kcal: 800, sodio: 500, azucares: 10),
      tiposRegistrados: {TipoComida.desayuno},
      ahora: DateTime(2026, 11, 6, 12),
    );
    return pedidoDeSugerencias(objetivo: perfil.objetivo, hueco: hueco);
  }

  test(
    'el pedido lleva el objetivo, el hueco y las comidas que faltan; nada más',
    () {
      final pedido = pedidoPara({Condicion.hipertension, Condicion.diabetes});
      expect(pedido.keys.toSet(), {'objetivo', 'hueco', 'comidas_pendientes'});
      final texto = pedido.toString().toLowerCase();
      for (final c in Condicion.values) {
        expect(
          texto,
          isNot(contains(c.name.toLowerCase())),
          reason: 'no nombra ${c.name}',
        );
      }
    },
  );

  test(
    'el efecto de las condiciones sí llega: los topes del hueco son más estrictos',
    () {
      final sano = pedidoPara({})['hueco']! as Map<String, Object>;
      final conCondiciones =
          pedidoPara({Condicion.hipertension, Condicion.diabetes})['hueco']!
              as Map<String, Object>;
      expect(
        conCondiciones['sodio_libre'] as int,
        lessThan(sano['sodio_libre'] as int),
      );
      expect(
        conCondiciones['azucar_libre'] as int,
        lessThan(sano['azucar_libre'] as int),
      );
    },
  );

  test('la app usa ese pedido y la Edge Function ya no lee condiciones', () {
    final repo = File('lib/datos/repos/supabase_repos.dart').readAsStringSync();
    final funcion = File(
      'supabase/functions/sugerir-comidas/index.ts',
    ).readAsStringSync();
    expect(repo, contains('pedidoDeSugerencias('));
    expect(repo, isNot(contains("'condiciones':")));
    expect(funcion, isNot(matches(RegExp(r'cuerpo\??\.condiciones'))));
  });
}
