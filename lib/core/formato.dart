import 'package:intl/intl.dart';

/// Formatos de texto compartidos por toda la interfaz.
class Fmt {
  static final _dia = DateFormat('EEEE d \'de\' MMMM', 'es');
  static final _diaCorto = DateFormat('d MMM', 'es');
  static final _hora = DateFormat('HH:mm');

  /// "lunes 31 de agosto", con la primera letra en mayúscula.
  static String dia(DateTime f) {
    final t = _dia.format(f);
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
  }

  static String diaCorto(DateTime f) => _diaCorto.format(f);

  static String hora(DateTime f) => _hora.format(f);

  /// Fecha relativa para la cabecera del diario: "Hoy", "Ayer" o la fecha.
  static String diaRelativo(DateTime f) {
    final hoy = soloFecha(DateTime.now());
    final d = soloFecha(f);
    final dif = hoy.difference(d).inDays;
    if (dif == 0) return 'Hoy';
    if (dif == 1) return 'Ayer';
    return dia(f);
  }

  /// Redondea a entero: las calorías con decimales solo dan ruido visual.
  static String kcal(double v) => '${v.round()} kcal';

  /// "32 g", "1.5 g". Un decimal solo cuando aporta algo.
  static String gramos(double v) => cantidad(v, 'g');

  /// Una porción con su unidad. Los líquidos se anotan en mililitros: pedirle
  /// a alguien los gramos de su vaso de jugo es pedirle que haga una cuenta
  /// que no tiene forma de hacer.
  static String cantidad(double v, String unidad) {
    if (v >= 10 || v == v.roundToDouble()) return '${v.round()} $unidad';
    return '${v.toStringAsFixed(1)} $unidad';
  }

  static String miligramos(double v) => '${v.round()} mg';

  static String porcentaje(double fraccion) => '${(fraccion * 100).round()}%';

  static String imc(double v) => v.toStringAsFixed(1);

  static String peso(double kg) => '${kg.toStringAsFixed(1)} kg';

  /// Medianoche del día indicado. Todas las agrupaciones del diario usan esto
  /// para que dos comidas del mismo día caigan siempre en la misma clave.
  static DateTime soloFecha(DateTime f) => DateTime(f.year, f.month, f.day);
}
