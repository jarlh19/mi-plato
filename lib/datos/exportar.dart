import 'dart:convert';

import 'modelos/modelos.dart';
import 'nutricion/calculos.dart';

/// Vuelca todo lo que la app sabe de una persona en un JSON legible.
///
/// Existe porque esto es un diario de salud: quien lo usa tiene derecho a
/// llevarse sus datos, y sin una salida el registro de meses queda secuestrado
/// dentro de la app. Es también la contraparte honesta del borrado de cuenta:
/// primero te llevas lo tuyo, después lo borras.
///
/// Función pura y sin dependencias de interfaz, para poder probarla.
String exportarJson({
  required Perfil perfil,
  required List<Comida> comidas,
  required List<RegistroPeso> pesos,
  DateTime? generadoEn,
}) {
  final meta = metaDiaria(perfil);
  final ordenadas = [...comidas]..sort((a, b) => a.fecha.compareTo(b.fecha));
  final ordenados = [...pesos]..sort((a, b) => a.fecha.compareTo(b.fecha));

  final datos = {
    'app': 'Mi Plato',
    'version_formato': 1,
    'generado_en': (generadoEn ?? DateTime.now()).toIso8601String(),
    'perfil': perfil.aJson()..remove('id'),
    // Los cálculos derivados van explícitos: quien lea el fichero fuera de la
    // app no tiene por qué rehacer las fórmulas para entender los números.
    // Redondeados: un IMC con quince decimales no es más preciso, solo más
    // difícil de leer, y la estimación de partida no da para tanto.
    'calculado': {
      'imc': double.parse(
        imc(perfil.pesoKg, perfil.alturaCm).toStringAsFixed(1),
      ),
      'categoria_imc': categoriaImc(imc(perfil.pesoKg, perfil.alturaCm)).name,
      'tmb_kcal': meta.tmb.round(),
      'gasto_diario_kcal': meta.gasto.round(),
      'meta_kcal': meta.kcal.round(),
      'meta_proteina_g': meta.proteina.round(),
      'meta_carbohidratos_g': meta.carbohidratos.round(),
      'meta_grasa_g': meta.grasa.round(),
      'tope_azucar_g': meta.azucarMax.round(),
      'tope_saturada_g': meta.saturadaMax.round(),
      'tope_sodio_mg': meta.sodioMax.round(),
    },
    'comidas': [
      for (final c in ordenadas)
        {
          ...c.aJson()..remove('perfil_id'),
          // Cada alimento, además de los gramos con los que se calculó, lleva
          // la cantidad en su propia unidad: es la que la persona escribió, y
          // leer "364 g" donde anotó un vaso de 350 ml no se entiende.
          'alimentos': [
            for (final a in c.alimentos)
              {...a.aJson(), 'cantidad': a.cantidad, 'unidad': a.unidad},
          ],
          // La ruta de la foto no sirve fuera de la app: el enlace es firmado
          // y caduca. Se dice cuántas hay, no dónde están.
          'foto_url': c.fotoUrl.isEmpty ? null : 'guardada en la app',
          'total': c.total.aJson(),
        },
    ],
    'pesos': [
      for (final p in ordenados)
        {
          'fecha': p.fecha.toIso8601String().split('T').first,
          'peso_kg': p.pesoKg,
        },
    ],
    'aviso':
        'Las calorías salen de estimar porciones a partir de fotos, con un '
        'error habitual del 20-30%. No es un registro clínico.',
  };

  return const JsonEncoder.withIndent('  ').convert(datos);
}
