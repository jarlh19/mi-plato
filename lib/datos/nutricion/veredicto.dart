import 'dart:math' as math;

import '../../core/formato.dart';
import '../modelos/modelos.dart';
import 'calculos.dart';

/// Traduce los macronutrientes de una comida en frases a favor y en contra,
/// contrastadas con el IMC y el objetivo de la persona.
///
/// Deliberadamente no interviene aquí ningún modelo de lenguaje. El modelo de
/// visión ya hizo su trabajo (reconocer el plato); a partir de ahí las reglas
/// son fijas y auditables, de modo que dos platos iguales reciben siempre el
/// mismo consejo y cada frase se puede rastrear hasta un umbral concreto.

enum Severidad { bueno, aviso, malo }

class Punto {
  const Punto(this.nivel, this.texto, {this.detalle = ''});

  final Severidad nivel;

  /// Frase corta: "Buena carga de proteína: 34 g".
  final String texto;

  /// Por qué importa, en una línea. Vacío si la frase se explica sola.
  final String detalle;
}

class Veredicto {
  const Veredicto(this.resumen, this.puntos);

  /// Una línea de cabecera: "Te quedan 780 kcal para hoy".
  final String resumen;

  final List<Punto> puntos;

  List<Punto> get pros =>
      puntos.where((p) => p.nivel == Severidad.bueno).toList();

  List<Punto> get contras =>
      puntos.where((p) => p.nivel != Severidad.bueno).toList();

  /// La peor severidad presente: da el color de la cabecera.
  Severidad get nivel {
    if (puntos.any((p) => p.nivel == Severidad.malo)) return Severidad.malo;
    if (puntos.any((p) => p.nivel == Severidad.aviso)) return Severidad.aviso;
    return Severidad.bueno;
  }
}

