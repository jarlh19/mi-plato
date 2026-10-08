// Modelos de dominio de la app.
// Todos se serializan a/desde el JSON que devuelve Supabase (snake_case).

import '../../core/formato.dart';

enum Sexo { femenino, masculino }

Sexo sexoDesde(String? v) => v == 'masculino' ? Sexo.masculino : Sexo.femenino;

/// Multiplicadores del gasto energético sobre la tasa metabólica basal.
/// Valores clásicos de Harris-Benedict, los mismos que usan las guías de la
/// FAO/OMS para estimar el gasto total.
enum NivelActividad {
  sedentario(1.2, 'Sedentario', 'Trabajo de oficina, casi sin ejercicio'),
  ligero(1.375, 'Ligero', 'Camino o entreno 1-3 días por semana'),
  moderado(1.55, 'Moderado', 'Entreno 3-5 días por semana'),
  alto(1.725, 'Alto', 'Entreno 6-7 días por semana'),
  muyAlto(1.9, 'Muy alto', 'Trabajo físico o doble sesión diaria');

  const NivelActividad(this.factor, this.etiqueta, this.detalle);
  final double factor;
  final String etiqueta;
  final String detalle;
}

NivelActividad actividadDesde(String? v) => NivelActividad.values.firstWhere(
  (n) => n.name == v,
  orElse: () => NivelActividad.ligero,
);

enum Objetivo {
  bajarPeso('Bajar peso'),
  mantener('Mantener'),
  subirMasa('Subir masa');

  const Objetivo(this.etiqueta);
  final String etiqueta;
}

Objetivo objetivoDesde(String? v) => Objetivo.values.firstWhere(
  (o) => o.name == v,
  orElse: () => Objetivo.mantener,
);

/// Condiciones que endurecen algunos límites diarios (sodio, azúcar, grasa
/// saturada). No son un diagnóstico: las marca la persona en su perfil.
enum Condicion {
  hipertension('Hipertensión'),
  diabetes('Diabetes o prediabetes'),
  colesterolAlto('Colesterol alto');

  const Condicion(this.etiqueta);
  final String etiqueta;
}

Condicion? condicionDesde(String v) {
  for (final c in Condicion.values) {
    if (c.name == v) return c;
  }
  return null;
}

enum TipoComida {
  desayuno('Desayuno', 0.25),
  almuerzo('Almuerzo', 0.35),
  cena('Cena', 0.30),
  snack('Snack', 0.10);

  const TipoComida(this.etiqueta, this.porcionDelDia);
  final String etiqueta;

  /// Fracción de las calorías diarias que se espera de esta comida. Sirve para
  /// decir "este almuerzo va bien" en vez de compararlo con el día entero.
  final double porcionDelDia;
}

TipoComida tipoComidaDesde(String? v) => TipoComida.values.firstWhere(
  (t) => t.name == v,
  orElse: () => TipoComida.almuerzo,
);

/// Sugiere el tipo de comida por la hora, para no obligar a elegirlo a mano.
TipoComida tipoComidaPorHora(DateTime f) {
  final h = f.hour;
  if (h < 11) return TipoComida.desayuno;
  if (h < 16) return TipoComida.almuerzo;
  if (h < 18) return TipoComida.snack;
  return TipoComida.cena;
}

/// Aporte nutricional. Todo en gramos salvo [kcal] y [sodio] (mg).
class Nutrientes {
  const Nutrientes({
    this.kcal = 0,
    this.proteina = 0,
    this.carbohidratos = 0,
    this.azucares = 0,
    this.grasa = 0,
    this.saturada = 0,
    this.fibra = 0,
    this.sodio = 0,
  });

  final double kcal;
  final double proteina;
  final double carbohidratos;

  /// Azúcares totales del alimento. Las guías limitan los *libres* (añadidos y
  /// los de zumos y miel); esta cifra los incluye junto a los de la fruta
  /// entera, así que sobreestima un poco en dietas con mucha fruta.
  final double azucares;

  final double grasa;
  final double saturada;
  final double fibra;

  /// Sodio en miligramos. Para leerlo como sal: 1 g de sal ≈ 400 mg de sodio.
  final double sodio;

  static const cero = Nutrientes();

