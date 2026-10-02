import '../modelos/modelos.dart';

/// Tabla nutricional de bolsillo, por 100 g de alimento listo para comer.
///
/// Los nutrientes van por 100 g incluso en las bebidas, que es como los publica
/// el USDA. Lo que cambia en un líquido es la unidad en que se anota la
/// porción: mililitros, porque nadie pesa un vaso. La densidad de cada bebida
/// hace la traducción.
///
/// Tiene dos usos:
///  - **Añadir a mano**: cuando la foto falla o no hay foto, la persona busca
///    aquí y la app no necesita red.
///  - **Modo demo**: sin backend, el análisis simulado arma un plato con estas
///    entradas para poder recorrer la app entera.
///
/// La fuente de verdad en producción es la base nutricional que consulta la
/// Edge Function (USDA FoodData Central). Esta tabla son valores redondeados
/// de referencia para platos comunes en Perú y Colombia; sirven para orientar,
/// no para una pauta clínica.
class AlimentoBase {
  const AlimentoBase(this.nombre, this.porcionTipica, this.por100g,
      {this.densidad = 0});

  final String nombre;

  /// Porción de referencia cuando se añade a mano, **en la unidad del
  /// alimento**: mililitros si es líquido, gramos si no.
  final double porcionTipica;

  /// Nutrientes por 100 g, también en las bebidas. Ver [Alimento.densidad].
  final Nutrientes por100g;

  /// Gramos por mililitro; 0 en los sólidos. Ver [Alimento.densidad].
  final double densidad;

  /// "ml" en los líquidos, "g" en el resto.
  String get unidad => densidad > 0 ? 'ml' : 'g';

  /// [cantidad] va en la unidad del alimento, igual que [porcionTipica].
  Alimento aAlimento({double? cantidad}) {
    final c = cantidad ?? porcionTipica;
    return Alimento(
      nombre: nombre,
      gramos: densidad > 0 ? c * densidad : c,
      por100g: por100g,
      densidad: densidad,
      fuente: FuenteDatos.base,
      confianza: 1,
      referencia: 'local:${_clave(nombre)}',
    );
  }
}

