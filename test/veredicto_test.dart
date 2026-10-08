import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plato/datos/modelos/modelos.dart';
import 'package:mi_plato/datos/nutricion/calculos.dart';
import 'package:mi_plato/datos/nutricion/tabla_local.dart';
import 'package:mi_plato/datos/nutricion/veredicto.dart';

/// Los pros y los contras son la razón de ser de la app. Aquí se comprueba que
/// cada frase aparece cuando le toca y no antes.
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

  Comida comidaCon(
    List<(String, double)> partes, {
    TipoComida tipo = TipoComida.almuerzo,
    double confianza = 1,
  }) => Comida(
    id: 'c1',
    perfilId: 'p1',
    fecha: DateTime(2026, 8, 31, 13),
    tipo: tipo,
    // Por el mismo camino que la app: así las cantidades de una bebida se
    // leen en mililitros y la densidad entra en la cuenta.
    alimentos: [
      for (final (nombre, cantidad) in partes)
        porNombre(
          nombre,
        )!.aAlimento(cantidad: cantidad).copiar(confianza: confianza),
    ],
  );

  bool tiene(Veredicto v, Severidad nivel, String fragmento) => v.puntos.any(
    (p) => p.nivel == nivel && p.texto.toLowerCase().contains(fragmento),
  );

  group('comida suelta', () {
    test('sin alimentos no inventa veredicto', () {
      final v = evaluarComida(
        comida: comidaCon(const []),
        perfil: jorge,
        meta: metaDiaria(jorge),
      );
      expect(v.puntos, isEmpty);
    });

    test('un almuerzo equilibrado sale a favor', () {
      final v = evaluarComida(
        comida: comidaCon([
          ('Arroz blanco cocido', 150),
          ('Pechuga de pollo a la plancha', 120),
          ('Ensalada de lechuga y tomate', 100),
        ]),
        perfil: jorge,
        meta: metaDiaria(jorge),
      );
      expect(tiene(v, Severidad.bueno, 'encaja'), isTrue);
      expect(tiene(v, Severidad.bueno, 'proteína'), isTrue);
      expect(v.nivel, Severidad.bueno);
    });

    test('marca el sodio alto de un embutido', () {
      final v = evaluarComida(
        comida: comidaCon([('Salchicha', 200)]),
        perfil: jorge,
        meta: metaDiaria(jorge),
      );
      expect(tiene(v, Severidad.malo, 'sodio'), isTrue);
      expect(tiene(v, Severidad.malo, 'saturada'), isTrue);
    });

    test('marca el azúcar de un refresco grande', () {
      final v = evaluarComida(
        comida: comidaCon([('Gaseosa', 600)], tipo: TipoComida.snack),
        perfil: jorge,
        meta: metaDiaria(jorge),
      );
      expect(tiene(v, Severidad.malo, 'azúcar'), isTrue);
    });

    test('avisa cuando la comida se pasa de la meta que queda', () {
      final meta = metaDiaria(jorge);
      final v = evaluarComida(
        comida: comidaCon([('Arroz blanco cocido', 300)]),
        perfil: jorge,
        meta: meta,
        // Ya se comió casi toda la meta del día.
        yaConsumido: Nutrientes(kcal: meta.kcal - 100),
      );
      expect(tiene(v, Severidad.malo, 'pasas tu meta'), isTrue);
      expect(v.resumen, contains('por encima'));
    });

    test('la densidad calórica se lee al revés según el IMC', () {
      final plato = comidaCon([('Papas fritas de bolsa', 100)]);

      final conSobrepeso = evaluarComida(
        comida: plato,
        perfil: jorge,
        meta: metaDiaria(jorge),
      );
      expect(tiene(conSobrepeso, Severidad.aviso, 'denso'), isTrue);

      // Mismo plato, persona por debajo del rango saludable: ahí suma.
      final delgado = jorge.copiar(pesoKg: 50);
      expect(categoriaImc(imc(50, 172)), CategoriaImc.bajoPeso);
      final conBajoPeso = evaluarComida(
        comida: plato,
        perfil: delgado,
        meta: metaDiaria(delgado),
      );
      expect(tiene(conBajoPeso, Severidad.bueno, 'denso'), isTrue);
    });

    test('una lectura dudosa se advierte', () {
      final v = evaluarComida(
        comida: comidaCon([('Arroz blanco cocido', 150)], confianza: 0.3),
        perfil: jorge,
        meta: metaDiaria(jorge),
      );
      expect(tiene(v, Severidad.aviso, 'reconocimiento'), isTrue);
    });
  });

  group('día completo', () {
    test('sin comidas no juzga nada', () {
      final v = evaluarDia(
        comidas: const [],
        perfil: jorge,
        meta: metaDiaria(jorge),
      );
      expect(v.puntos, isEmpty);
      expect(v.resumen, contains('Aún no'));
    });

    test('detecta el día por encima de la meta', () {
      final v = evaluarDia(
        comidas: [
          comidaCon([('Pizza', 500)]),
          comidaCon([('Hamburguesa', 400)]),
          comidaCon([('Papas fritas', 300)]),
        ],
        perfil: jorge,
        meta: metaDiaria(jorge),
      );
      expect(tiene(v, Severidad.malo, 'pasaste tu meta'), isTrue);
    });

    test('avisa del día muy por debajo', () {
      final v = evaluarDia(
        comidas: [
          comidaCon([('Manzana', 150)]),
        ],
        perfil: jorge,
        meta: metaDiaria(jorge),
      );
      expect(tiene(v, Severidad.aviso, 'corto'), isTrue);
    });
  });

  group('lecturas del perfil', () {
    test('el IMC se explica con el rango de la altura', () {
      final l = lecturaImc(jorge);
      expect(l.titulo, contains('Sobrepeso'));
      expect(l.nivel, Severidad.aviso);
      expect(l.detalle, contains('por encima'));
    });

    test('sin dos semanas de pesajes no hay ritmo real', () {
      final base = DateTime(2026, 8, 1);
      expect(ritmoRealSemanal(const []), isNull);
      expect(
        ritmoRealSemanal([
          RegistroPeso(id: '1', perfilId: 'p1', fecha: base, pesoKg: 85),
          RegistroPeso(
            id: '2',
            perfilId: 'p1',
            fecha: base.add(const Duration(days: 3)),
            pesoKg: 84,
          ),
        ]),
        isNull,
      );
    });

    test('con dos semanas devuelve kilos por semana', () {
      final base = DateTime(2026, 8, 1);
      final ritmo = ritmoRealSemanal([
        RegistroPeso(id: '1', perfilId: 'p1', fecha: base, pesoKg: 85),
        RegistroPeso(
          id: '2',
          perfilId: 'p1',
          fecha: base.add(const Duration(days: 14)),
          pesoKg: 84,
        ),
      ]);
      expect(ritmo, closeTo(-0.5, 0.001));
    });

    test('estima las semanas hasta el rango saludable', () {
      final semanas = semanasHastaRangoSaludable(jorge, metaDiaria(jorge));
      // Sobran ~11 kg y el ritmo ronda 0.5 kg/semana.
      expect(semanas, isNotNull);
      expect(semanas, inInclusiveRange(15, 40));
    });

    test('dentro del rango no hay cuenta atrás', () {
      final sano = jorge.copiar(pesoKg: 70);
      expect(semanasHastaRangoSaludable(sano, metaDiaria(sano)), isNull);
    });
  });
}