  Nutrientes operator +(Nutrientes o) => Nutrientes(
    kcal: kcal + o.kcal,
    proteina: proteina + o.proteina,
    carbohidratos: carbohidratos + o.carbohidratos,
    azucares: azucares + o.azucares,
    grasa: grasa + o.grasa,
    saturada: saturada + o.saturada,
    fibra: fibra + o.fibra,
    sodio: sodio + o.sodio,
  );

  Nutrientes operator *(double f) => Nutrientes(
    kcal: kcal * f,
    proteina: proteina * f,
    carbohidratos: carbohidratos * f,
    azucares: azucares * f,
    grasa: grasa * f,
    saturada: saturada * f,
    fibra: fibra * f,
    sodio: sodio * f,
  );

  bool get vacio =>
      kcal == 0 && proteina == 0 && carbohidratos == 0 && grasa == 0;

  factory Nutrientes.desdeJson(Map<String, dynamic> j) => Nutrientes(
    kcal: _num(j['kcal']),
    proteina: _num(j['proteina']),
    carbohidratos: _num(j['carbohidratos']),
    azucares: _num(j['azucares']),
    grasa: _num(j['grasa']),
    saturada: _num(j['saturada']),
    fibra: _num(j['fibra']),
    sodio: _num(j['sodio']),
  );

  Map<String, dynamic> aJson() => {
    'kcal': kcal,
    'proteina': proteina,
    'carbohidratos': carbohidratos,
    'azucares': azucares,
    'grasa': grasa,
    'saturada': saturada,
    'fibra': fibra,
    'sodio': sodio,
  };
}

double _num(Object? v) => v is num ? v.toDouble() : 0;

/// De dónde salieron los números de un alimento. Se muestra en la ficha para
/// que quede claro qué está medido y qué está estimado.
enum FuenteDatos {
  base('Base nutricional'),
  modelo('Estimado por el modelo'),
  manual('Corregido por ti');

  const FuenteDatos(this.etiqueta);
  final String etiqueta;
}

FuenteDatos fuenteDesde(String? v) => FuenteDatos.values.firstWhere(
  (f) => f.name == v,
  orElse: () => FuenteDatos.modelo,
);

/// Un alimento reconocido dentro de una foto.
class Alimento {
  const Alimento({
    required this.nombre,
    required this.gramos,
    required this.por100g,
    this.densidad = 0,
    this.fuente = FuenteDatos.modelo,
    this.confianza = 0.5,
    this.referencia = '',
  });

  final String nombre;

  /// Porción estimada. Es el número más frágil de toda la app: de una foto
  /// plana no se deduce el volumen, así que el error habitual ronda el 20-30%.
  final double gramos;

  final Nutrientes por100g;

  /// Gramos por mililitro, o 0 si el alimento es sólido.
  ///
  /// La porción se guarda **siempre en gramos**, porque cualquier base
  /// nutricional da los nutrientes por 100 g, también los de las bebidas. Pero
  /// nadie pesa un vaso de gaseosa: lo mide en mililitros. Esta densidad es lo
  /// que traduce entre la unidad en que se escribe y la unidad en que se
  /// calcula, sin tener que duplicar la tabla nutricional en dos unidades.
  ///
  /// Ojo con las etiquetas: las de bebidas suelen venir por 100 ml, no por
  /// 100 g. Si se copia una etiqueta a [por100g] hay que dividirla por la
  /// densidad primero.
  final double densidad;

  final FuenteDatos fuente;

  /// Seguridad del modelo al identificar el alimento, de 0 a 1.
  final double confianza;

  /// Identificador en la base nutricional (p. ej. "usda:173410"). Vacío si el
  /// dato no vino de una base.
  final String referencia;

  Nutrientes get total => por100g * (gramos / 100);

  bool get esLiquido => densidad > 0;

  /// "ml" en los líquidos, "g" en el resto.
  String get unidad => esLiquido ? 'ml' : 'g';

  /// La porción en su propia unidad: es la que se muestra y la que se edita.
  double get cantidad => esLiquido ? gramos / densidad : gramos;

  /// Copia con la porción fijada en la unidad del alimento.
  Alimento conCantidad(double c) =>
      copiar(gramos: esLiquido ? c * densidad : c);