const _tabla = <AlimentoBase>[
  // Cereales y tubérculos
  AlimentoBase('Arroz blanco cocido', 150, Nutrientes(kcal: 130, proteina: 2.7, carbohidratos: 28, azucares: 0.1, grasa: 0.3, saturada: 0.1, fibra: 0.4, sodio: 1)),
  AlimentoBase('Pasta cocida', 180, Nutrientes(kcal: 158, proteina: 5.8, carbohidratos: 31, azucares: 0.6, grasa: 0.9, saturada: 0.2, fibra: 1.8, sodio: 1)),
  AlimentoBase('Papa cocida', 150, Nutrientes(kcal: 87, proteina: 2, carbohidratos: 20, azucares: 0.9, grasa: 0.1, saturada: 0.03, fibra: 1.8, sodio: 5)),
  AlimentoBase('Papas fritas', 120, Nutrientes(kcal: 312, proteina: 3.4, carbohidratos: 41, azucares: 0.3, grasa: 15, saturada: 2.3, fibra: 3.8, sodio: 210)),
  AlimentoBase('Yuca cocida', 150, Nutrientes(kcal: 160, proteina: 1.4, carbohidratos: 38, azucares: 1.7, grasa: 0.3, saturada: 0.07, fibra: 1.8, sodio: 14)),
  AlimentoBase('Choclo o maíz', 120, Nutrientes(kcal: 96, proteina: 3.4, carbohidratos: 21, azucares: 4.5, grasa: 1.5, saturada: 0.2, fibra: 2.4, sodio: 15)),
  AlimentoBase('Avena cocida', 200, Nutrientes(kcal: 71, proteina: 2.5, carbohidratos: 12, azucares: 0.3, grasa: 1.5, saturada: 0.3, fibra: 1.7, sodio: 4)),
  AlimentoBase('Pan francés', 60, Nutrientes(kcal: 275, proteina: 9, carbohidratos: 52, azucares: 2.5, grasa: 3, saturada: 0.7, fibra: 2.4, sodio: 520)),
  AlimentoBase('Arepa', 100, Nutrientes(kcal: 220, proteina: 4.5, carbohidratos: 45, azucares: 1, grasa: 2.5, saturada: 0.5, fibra: 2, sodio: 300)),
  AlimentoBase('Tortilla de maíz', 50, Nutrientes(kcal: 218, proteina: 5.7, carbohidratos: 45, azucares: 1, grasa: 2.9, saturada: 0.4, fibra: 5, sodio: 45)),

  // Legumbres
  AlimentoBase('Frijoles cocidos', 150, Nutrientes(kcal: 127, proteina: 8.7, carbohidratos: 22.8, azucares: 0.3, grasa: 0.5, saturada: 0.1, fibra: 6.4, sodio: 2)),
  AlimentoBase('Lentejas cocidas', 150, Nutrientes(kcal: 116, proteina: 9, carbohidratos: 20, azucares: 1.8, grasa: 0.4, saturada: 0.05, fibra: 7.9, sodio: 2)),
  AlimentoBase('Garbanzos cocidos', 150, Nutrientes(kcal: 164, proteina: 8.9, carbohidratos: 27, azucares: 4.8, grasa: 2.6, saturada: 0.3, fibra: 7.6, sodio: 7)),

  // Carnes, pescado y huevo
  AlimentoBase('Pechuga de pollo a la plancha', 120, Nutrientes(kcal: 165, proteina: 31, carbohidratos: 0, azucares: 0, grasa: 3.6, saturada: 1, fibra: 0, sodio: 74)),
  AlimentoBase('Pollo frito con piel', 120, Nutrientes(kcal: 260, proteina: 24, carbohidratos: 8, azucares: 0, grasa: 15, saturada: 4, fibra: 0.3, sodio: 400)),
  AlimentoBase('Carne de res a la plancha', 120, Nutrientes(kcal: 250, proteina: 26, carbohidratos: 0, azucares: 0, grasa: 15, saturada: 6, fibra: 0, sodio: 60)),
  AlimentoBase('Cerdo asado', 120, Nutrientes(kcal: 297, proteina: 26, carbohidratos: 0, azucares: 0, grasa: 21, saturada: 7.7, fibra: 0, sodio: 62)),
  AlimentoBase('Pescado a la plancha', 130, Nutrientes(kcal: 140, proteina: 24, carbohidratos: 0, azucares: 0, grasa: 4.5, saturada: 1, fibra: 0, sodio: 80)),
  AlimentoBase('Atún en lata', 80, Nutrientes(kcal: 128, proteina: 23.6, carbohidratos: 0, azucares: 0, grasa: 3, saturada: 0.8, fibra: 0, sodio: 350)),
  AlimentoBase('Ceviche', 200, Nutrientes(kcal: 100, proteina: 15, carbohidratos: 6, azucares: 1.5, grasa: 1.5, saturada: 0.3, fibra: 0.6, sodio: 350)),
  AlimentoBase('Huevo cocido', 55, Nutrientes(kcal: 155, proteina: 12.6, carbohidratos: 1.1, azucares: 1.1, grasa: 10.6, saturada: 3.3, fibra: 0, sodio: 124)),
  AlimentoBase('Huevo frito', 60, Nutrientes(kcal: 196, proteina: 13.6, carbohidratos: 0.8, azucares: 0.4, grasa: 15, saturada: 4, fibra: 0, sodio: 207)),
  AlimentoBase('Salchicha', 50, Nutrientes(kcal: 290, proteina: 11, carbohidratos: 4, azucares: 1.5, grasa: 26, saturada: 9.5, fibra: 0, sodio: 1000)),

  // Verduras y frutas
  AlimentoBase('Ensalada de lechuga y tomate', 100, Nutrientes(kcal: 20, proteina: 1, carbohidratos: 3.5, azucares: 2, grasa: 0.2, saturada: 0.03, fibra: 1.5, sodio: 10)),
  AlimentoBase('Brócoli cocido', 100, Nutrientes(kcal: 35, proteina: 2.4, carbohidratos: 7.2, azucares: 1.4, grasa: 0.4, saturada: 0.05, fibra: 3.3, sodio: 41)),
  AlimentoBase('Zanahoria', 80, Nutrientes(kcal: 41, proteina: 0.9, carbohidratos: 9.6, azucares: 4.7, grasa: 0.2, saturada: 0.03, fibra: 2.8, sodio: 69)),
  AlimentoBase('Palta o aguacate', 70, Nutrientes(kcal: 160, proteina: 2, carbohidratos: 8.5, azucares: 0.7, grasa: 14.7, saturada: 2.1, fibra: 6.7, sodio: 7)),
  AlimentoBase('Plátano o banano', 120, Nutrientes(kcal: 89, proteina: 1.1, carbohidratos: 22.8, azucares: 12.2, grasa: 0.3, saturada: 0.1, fibra: 2.6, sodio: 1)),
  AlimentoBase('Manzana', 150, Nutrientes(kcal: 52, proteina: 0.3, carbohidratos: 13.8, azucares: 10.4, grasa: 0.2, saturada: 0.03, fibra: 2.4, sodio: 1)),
  AlimentoBase('Papaya', 150, Nutrientes(kcal: 43, proteina: 0.5, carbohidratos: 10.8, azucares: 7.8, grasa: 0.3, saturada: 0.08, fibra: 1.7, sodio: 8)),

  // Lácteos
  AlimentoBase('Leche entera', 200, Nutrientes(kcal: 61, proteina: 3.2, carbohidratos: 4.8, azucares: 4.8, grasa: 3.3, saturada: 1.9, fibra: 0, sodio: 43), densidad: 1.03),
  AlimentoBase('Yogur natural', 150, Nutrientes(kcal: 61, proteina: 3.5, carbohidratos: 4.7, azucares: 4.7, grasa: 3.3, saturada: 2.1, fibra: 0, sodio: 46)),
  AlimentoBase('Queso fresco', 40, Nutrientes(kcal: 264, proteina: 18, carbohidratos: 3, azucares: 3, grasa: 20, saturada: 12, fibra: 0, sodio: 373)),

  // Preparados y ultraprocesados
  AlimentoBase('Empanada frita', 100, Nutrientes(kcal: 320, proteina: 9, carbohidratos: 30, azucares: 2, grasa: 18, saturada: 5, fibra: 1.5, sodio: 480)),
  AlimentoBase('Pizza', 130, Nutrientes(kcal: 266, proteina: 11, carbohidratos: 33, azucares: 3.6, grasa: 10, saturada: 4.5, fibra: 2.3, sodio: 598)),
  AlimentoBase('Hamburguesa', 200, Nutrientes(kcal: 295, proteina: 17, carbohidratos: 24, azucares: 5, grasa: 14, saturada: 5.5, fibra: 1.5, sodio: 500)),
  AlimentoBase('Papas fritas de bolsa', 40, Nutrientes(kcal: 536, proteina: 7, carbohidratos: 53, azucares: 0.3, grasa: 35, saturada: 3.5, fibra: 4.8, sodio: 525)),
  AlimentoBase('Galletas dulces', 40, Nutrientes(kcal: 460, proteina: 6, carbohidratos: 70, azucares: 25, grasa: 17, saturada: 8, fibra: 2, sodio: 350)),
  AlimentoBase('Chocolate con leche', 30, Nutrientes(kcal: 535, proteina: 7.6, carbohidratos: 59, azucares: 52, grasa: 30, saturada: 18, fibra: 3.4, sodio: 79)),
  AlimentoBase('Mayonesa', 15, Nutrientes(kcal: 680, proteina: 1, carbohidratos: 1, azucares: 1, grasa: 75, saturada: 11, fibra: 0, sodio: 600)),
  AlimentoBase('Aceite vegetal', 10, Nutrientes(kcal: 884, proteina: 0, carbohidratos: 0, azucares: 0, grasa: 100, saturada: 14, fibra: 0, sodio: 0), densidad: 0.92),

  // Bebidas
  AlimentoBase('Gaseosa', 350, Nutrientes(kcal: 42, proteina: 0, carbohidratos: 10.6, azucares: 10.6, grasa: 0, saturada: 0, fibra: 0, sodio: 4), densidad: 1.04),
  AlimentoBase('Jugo de fruta natural', 250, Nutrientes(kcal: 45, proteina: 0.7, carbohidratos: 10.4, azucares: 8.4, grasa: 0.2, saturada: 0.02, fibra: 0.2, sodio: 1), densidad: 1.05),
  AlimentoBase('Café sin azúcar', 200, Nutrientes(kcal: 2, proteina: 0.1, carbohidratos: 0, azucares: 0, grasa: 0, saturada: 0, fibra: 0, sodio: 2), densidad: 1.00),
];