/// Evalúa una comida concreta.
///
/// [yaConsumido] es la suma del resto del día *sin* contar esta comida, para
/// poder decir cuánto margen queda después de comerla.
Veredicto evaluarComida({
  required Comida comida,
  required Perfil perfil,
  required MetaDiaria meta,
  Nutrientes yaConsumido = Nutrientes.cero,
}) {
  final t = comida.total;
  if (comida.alimentos.isEmpty) {
    return const Veredicto('Sin alimentos reconocidos', []);
  }

  final puntos = <Punto>[];
  final categoria = categoriaImc(imc(perfil.pesoKg, perfil.alturaCm));

  // --- Energía ------------------------------------------------------------
  // Se compara con lo que se espera de *esta* comida, no con el día entero:
  // un almuerzo de 700 kcal no es un exceso, es un almuerzo.
  final esperado = meta.kcal * comida.tipo.porcionDelDia;
  final razon = esperado > 0 ? t.kcal / esperado : 0.0;
  final restante = meta.kcal - yaConsumido.kcal - t.kcal;

  if (restante < 0) {
    puntos.add(
      Punto(
        Severidad.malo,
        'Con esta comida pasas tu meta del día en ${Fmt.kcal(-restante)}',
        detalle: 'Tu meta diaria es ${Fmt.kcal(meta.kcal)}.',
      ),
    );
  } else if (razon > 1.4) {
    puntos.add(
      Punto(
        Severidad.malo,
        'Pesado para un ${comida.tipo.etiqueta.toLowerCase()}: '
        '${Fmt.kcal(t.kcal)} frente a las ${Fmt.kcal(esperado)} previstas',
        detalle: 'Te quedan ${Fmt.kcal(restante)} para el resto del día.',
      ),
    );
  } else if (razon > 1.15) {
    puntos.add(
      Punto(
        Severidad.aviso,
        'Algo por encima de lo previsto: ${Fmt.kcal(t.kcal)} de '
        '${Fmt.kcal(esperado)}',
        detalle: 'Recuperable si aligeras la siguiente comida.',
      ),
    );
  } else if (razon < 0.5 && comida.tipo != TipoComida.snack) {
    puntos.add(
      Punto(
        categoria == CategoriaImc.bajoPeso ? Severidad.malo : Severidad.aviso,
        'Muy ligero para un ${comida.tipo.etiqueta.toLowerCase()}: '
        'solo ${Fmt.kcal(t.kcal)}',
        detalle: 'Comer de menos ahora suele acabar en picoteo después.',
      ),
    );
  } else {
    puntos.add(
      Punto(
        Severidad.bueno,
        'Encaja en tu ${comida.tipo.etiqueta.toLowerCase()}: '
        '${Fmt.kcal(t.kcal)} de ${Fmt.kcal(esperado)}',
      ),
    );
  }

  // --- Proteína -----------------------------------------------------------
  final fracProteina = meta.proteina > 0 ? t.proteina / meta.proteina : 0.0;
  if (fracProteina >= 0.25) {
    puntos.add(
      Punto(
        Severidad.bueno,
        'Buena carga de proteína: ${Fmt.gramos(t.proteina)}, '
        '${Fmt.porcentaje(fracProteina)} de tu día',
        detalle: perfil.objetivo == Objetivo.bajarPeso
            ? 'Sacia y protege tu masa muscular mientras bajas de peso.'
            : 'Es lo que usa el cuerpo para construir músculo.',
      ),
    );
  } else if (fracProteina < 0.10 && comida.tipo != TipoComida.snack) {
    puntos.add(
      Punto(
        Severidad.aviso,
        'Poca proteína: ${Fmt.gramos(t.proteina)}',
        detalle:
            'Tu meta del día son ${Fmt.gramos(meta.proteina)}; '
            'con este ritmo no llegas.',
      ),
    );
  }

  // --- Fibra --------------------------------------------------------------
  final fracFibra = meta.fibra > 0 ? t.fibra / meta.fibra : 0.0;
  if (fracFibra >= 0.25) {
    puntos.add(
      Punto(
        Severidad.bueno,
        'Aporta fibra: ${Fmt.gramos(t.fibra)}',
        detalle: 'Alarga la saciedad y ayuda al control de la glucosa.',
      ),
    );
  } else if (t.fibra < 2 && comida.tipo != TipoComida.snack) {
    puntos.add(
      Punto(
        Severidad.aviso,
        'Casi sin fibra: ${Fmt.gramos(t.fibra)}',
        detalle: 'Una verdura o una fruta en el plato lo arregla.',
      ),
    );
  }

  // --- Sodio, azúcar y grasa saturada -------------------------------------
  // Son techos diarios: lo que se mira es cuánto del techo se gasta de una vez.
  final fracSodio = meta.sodioMax > 0 ? t.sodio / meta.sodioMax : 0.0;
  if (fracSodio > 0.5) {
    puntos.add(
      Punto(
        Severidad.malo,
        'Sodio alto: ${Fmt.miligramos(t.sodio)}, '
        '${Fmt.porcentaje(fracSodio)} de tu tope del día',
        detalle: perfil.condiciones.contains(Condicion.hipertension)
            ? 'Con hipertensión tu tope es más bajo (1500 mg).'
            : 'La OMS recomienda no pasar de 2000 mg al día.',
      ),
    );
  } else if (fracSodio > 0.33) {
    puntos.add(
      Punto(
        Severidad.aviso,
        'Sodio a vigilar: ${Fmt.miligramos(t.sodio)}',
        detalle: 'Ya vas por ${Fmt.porcentaje(fracSodio)} del tope diario.',
      ),
    );
  }

  final fracAzucar = meta.azucarMax > 0 ? t.azucares / meta.azucarMax : 0.0;
  if (fracAzucar > 0.5) {
    puntos.add(
      Punto(
        Severidad.malo,
        'Mucho azúcar: ${Fmt.gramos(t.azucares)}, '
        '${Fmt.porcentaje(fracAzucar)} de tu tope',
        detalle: perfil.condiciones.contains(Condicion.diabetes)
            ? 'Con diabetes tu tope está en el 5% de las calorías.'
            : 'Sube rápido y deja con hambre al poco rato.',
      ),
    );
  } else if (fracAzucar > 0.33) {
    puntos.add(
      Punto(
        Severidad.aviso,
        'Azúcar a tener en cuenta: ${Fmt.gramos(t.azucares)}',
        detalle: 'Parte puede venir de la fruta entera, que preocupa menos.',
      ),
    );
  }

  final fracSaturada = meta.saturadaMax > 0
      ? t.saturada / meta.saturadaMax
      : 0.0;
  if (fracSaturada > 0.5) {
    puntos.add(
      Punto(
        Severidad.malo,
        'Grasa saturada alta: ${Fmt.gramos(t.saturada)}, '
        '${Fmt.porcentaje(fracSaturada)} de tu tope',
        detalle: perfil.condiciones.contains(Condicion.colesterolAlto)
            ? 'Con colesterol alto conviene quedarse por debajo del 7%.'
            : 'Frituras, embutidos y lácteos enteros son la fuente habitual.',
      ),
    );
  } else if (fracSaturada > 0.35) {
    puntos.add(
      Punto(
        Severidad.aviso,
        'Grasa saturada a vigilar: ${Fmt.gramos(t.saturada)}',
      ),
    );
  }

  // --- Densidad calórica --------------------------------------------------
  // El mismo plato se lee al revés según el IMC: lo que estorba a quien quiere
  // bajar de peso es justo lo que ayuda a quien está por debajo del rango.
  if (comida.gramosTotales > 0) {
    final densidad = t.kcal / comida.gramosTotales * 100;
    if (densidad > 250) {
      puntos.add(
        Punto(
          categoria == CategoriaImc.bajoPeso
              ? Severidad.bueno
              : Severidad.aviso,
          'Plato denso: ${densidad.round()} kcal por cada 100 g',
          detalle: categoria == CategoriaImc.bajoPeso
              ? 'Te conviene: suma calorías sin tener que comer mucho volumen.'
              : 'Mucha energía en poco volumen; llena menos de lo que suma.',
        ),
      );
    } else if (densidad < 120 && perfil.objetivo == Objetivo.bajarPeso) {
      puntos.add(
        Punto(
          Severidad.bueno,
          'Poco denso: ${densidad.round()} kcal por 100 g',
          detalle: 'Llena el plato sin gastarte el presupuesto del día.',
        ),
      );
    }
  }

  // --- Fiabilidad de la lectura -------------------------------------------
  if (comida.confianza < 0.6) {
    puntos.add(
      const Punto(
        Severidad.aviso,
        'El reconocimiento de la foto no fue claro',
        detalle: 'Revisa los alimentos y ajusta los gramos antes de guardar.',
      ),
    );
  }

  final resumen = restante >= 0
      ? 'Te quedan ${Fmt.kcal(restante)} para hoy'
      : 'Vas ${Fmt.kcal(-restante)} por encima de tu meta de hoy';

  return Veredicto(resumen, puntos);
}

