import 'dart:math' as math;

import '../modelos/modelos.dart';

/// Cálculo del IMC, del gasto energético y de la meta diaria.
///
/// Todo aquí es Dart puro y determinista: el modelo de visión solo dice *qué*
/// hay en el plato y *cuánto* pesa; los números que se le enseñan a la persona
/// salen de estas fórmulas, no de lo que el modelo quiera opinar. Así el
/// consejo es reproducible y se puede probar con tests.
///
/// Fuentes de los umbrales:
///  - IMC: clasificación de la OMS para personas adultas.
///  - Gasto: Mifflin-St Jeor (1990), la ecuación que la Academy of Nutrition
///    and Dietetics recomienda por delante de Harris-Benedict.
///  - Límites de azúcar libre, grasa saturada y sodio: guías OMS.
///  - Fibra: 14 g por cada 1000 kcal (Dietary Guidelines for Americans).

const kcalPorGramoProteina = 4.0;
const kcalPorGramoCarbohidrato = 4.0;
const kcalPorGramoGrasa = 9.0;

/// Energía de un kilo de tejido graso. Es la constante que traduce un déficit
/// diario en kilos por semana.
const kcalPorKiloDeGrasa = 7700.0;

enum CategoriaImc {
  bajoPeso('Bajo peso'),
  normal('Peso normal'),
  sobrepeso('Sobrepeso'),
  obesidad1('Obesidad grado I'),
  obesidad2('Obesidad grado II'),
  obesidad3('Obesidad grado III');

  const CategoriaImc(this.etiqueta);
  final String etiqueta;

  bool get esSaludable => this == CategoriaImc.normal;
}

/// IMC = peso (kg) / altura (m)². Devuelve 0 si la altura no es válida, para
/// que una pantalla a medio llenar no reviente con una división por cero.
double imc(double pesoKg, double alturaCm) {
  if (alturaCm <= 0 || pesoKg <= 0) return 0;
  final m = alturaCm / 100;
  return pesoKg / (m * m);
}

CategoriaImc categoriaImc(double valor) {
  if (valor < 18.5) return CategoriaImc.bajoPeso;
  if (valor < 25) return CategoriaImc.normal;
  if (valor < 30) return CategoriaImc.sobrepeso;
  if (valor < 35) return CategoriaImc.obesidad1;
  if (valor < 40) return CategoriaImc.obesidad2;
  return CategoriaImc.obesidad3;
}

/// Rango de peso que deja el IMC entre 18.5 y 24.9 para esa altura.
({double min, double max}) rangoPesoSaludable(double alturaCm) {
  final m = alturaCm / 100;
  return (min: 18.5 * m * m, max: 24.9 * m * m);
}

/// Tasa metabólica basal por Mifflin-St Jeor: las calorías que gasta el cuerpo
/// en reposo absoluto.
double tmb(Perfil p) {
  final base = 10 * p.pesoKg + 6.25 * p.alturaCm - 5 * p.edad;
  return p.sexo == Sexo.masculino ? base + 5 : base - 161;
}

/// Gasto energético total: la basal multiplicada por el nivel de actividad.
double gastoDiario(Perfil p) => tmb(p) * p.actividad.factor;

/// Meta de un día completo, ya ajustada al objetivo y a las condiciones que la
/// persona declaró en su perfil.
class MetaDiaria {
  const MetaDiaria({
    required this.kcal,
    required this.proteina,
    required this.carbohidratos,
    required this.grasa,
    required this.fibra,
    required this.azucarMax,
    required this.saturadaMax,
    required this.sodioMax,
    required this.tmb,
    required this.gasto,
  });

  final double kcal;
  final double proteina;
  final double carbohidratos;
  final double grasa;

  /// Mínimo recomendado, no un techo: la fibra es de los pocos objetivos que
  /// conviene superar.
  final double fibra;

  final double azucarMax;
  final double saturadaMax;
  final double sodioMax;

  final double tmb;
  final double gasto;

  /// Positivo en déficit (se come menos de lo que se gasta), negativo en
  /// superávit.
  double get deficit => gasto - kcal;

  /// Kilos por semana que implica el déficit actual, si se cumple. Es una
  /// estimación: el cuerpo se adapta y el gasto real baja con el peso.
  double get ritmoSemanalKg => deficit * 7 / kcalPorKiloDeGrasa;
}

/// Peso que se usa para dosificar la proteína. Con obesidad, calcularla sobre
/// el peso real dispara la cifra a algo imposible de comer, así que se topa en
/// el límite alto del rango saludable.
double _pesoDeReferencia(Perfil p) {
  final rango = rangoPesoSaludable(p.alturaCm);
  return math.min(p.pesoKg, rango.max);
}

/// Suelo calórico. Por debajo de esto una dieta deja de cubrir micronutrientes
/// y necesita seguimiento clínico, así que la app nunca propone menos.
double _sueloCalorico(Sexo sexo) => sexo == Sexo.masculino ? 1500 : 1200;

MetaDiaria metaDiaria(Perfil p) {
  final basal = tmb(p);
  final gasto = basal * p.actividad.factor;

  final objetivoKcal = switch (p.objetivo) {
    // Déficit del 20%: agresivo pero sostenible. Más que eso cuesta masa
    // muscular y casi nadie lo aguanta más de unas semanas.
    Objetivo.bajarPeso => gasto * 0.80,
    Objetivo.mantener => gasto,
    // Superávit del 10%: lo justo para construir músculo sin engordar de más.
    Objetivo.subirMasa => gasto * 1.10,
  };

  final kcal = math.max(objetivoKcal, _sueloCalorico(p.sexo));

  final gPorKilo = switch (p.objetivo) {
    Objetivo.bajarPeso => 1.6, // protege la masa magra durante el déficit
    Objetivo.mantener => 1.2,
    Objetivo.subirMasa => 1.8,
  };
  final proteina = _pesoDeReferencia(p) * gPorKilo;

  // 27% de la energía en grasa: dentro del 20-35% que recomiendan las guías.
  final grasa = kcal * 0.27 / kcalPorGramoGrasa;

  // Lo que sobra tras cubrir proteína y grasa va a carbohidratos.
  final kcalRestantes =
      kcal - proteina * kcalPorGramoProteina - grasa * kcalPorGramoGrasa;
  final carbohidratos = math.max(0.0, kcalRestantes) / kcalPorGramoCarbohidrato;

  final tieneDiabetes = p.condiciones.contains(Condicion.diabetes);
  final tieneColesterol = p.condiciones.contains(Condicion.colesterolAlto);
  final tieneHipertension = p.condiciones.contains(Condicion.hipertension);

  return MetaDiaria(
    kcal: kcal,
    proteina: proteina,
    carbohidratos: carbohidratos,
    grasa: grasa,
    fibra: 14 * kcal / 1000,
    // La OMS pone el techo en el 10% de la energía y sugiere bajar al 5%.
    azucarMax: kcal * (tieneDiabetes ? 0.05 : 0.10) / kcalPorGramoCarbohidrato,
    saturadaMax: kcal * (tieneColesterol ? 0.07 : 0.10) / kcalPorGramoGrasa,
    sodioMax: tieneHipertension ? 1500 : 2000,
    tmb: basal,
    gasto: gasto,
  );
}
