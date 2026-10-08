import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../datos/modelos/modelos.dart';
import '../../datos/nutricion/calculos.dart';
import '../../estado/providers.dart';
import '../comun/widgets.dart';
import 'detalle_comida.dart';
import 'tarjeta_sugerencias.dart';

/// Diario del día: cuánto llevas, qué dice de tu objetivo y qué comiste.
class DiarioPantalla extends ConsumerWidget {
  const DiarioPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(metaProvider);
    final comidas = ref.watch(comidasDelDiaProvider);
    final dia = ref.watch(diaProvider);

    if (meta == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _BarraDia(dia: dia),
        Expanded(
          child: AsyncVista<List<Comida>>(
            valor: comidas,
            alReintentar: () => ref.invalidate(comidasDelDiaProvider),
            constructor: (lista) => _Contenido(comidas: lista, meta: meta),
          ),
        ),
      ],
    );
  }
}

class _BarraDia extends ConsumerWidget {
  const _BarraDia({required this.dia});

  final DateTime dia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esHoy = dia == Fmt.soloFecha(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Día anterior',
            onPressed: () => ref.read(diaProvider.notifier).state = dia
                .subtract(const Duration(days: 1)),
          ),
          Expanded(
            child: Text(
              Fmt.diaRelativo(dia),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Día siguiente',
            // No se navega al futuro: no hay nada que registrar allí.
            onPressed: esHoy
                ? null
                : () => ref.read(diaProvider.notifier).state = dia.add(
                    const Duration(days: 1),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.comidas, required this.meta});

  final List<Comida> comidas;
  final MetaDiaria meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = comidas.fold(Nutrientes.cero, (acc, c) => acc + c.total);
    final veredicto = ref.watch(veredictoDiaProvider);
    final t = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Center(
          child: AnilloCalorias(consumidas: total.kcal, meta: meta.kcal),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reparto del día', style: t.titleSmall),
                const SizedBox(height: 6),
                BarraNutriente(
                  etiqueta: 'Proteína',
                  valor: total.proteina,
                  meta: meta.proteina,
                  texto:
                      '${Fmt.gramos(total.proteina)} / ${Fmt.gramos(meta.proteina)}',
                ),
                BarraNutriente(
                  etiqueta: 'Carbohidratos',
                  valor: total.carbohidratos,
                  meta: meta.carbohidratos,
                  texto:
                      '${Fmt.gramos(total.carbohidratos)} / ${Fmt.gramos(meta.carbohidratos)}',
                ),
                BarraNutriente(
                  etiqueta: 'Grasa',
                  valor: total.grasa,
                  meta: meta.grasa,
                  texto:
                      '${Fmt.gramos(total.grasa)} / ${Fmt.gramos(meta.grasa)}',
                ),
                BarraNutriente(
                  etiqueta: 'Fibra',
                  valor: total.fibra,
                  meta: meta.fibra,
                  texto:
                      '${Fmt.gramos(total.fibra)} / ${Fmt.gramos(meta.fibra)}',
                ),
                const Divider(height: 24),
                Text('Topes del día', style: t.titleSmall),
                const SizedBox(height: 6),
                BarraNutriente(
                  etiqueta: 'Azúcar',
                  valor: total.azucares,
                  meta: meta.azucarMax,
                  esTecho: true,
                  texto:
                      '${Fmt.gramos(total.azucares)} / ${Fmt.gramos(meta.azucarMax)}',
                ),
                BarraNutriente(
                  etiqueta: 'Grasa saturada',
                  valor: total.saturada,
                  meta: meta.saturadaMax,
                  esTecho: true,
                  texto:
                      '${Fmt.gramos(total.saturada)} / ${Fmt.gramos(meta.saturadaMax)}',
                ),
                BarraNutriente(
                  etiqueta: 'Sodio',
                  valor: total.sodio,
                  meta: meta.sodioMax,
                  esTecho: true,
                  texto:
                      '${Fmt.miligramos(total.sodio)} / ${Fmt.miligramos(meta.sodioMax)}',
                ),
              ],
            ),
          ),
        ),
        if (veredicto != null && veredicto.puntos.isNotEmpty) ...[
          const SizedBox(height: 16),
          TarjetaVeredicto(veredicto: veredicto, titulo: 'Cómo va tu día'),
        ],
        const SizedBox(height: 16),
        const TarjetaSugerencias(),
        const SizedBox(height: 20),
        if (comidas.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EstadoVacio(
              icono: Icons.no_food_outlined,
              titulo: 'Nada registrado todavía',
              detalle: 'Toca "Registrar comida" y fotografía tu plato.',
            ),
          )
        else
          for (final tipo in TipoComida.values)
            ..._bloqueTipo(
              context,
              ref,
              tipo,
              comidas.where((c) => c.tipo == tipo).toList(),
            ),
      ],
    );
  }

  List<Widget> _bloqueTipo(
    BuildContext context,
    WidgetRef ref,
    TipoComida tipo,
    List<Comida> lista,
  ) {
    if (lista.isEmpty) return const [];
    final t = Theme.of(context).textTheme;
    final kcal = lista.fold(0.0, (acc, c) => acc + c.total.kcal);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Row(
          children: [
            Expanded(child: Text(tipo.etiqueta, style: t.titleSmall)),
            Text(
              Fmt.kcal(kcal),
              style: t.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      for (final c in lista) _FilaComida(comida: c),
    ];
  }
}

class _FilaComida extends ConsumerWidget {
  const _FilaComida({required this.comida});

  final Comida comida;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final titulo = comida.descripcion.isNotEmpty
        ? comida.descripcion
        : comida.alimentos.map((a) => a.nombre).join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => mostrarDetalleComida(context, comida),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: esquema.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    comida.fotoUrl.isEmpty
                        ? Icons.restaurant
                        : Icons.photo_outlined,
                    color: esquema.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Fmt.hora(comida.fecha)} · '
                        'P ${comida.total.proteina.round()} g · '
                        'C ${comida.total.carbohidratos.round()} g · '
                        'G ${comida.total.grasa.round()} g',
                        style: t.bodySmall?.copyWith(
                          color: esquema.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Fmt.kcal(comida.total.kcal),
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