/// Evalúa el día completo. Es un juicio distinto al de una comida suelta:
/// aquí sí se comparan los totales con la meta entera.
Veredicto evaluarDia({
  required List<Comida> comidas,
  required Perfil perfil,
  required MetaDiaria meta,
}) {
  if (comidas.isEmpty) {
    return const Veredicto('Aún no has registrado nada hoy', []);
  }

  final t = comidas.fold(Nutrientes.cero, (acc, c) => acc + c.total);
  final puntos = <Punto>[];
  final restante = meta.kcal - t.kcal;
  final fraccion = meta.kcal > 0 ? t.kcal / meta.kcal : 0.0;

  if (fraccion > 1.10) {
    puntos.add(
      Punto(
        Severidad.malo,
        'Pasaste tu meta en ${Fmt.kcal(-restante)}',
        detalle: perfil.objetivo == Objetivo.bajarPeso
            ? 'Un día suelto no rompe nada; lo que cuenta es la media semanal.'
            : 'Revisa si el objetivo de calorías se te quedó corto.',
      ),
    );
  } else if (fraccion < 0.75) {
    puntos.add(
      Punto(
        Severidad.aviso,
        'Te quedaste corto: ${Fmt.kcal(t.kcal)} de ${Fmt.kcal(meta.kcal)}',
        detalle:
            'Comer muy por debajo baja el metabolismo y cuesta sostenerlo.',
      ),
    );
  } else {
    puntos.add(
      Punto(
        Severidad.bueno,
        'Día en meta: ${Fmt.kcal(t.kcal)} de ${Fmt.kcal(meta.kcal)}',
      ),
    );
  }

  final fracProteina = meta.proteina > 0 ? t.proteina / meta.proteina : 0.0;
  puntos.add(
    fracProteina >= 0.9
        ? Punto(Severidad.bueno, 'Proteína cubierta: ${Fmt.gramos(t.proteina)}')
        : Punto(
            fracProteina < 0.6 ? Severidad.malo : Severidad.aviso,
            'Proteína por debajo: ${Fmt.gramos(t.proteina)} de '
            '${Fmt.gramos(meta.proteina)}',
            detalle: perfil.objetivo == Objetivo.bajarPeso
                ? 'En déficit, la proteína baja se paga en masa muscular.'
                : 'Sin proteína suficiente no hay construcción de músculo.',
          ),
  );

  if (t.fibra >= meta.fibra) {
    puntos.add(
      Punto(Severidad.bueno, 'Fibra cubierta: ${Fmt.gramos(t.fibra)}'),
    );
  } else if (t.fibra < meta.fibra * 0.5) {
    puntos.add(
      Punto(
        Severidad.aviso,
        'Poca fibra: ${Fmt.gramos(t.fibra)} de ${Fmt.gramos(meta.fibra)}',
      ),
    );
  }

  if (t.sodio > meta.sodioMax) {
    puntos.add(
      Punto(
        Severidad.malo,
        'Sodio por encima del tope: ${Fmt.miligramos(t.sodio)}',
        detalle: 'Tope del día: ${Fmt.miligramos(meta.sodioMax)}.',
      ),
    );
  }
  if (t.azucares > meta.azucarMax) {
    puntos.add(
      Punto(
        Severidad.malo,
        'Azúcar por encima del tope: ${Fmt.gramos(t.azucares)}',
        detalle: 'Tope del día: ${Fmt.gramos(meta.azucarMax)}.',
      ),
    );
  }
  if (t.saturada > meta.saturadaMax) {
    puntos.add(
      Punto(
        Severidad.malo,
        'Grasa saturada por encima del tope: ${Fmt.gramos(t.saturada)}',
        detalle: 'Tope del día: ${Fmt.gramos(meta.saturadaMax)}.',
      ),
    );
  }

  final resumen = restante >= 0
      ? 'Te quedan ${Fmt.kcal(restante)} para hoy'
      : 'Vas ${Fmt.kcal(-restante)} por encima de tu meta de hoy';

  return Veredicto(resumen, puntos);
}

