import '../modelos/modelos.dart';
import 'calculos.dart';

/// Qué le falta al día para cerrar en la meta, y cuánto margen queda antes de
/// pasarse de los topes.
///
/// Es la pregunta que hay que contestar antes de sugerir nada: sin esto una
/// sugerencia es un consejo genérico de internet. Se calcula con lo ya comido,
/// no se le pregunta a nadie.
class HuecoDelDia {
  const HuecoDelDia({
    required this.kcal,
    required this.proteina,
    required this.carbohidratos,
    required this.grasa,
    required this.fibra,
    required this.azucarLibre,
    required this.saturadaLibre,
    required this.sodioLibre,
    required this.comidasPendientes,
  });

  /// Kcal que quedan para llegar a la meta. Negativo si ya se pasó.
  final double kcal;

  /// Gramos que faltan de cada macro. Nunca negativo: pasarse de proteína no
  /// crea un hueco, y un número negativo aquí solo confundiría a quien lo lee.
  final double proteina;
  final double carbohidratos;
  final double grasa;
  final double fibra;

  /// Margen que queda hasta el tope. Cero cuando ya se alcanzó.
  final double azucarLibre;
  final double saturadaLibre;
  final double sodioLibre;

  /// Las comidas del día que todavía no se han registrado. Sugerir un desayuno
  /// a las nueve de la noche no le sirve a nadie.
  final List<TipoComida> comidasPendientes;

  /// Si no queda hueco no hay nada que sugerir, y forzar una sugerencia sería
  /// empujar a comer de más.
  bool get hayHueco => kcal >= 100 && comidasPendientes.isNotEmpty;

  /// El hueco es tan grande que quedan varias comidas por delante.
  bool get esDiaCompleto => comidasPendientes.length >= 3;
}

/// Calcula el hueco a partir de la meta y de lo que ya se comió hoy.
///
/// [tiposRegistrados] son los tipos de comida que ya tienen registro; lo que
/// falta sale de restarlos al día completo.
HuecoDelDia huecoDelDia({
  required MetaDiaria meta,
  required Nutrientes comido,
  required Set<TipoComida> tiposRegistrados,
  DateTime? ahora,
}) {
  final hora = (ahora ?? DateTime.now()).hour;

  // Una comida cuenta como pasada si ya se registró o si su hora quedó atrás.
  // El snack no caduca: se puede picar a cualquier hora.
  final pendientes = [
    for (final t in TipoComida.values)
      if (!tiposRegistrados.contains(t) && !_yaPaso(t, hora)) t,
  ];

  double falta(double meta, double hecho) {
    final d = meta - hecho;
    return d > 0 ? d : 0;
  }

  return HuecoDelDia(
    kcal: meta.kcal - comido.kcal,
    proteina: falta(meta.proteina, comido.proteina),
    carbohidratos: falta(meta.carbohidratos, comido.carbohidratos),
    grasa: falta(meta.grasa, comido.grasa),
    fibra: falta(meta.fibra, comido.fibra),
    azucarLibre: falta(meta.azucarMax, comido.azucares),
    saturadaLibre: falta(meta.saturadaMax, comido.saturada),
    sodioLibre: falta(meta.sodioMax, comido.sodio),
    comidasPendientes: pendientes,
  );
}

bool _yaPaso(TipoComida t, int hora) => switch (t) {
  TipoComida.desayuno => hora >= 11,
  TipoComida.almuerzo => hora >= 16,
  TipoComida.cena => hora >= 23,
  TipoComida.snack => false,
};

/// Una propuesta de qué comer, antes de comprobar si encaja.
///
/// [porque] lo redacta el modelo; [alimento] trae los nutrientes con los que
/// se va a verificar. Las dos cosas llegan juntas y ninguna se cree sin más.
class Sugerencia {
  const Sugerencia({
    required this.alimento,
    required this.porque,
    this.comida = TipoComida.almuerzo,
  });

  final Alimento alimento;
  final String porque;
  final TipoComida comida;

  Nutrientes get aporta => alimento.total;
}