/// Todos los alimentos de la tabla, ordenados por nombre.
List<AlimentoBase> get catalogoLocal =>
    [..._tabla]..sort((a, b) => a.nombre.compareTo(b.nombre));

String _clave(String s) {
  const con = 'áàäâéèëêíìïîóòöôúùüûñ';
  const sin = 'aaaaeeeeiiiioooouuuun';
  final b = StringBuffer();
  for (final c in s.toLowerCase().runes) {
    final ch = String.fromCharCode(c);
    final i = con.indexOf(ch);
    b.write(i >= 0 ? sin[i] : ch);
  }
  return b.toString();
}

/// Busca por texto libre, ignorando tildes y mayúsculas.
List<AlimentoBase> buscarLocal(String texto) {
  final q = _clave(texto.trim());
  if (q.isEmpty) return catalogoLocal;
  return catalogoLocal.where((a) => _clave(a.nombre).contains(q)).toList();
}

/// Busca la entrada que mejor encaja con un nombre suelto. La usa el modo demo
/// y sirve de red de seguridad cuando la base remota no encuentra el alimento.
AlimentoBase? porNombre(String nombre) {
  final q = _clave(nombre);
  for (final a in _tabla) {
    if (_clave(a.nombre) == q) return a;
  }
  for (final a in _tabla) {
    final k = _clave(a.nombre);
    if (k.contains(q) || q.contains(k)) return a;
  }
  return null;
}