/// Lectura del IMC en una frase, con el rango de peso que le correspondería.
({String titulo, String detalle, Severidad nivel}) lecturaImc(Perfil p) {
  final valor = imc(p.pesoKg, p.alturaCm);
  final cat = categoriaImc(valor);
  final rango = rangoPesoSaludable(p.alturaCm);

  final nivel = switch (cat) {
    CategoriaImc.normal => Severidad.bueno,
    CategoriaImc.bajoPeso || CategoriaImc.sobrepeso => Severidad.aviso,
    _ => Severidad.malo,
  };

  final detalle = cat.esSaludable
      ? 'Para tu altura, el rango saludable va de '
            '${Fmt.peso(rango.min)} a ${Fmt.peso(rango.max)}.'
      : cat == CategoriaImc.bajoPeso
      ? 'Te faltan ${Fmt.peso(rango.min - p.pesoKg)} para entrar en el '
            'rango saludable de tu altura.'
      : 'Estás ${Fmt.peso(p.pesoKg - rango.max)} por encima del rango '
            'saludable de tu altura.';

  return (
    titulo: '${Fmt.imc(valor)} · ${cat.etiqueta}',
    detalle: detalle,
    nivel: nivel,
  );
}

/// Ritmo real de cambio de peso a partir del historial, en kg por semana.
/// Devuelve `null` cuando no hay dos pesajes separados por al menos una semana:
/// antes de eso la báscula solo mide agua.
double? ritmoRealSemanal(List<RegistroPeso> pesos) {
  if (pesos.length < 2) return null;
  final orden = [...pesos]..sort((a, b) => a.fecha.compareTo(b.fecha));
  final primero = orden.first;
  final ultimo = orden.last;
  final dias = ultimo.fecha.difference(primero.fecha).inDays;
  if (dias < 7) return null;
  return (ultimo.pesoKg - primero.pesoKg) / dias * 7;
}

/// Semanas estimadas hasta entrar en el rango saludable de IMC, con el ritmo
/// que marca la meta. `null` si ya está dentro o si el objetivo no lleva allí.
int? semanasHastaRangoSaludable(Perfil p, MetaDiaria meta) {
  final rango = rangoPesoSaludable(p.alturaCm);
  final ritmo = meta.ritmoSemanalKg;
  if (p.pesoKg > rango.max && ritmo > 0.05) {
    return math.max(1, ((p.pesoKg - rango.max) / ritmo).ceil());
  }
  if (p.pesoKg < rango.min && ritmo < -0.05) {
    return math.max(1, ((rango.min - p.pesoKg) / -ritmo).ceil());
  }
  return null;
}