/// Por qué una sugerencia no se muestra. Se guarda en vez de descartarla en
/// silencio: si el modelo propone cinco cosas y se caen cuatro, eso es un dato
/// sobre el modelo, no un detalle de presentación.
enum MotivoRechazo {
  sinHueco('No queda margen en el día'),
  pasaKcal('Se pasa de las calorías que quedan'),
  pasaSodio('Se pasa del tope de sodio'),
  pasaAzucar('Se pasa del tope de azúcar'),
  pasaSaturada('Se pasa del tope de grasa saturada'),
  datosImposibles('Los nutrientes no son creíbles');

  const MotivoRechazo(this.etiqueta);
  final String etiqueta;
}

/// Una sugerencia ya contrastada contra el hueco real.
class SugerenciaEvaluada {
  const SugerenciaEvaluada(this.sugerencia, {this.rechazo});

  final Sugerencia sugerencia;
  final MotivoRechazo? rechazo;

  bool get aceptada => rechazo == null;
}

/// Contrasta lo que propuso el modelo con los topes reales de la persona.
///
/// Esta función es la razón por la que el botón puede existir sin romper el
/// ADR-0001: el modelo aporta variedad y redacción, pero lo que llega a la
/// pantalla ha pasado por los mismos umbrales que el resto de la app. Si
/// sugiere embutido a quien le queda medio gramo de sodio, se cae aquí.
List<SugerenciaEvaluada> evaluarSugerencias(
  List<Sugerencia> propuestas,
  HuecoDelDia hueco,
) {
  return [
    for (final s in propuestas)
      SugerenciaEvaluada(s, rechazo: _revisar(s, hueco)),
  ];
}

MotivoRechazo? _revisar(Sugerencia s, HuecoDelDia hueco) {
  final n = s.aporta;

  // Antes que nada, que los números sean de este mundo. Un alimento de 900
  // kcal por 100 g no existe: la grasa pura son 884.
  if (!_creible(s.alimento)) return MotivoRechazo.datosImposibles;

  if (!hueco.hayHueco) return MotivoRechazo.sinHueco;

  // Margen del 10% sobre lo que queda: clavar la meta al gramo no es el
  // objetivo, y rechazar una fruta por nueve kcal sería ruido.
  if (n.kcal > hueco.kcal * 1.1) return MotivoRechazo.pasaKcal;

  if (n.sodio > hueco.sodioLibre) return MotivoRechazo.pasaSodio;
  if (n.azucares > hueco.azucarLibre) return MotivoRechazo.pasaAzucar;
  if (n.saturada > hueco.saturadaLibre) return MotivoRechazo.pasaSaturada;

  return null;
}

/// Límites físicos, no nutricionales: descartan un alimento inventado.
bool _creible(Alimento a) {
  final p = a.por100g;
  if (a.gramos <= 0 || a.gramos > 2000) return false;
  if (p.kcal < 0 || p.kcal > 900) return false;
  if (p.proteina < 0 || p.proteina > 100) return false;
  if (p.carbohidratos < 0 || p.carbohidratos > 100) return false;
  if (p.grasa < 0 || p.grasa > 100) return false;
  if (p.sodio < 0 || p.sodio > 50000) return false;
  // Los azúcares son parte de los carbohidratos y la saturada parte de la
  // grasa: si los superan, la ficha está mal.
  if (p.azucares > p.carbohidratos + 0.5) return false;
  if (p.saturada > p.grasa + 0.5) return false;
  return true;
}

/// Resultado completo de una tanda de sugerencias, listo para la pantalla.
class Sugerencias {
  const Sugerencias({
    required this.evaluadas,
    required this.hueco,
    this.nota = '',
  });

  final List<SugerenciaEvaluada> evaluadas;
  final HuecoDelDia hueco;

  /// Texto libre del modelo sobre el conjunto. Puede venir vacío.
  final String nota;

  List<Sugerencia> get aceptadas => [
    for (final e in evaluadas)
      if (e.aceptada) e.sugerencia,
  ];

  List<SugerenciaEvaluada> get descartadas => [
    for (final e in evaluadas)
      if (!e.aceptada) e,
  ];

  bool get vacio => aceptadas.isEmpty;
}
