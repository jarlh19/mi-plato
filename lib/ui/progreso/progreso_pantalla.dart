import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/modelos/modelos.dart';
import '../../datos/nutricion/calculos.dart';
import '../../datos/nutricion/veredicto.dart';
import '../../estado/providers.dart';
import '../comun/widgets.dart';

/// Progreso: la semana de calorías, el IMC y la curva de peso.
class ProgresoPantalla extends ConsumerWidget {
  const ProgresoPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(sesionProvider);
    final meta = ref.watch(metaProvider);
    final semana = ref.watch(resumenSemanaProvider);
    final pesos = ref.watch(pesosProvider);

    if (perfil == null || meta == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _TarjetaImc(perfil: perfil, meta: meta),
        const SizedBox(height: 16),
        AsyncVista<List<ResumenDia>>(
          valor: semana,
          alReintentar: () => ref.invalidate(resumenSemanaProvider),
          constructor: (dias) => _TarjetaSemana(dias: dias, meta: meta),
        ),
        const SizedBox(height: 16),
        AsyncVista<List<RegistroPeso>>(
          valor: pesos,
          alReintentar: () => ref.invalidate(pesosProvider),
          constructor: (lista) =>
              _TarjetaPeso(pesos: lista, perfil: perfil, meta: meta),
        ),
      ],
    );
  }
}

class _TarjetaImc extends StatelessWidget {
  const _TarjetaImc({required this.perfil, required this.meta});