  /// Densidad calórica en kcal por 100 g. Por encima de ~250 el alimento suma
  /// muchas calorías sin llenar, que es lo que suele romper un déficit.
  ///
  /// Lleva apellido para no confundirse con [densidad], que es masa por
  /// volumen: son dos cosas distintas que en castellano comparten la palabra.
  double get densidadCalorica => por100g.kcal;

  Alimento copiar({
    String? nombre,
    double? gramos,
    Nutrientes? por100g,
    FuenteDatos? fuente,
    double? confianza,
  }) => Alimento(
    nombre: nombre ?? this.nombre,
    gramos: gramos ?? this.gramos,
    por100g: por100g ?? this.por100g,
    densidad: densidad,
    fuente: fuente ?? this.fuente,
    confianza: confianza ?? this.confianza,
    referencia: referencia,
  );

  factory Alimento.desdeJson(Map<String, dynamic> j) => Alimento(
    nombre: (j['nombre'] ?? '') as String,
    gramos: _num(j['gramos']),
    por100g: Nutrientes.desdeJson(
      (j['por_100g'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
    ),
    densidad: _num(j['densidad']),
    fuente: fuenteDesde(j['fuente'] as String?),
    confianza: _num(j['confianza']),
    referencia: (j['referencia'] ?? '') as String,
  );

  Map<String, dynamic> aJson() => {
    'nombre': nombre,
    'gramos': gramos,
    'por_100g': por100g.aJson(),
    'densidad': densidad,
    'fuente': fuente.name,
    'confianza': confianza,
    'referencia': referencia,
  };
}

/// Una comida registrada: la foto, lo que el modelo reconoció en ella y las
/// correcciones que haya hecho la persona.
class Comida {
  const Comida({
    required this.id,
    required this.perfilId,
    required this.fecha,
    required this.tipo,
    required this.alimentos,
    this.fotoUrl = '',
    this.descripcion = '',
  });

  final String id;
  final String perfilId;
  final DateTime fecha;
  final TipoComida tipo;
  final List<Alimento> alimentos;
  final String fotoUrl;

  /// Cómo describió el plato el modelo: "arroz con pollo y ensalada criolla".
  final String descripcion;

  Nutrientes get total =>
      alimentos.fold(Nutrientes.cero, (acc, a) => acc + a.total);

  double get gramosTotales => alimentos.fold(0.0, (acc, a) => acc + a.gramos);

  /// Confianza más baja de la foto: si un solo alimento va dudoso, la suma
  /// entera lo está.
  double get confianza => alimentos.isEmpty
      ? 0
      : alimentos.map((a) => a.confianza).reduce((a, b) => a < b ? a : b);

  Comida copiar({
    TipoComida? tipo,
    List<Alimento>? alimentos,
    String? fotoUrl,
    DateTime? fecha,
  }) => Comida(
    id: id,
    perfilId: perfilId,
    fecha: fecha ?? this.fecha,
    tipo: tipo ?? this.tipo,
    alimentos: alimentos ?? this.alimentos,
    fotoUrl: fotoUrl ?? this.fotoUrl,
    descripcion: descripcion,
  );

  factory Comida.desdeJson(Map<String, dynamic> j) => Comida(
    id: j['id'] as String,
    perfilId: (j['perfil_id'] ?? '') as String,
    fecha: DateTime.parse(j['fecha'] as String).toLocal(),
    tipo: tipoComidaDesde(j['tipo'] as String?),
    alimentos: ((j['alimentos'] ?? const []) as List)
        .map((a) => Alimento.desdeJson(a as Map<String, dynamic>))
        .toList(),
    fotoUrl: (j['foto_url'] ?? '') as String,
    descripcion: (j['descripcion'] ?? '') as String,
  );

  Map<String, dynamic> aJson() => {
    'id': id,
    'perfil_id': perfilId,
    'fecha': fecha.toUtc().toIso8601String(),
    'tipo': tipo.name,
    'alimentos': alimentos.map((a) => a.aJson()).toList(),
    'foto_url': fotoUrl,
    'descripcion': descripcion,
  };
}

/// Perfil de la persona. Los datos antropométricos no son decorativos: de
/// ellos salen el IMC y toda la meta diaria.
class Perfil {
  const Perfil({
    required this.id,
    required this.nombre,
    this.sexo = Sexo.femenino,
    this.edad = 30,
    this.alturaCm = 165,
    this.pesoKg = 65,
    this.actividad = NivelActividad.ligero,
    this.objetivo = Objetivo.mantener,
    this.condiciones = const {},
    this.perfilCompleto = false,
  });

  final String id;
  final String nombre;
  final Sexo sexo;

  /// Guardamos la edad en años, no la fecha de nacimiento: en la fórmula de
  /// Mifflin-St Jeor un año de más mueve el resultado 5 kcal, muy por debajo
  /// del error de estimar una porción con una foto.
  final int edad;

  final double alturaCm;
  final double pesoKg;
  final NivelActividad actividad;
  final Objetivo objetivo;
  final Set<Condicion> condiciones;

  /// Falso hasta que la persona pasa por el onboarding. Sin estos datos no se
  /// puede calcular nada, así que el router la manda allí.
  final bool perfilCompleto;

  factory Perfil.desdeJson(Map<String, dynamic> j) => Perfil(
    id: j['id'] as String,
    nombre: (j['nombre'] ?? '') as String,
    sexo: sexoDesde(j['sexo'] as String?),
    edad: (j['edad'] as num?)?.toInt() ?? 30,
    alturaCm: _num(j['altura_cm']),
    pesoKg: _num(j['peso_kg']),
    actividad: actividadDesde(j['actividad'] as String?),
    objetivo: objetivoDesde(j['objetivo'] as String?),
    condiciones: ((j['condiciones'] ?? const []) as List)
        .map((c) => condicionDesde(c as String))
        .whereType<Condicion>()
        .toSet(),
    perfilCompleto: (j['perfil_completo'] ?? false) as bool,
  );

  Map<String, dynamic> aJson() => {
    'id': id,
    'nombre': nombre,
    'sexo': sexo.name,
    'edad': edad,
    'altura_cm': alturaCm,
    'peso_kg': pesoKg,
    'actividad': actividad.name,
    'objetivo': objetivo.name,
    'condiciones': condiciones.map((c) => c.name).toList(),
    'perfil_completo': perfilCompleto,
  };

  Perfil copiar({
    String? nombre,
    Sexo? sexo,
    int? edad,
    double? alturaCm,
    double? pesoKg,
    NivelActividad? actividad,
    Objetivo? objetivo,
    Set<Condicion>? condiciones,
    bool? perfilCompleto,
  }) => Perfil(
    id: id,
    nombre: nombre ?? this.nombre,
    sexo: sexo ?? this.sexo,
    edad: edad ?? this.edad,
    alturaCm: alturaCm ?? this.alturaCm,
    pesoKg: pesoKg ?? this.pesoKg,
    actividad: actividad ?? this.actividad,
    objetivo: objetivo ?? this.objetivo,
    condiciones: condiciones ?? this.condiciones,
    perfilCompleto: perfilCompleto ?? this.perfilCompleto,
  );
}

/// Un pesaje. El historial es lo que permite dibujar el progreso y comprobar
/// si el déficit calculado se está cumpliendo de verdad.
class RegistroPeso {
  const RegistroPeso({
    required this.id,
    required this.perfilId,
    required this.fecha,
    required this.pesoKg,
  });

  final String id;
  final String perfilId;
  final DateTime fecha;
  final double pesoKg;

  factory RegistroPeso.desdeJson(Map<String, dynamic> j) => RegistroPeso(
    id: j['id'] as String,
    perfilId: (j['perfil_id'] ?? '') as String,
    fecha: DateTime.parse(j['fecha'] as String).toLocal(),
    pesoKg: _num(j['peso_kg']),
  );

  Map<String, dynamic> aJson() => {
    'id': id,
    'perfil_id': perfilId,
    'fecha': Fmt.soloFecha(fecha).toIso8601String(),
    'peso_kg': pesoKg,
  };
}

/// Total de un día, para las tarjetas de progreso.
class ResumenDia {
  const ResumenDia({
    required this.fecha,
    required this.total,
    required this.comidas,
  });

  final DateTime fecha;
  final Nutrientes total;
  final int comidas;

  bool get sinRegistro => comidas == 0;
}