  final Perfil perfil;
  final MetaDiaria meta;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final lectura = lecturaImc(perfil);
    final semanas = semanasHastaRangoSaludable(perfil, meta);
    final color = Tema.severidad(context, switch (lectura.nivel) {
      Severidad.bueno => Tema.bueno,
      Severidad.aviso => Tema.aviso,
      Severidad.malo => Tema.malo,
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tu IMC', style: t.titleSmall),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  lectura.titulo.split(' · ').first,
                  style: t.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    categoriaImc(imc(perfil.pesoKg, perfil.alturaCm)).etiqueta,
                    style: t.titleMedium?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _EscalaImc(valor: imc(perfil.pesoKg, perfil.alturaCm)),
            const SizedBox(height: 12),
            Text(
              lectura.detalle,
              style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
            if (semanas != null) ...[
              const SizedBox(height: 8),
              Text(
                'Al ritmo de tu meta actual, unas $semanas semanas para entrar '
                'en el rango saludable.',
                style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'El IMC no distingue músculo de grasa ni mide dónde está. Es una '
              'referencia de partida, no un diagnóstico.',
              style: t.bodySmall?.copyWith(
                color: esquema.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de las categorías de IMC con una marca en el valor actual.
class _EscalaImc extends StatelessWidget {
  const _EscalaImc({required this.valor});

  final double valor;

  @override
  Widget build(BuildContext context) {
    // La escala se recorta en 40: por encima el marcador ya está al final.
    final posicion = ((valor - 15) / 25).clamp(0.0, 1.0);
    // La escala es decorativa: el valor y la categoría ya se leen encima, y
    // describir cuatro tramos de color no aporta nada a quien no la ve.
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (_, limites) => SizedBox(
          height: 26,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      // Anchos proporcionales a los tramos de la OMS.
                      Expanded(flex: 14, child: _tramo(Tema.aviso)),
                      Expanded(flex: 26, child: _tramo(Tema.bueno)),
                      Expanded(flex: 20, child: _tramo(Tema.aviso)),
                      Expanded(flex: 40, child: _tramo(Tema.malo)),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: (limites.maxWidth - 10) * posicion,
                top: 0,
                child: Container(
                  width: 10,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tramo(Color color) =>
      Container(height: 10, color: color.withValues(alpha: 0.55));
}

class _TarjetaSemana extends StatelessWidget {
  const _TarjetaSemana({required this.dias, required this.meta});

  final List<ResumenDia> dias;
  final MetaDiaria meta;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final conRegistro = dias.where((d) => !d.sinRegistro).toList();
    final media = conRegistro.isEmpty
        ? 0.0
        : conRegistro.fold(0.0, (a, d) => a + d.total.kcal) /
              conRegistro.length;
    final tope = math.max(
      meta.kcal * 1.25,
      dias.fold(0.0, (a, d) => math.max(a, d.total.kcal)) * 1.1,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Últimos 7 días', style: t.titleSmall),
            const SizedBox(height: 14),
            SizedBox(
              height: 140,
              child: Stack(
                children: [
                  // Línea de la meta: la referencia contra la que se lee todo.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 22 + (140 - 22) * (meta.kcal / tope),
                    child: Container(
                      height: 1,
                      color: esquema.outline.withValues(alpha: 0.6),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in dias)
                        Expanded(
                          child: _Barra(dia: d, tope: tope, meta: meta),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              conRegistro.isEmpty
                  ? 'Sin registros esta semana.'
                  : 'Media de los días registrados: ${Fmt.kcal(media)}. '
                        'Tu meta es ${Fmt.kcal(meta.kcal)}.',
              style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
            if (conRegistro.length < dias.length)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Los días sin registrar no cuentan en la media, así que '
                  'saltarse el diario mejora el número sin mejorar la dieta.',
                  style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({required this.dia, required this.tope, required this.meta});

  final ResumenDia dia;
  final double tope;
  final MetaDiaria meta;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final alto = tope > 0 ? (dia.total.kcal / tope).clamp(0.0, 1.0) : 0.0;
    final pasado = dia.total.kcal > meta.kcal;

    // Cada barra es una figura sin texto salvo el día. Sin esto, un lector de
    // pantalla recorre "25, 26, 27..." sin ninguna cifra.
    return Semantics(
      label: dia.sinRegistro
          ? '${Fmt.diaCorto(dia.fecha)}: sin registro'
          : '${Fmt.diaCorto(dia.fecha)}: ${dia.total.kcal.round()} kilocalorías'
                '${pasado ? ", por encima de la meta" : ""}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: dia.sinRegistro ? 0.02 : math.max(alto, 0.02),
                  child: Container(
                    decoration: BoxDecoration(
                      color: dia.sinRegistro
                          ? esquema.surfaceContainerHighest
                          : pasado
                          ? Tema.severidad(context, Tema.malo)
                          : esquema.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              Fmt.diaCorto(dia.fecha).split(' ').first,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaPeso extends ConsumerWidget {
  const _TarjetaPeso({
    required this.pesos,
    required this.perfil,
    required this.meta,
  });

  final List<RegistroPeso> pesos;
  final Perfil perfil;
  final MetaDiaria meta;

  Future<void> _registrar(BuildContext context, WidgetRef ref) async {
    final controlador = TextEditingController(
      text: perfil.pesoKg.toStringAsFixed(1),
    );
    final valor = await showDialog<double>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Cuánto pesas hoy?'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              d,
              double.tryParse(controlador.text.replaceAll(',', '.')),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (valor == null || valor < 30 || valor > 300) return;
    try {
      await ref.read(diarioRepoProvider).registrarPeso(perfil.id, valor);
      // El peso entra en la fórmula del gasto, así que la meta se recalcula.
      await ref
          .read(sesionProvider.notifier)
          .guardar(perfil.copiar(pesoKg: valor));
      if (context.mounted) refrescarTodo(ref);
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final real = ritmoRealSemanal(pesos);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Peso', style: t.titleSmall)),
                TextButton.icon(
                  onPressed: () => _registrar(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Registrar'),
                ),
              ],
            ),
            if (pesos.length < 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Con un solo pesaje no hay tendencia. Pésate una o dos veces '
                  'por semana, siempre a la misma hora.',
                  style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              Semantics(
                // La curva es un canvas. Lo que se puede decir con palabras es
                // de dónde sale y adónde llega; el detalle punto a punto no
                // cabe en una etiqueta y tampoco lo pediría nadie.
                label:
                    'Curva de peso: de ${Fmt.peso(pesos.first.pesoKg)} el '
                    '${Fmt.diaCorto(pesos.first.fecha)} a '
                    '${Fmt.peso(pesos.last.pesoKg)} el '
                    '${Fmt.diaCorto(pesos.last.fecha)}.',
                excludeSemantics: true,
                child: SizedBox(
                  height: 120,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _PintorPeso(
                      pesos: pesos,
                      color: esquema.primary,
                      rejilla: esquema.outlineVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${Fmt.peso(pesos.first.pesoKg)} → '
                      '${Fmt.peso(pesos.last.pesoKg)}',
                      style: t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${Fmt.diaCorto(pesos.first.fecha)} – '
                    '${Fmt.diaCorto(pesos.last.fecha)}',
                    style: t.bodySmall?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _ComparacionRitmo(estimado: meta.ritmoSemanalKg, real: real),
          ],
        ),
      ),
    );
  }
}

/// Contrasta el ritmo que predice la meta con el que marca la báscula. Si no
/// coinciden, lo que falla suele ser la estimación de porciones.
class _ComparacionRitmo extends StatelessWidget {
  const _ComparacionRitmo({required this.estimado, required this.real});

  final double estimado;
  final double? real;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    String kg(double v) =>
        '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)} kg/semana';

    if (real == null) {
      return Text(
        'Tu meta apunta a ${kg(-estimado)}. Hacen falta dos semanas de '
        'pesajes para comparar con lo que pasa de verdad.',
        style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
      );
    }

    final desvio = (real! - (-estimado)).abs();
    final coincide = desvio < 0.2;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          coincide ? Icons.check_circle_outline : Icons.info_outline,
          size: 18,
          color: Tema.severidad(context, coincide ? Tema.bueno : Tema.aviso),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            coincide
                ? 'Previsto ${kg(-estimado)}, real ${kg(real!)}. El cálculo '
                      'está cuadrando.'
                : 'Previsto ${kg(-estimado)}, real ${kg(real!)}. La diferencia '
                      'suele venir de porciones mal estimadas o de comidas sin '
                      'registrar.',
            style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _PintorPeso extends CustomPainter {
  _PintorPeso({
    required this.pesos,
    required this.color,
    required this.rejilla,
  });

  final List<RegistroPeso> pesos;
  final Color color;
  final Color rejilla;

  @override
  void paint(Canvas lienzo, Size tamano) {
    if (pesos.length < 2) return;

    final valores = pesos.map((p) => p.pesoKg).toList();
    var min = valores.reduce(math.min);
    var max = valores.reduce(math.max);
    // Un margen mínimo evita que medio kilo de diferencia se dibuje como un
    // precipicio.
    if (max - min < 1) {
      final centro = (max + min) / 2;
      min = centro - 0.5;
      max = centro + 0.5;
    }
    final rango = max - min;

    final primero = pesos.first.fecha.millisecondsSinceEpoch.toDouble();
    final ultimo = pesos.last.fecha.millisecondsSinceEpoch.toDouble();
    final ancho = math.max(ultimo - primero, 1);

    Offset punto(RegistroPeso p) => Offset(
      (p.fecha.millisecondsSinceEpoch - primero) / ancho * tamano.width,
      tamano.height - (p.pesoKg - min) / rango * (tamano.height - 8) - 4,
    );

    final lineaBase = Paint()
      ..color = rejilla
      ..strokeWidth = 1;
    lienzo.drawLine(
      Offset(0, tamano.height),
      Offset(tamano.width, tamano.height),
      lineaBase,
    );

    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final ruta = Path()..moveTo(punto(pesos.first).dx, punto(pesos.first).dy);
    for (final p in pesos.skip(1)) {
      final o = punto(p);
      ruta.lineTo(o.dx, o.dy);
    }
    lienzo.drawPath(ruta, trazo);

    final marca = Paint()..color = color;
    for (final p in pesos) {
      lienzo.drawCircle(punto(p), 3, marca);
    }
  }

  @override
  bool shouldRepaint(_PintorPeso anterior) => anterior.pesos != pesos;
}
