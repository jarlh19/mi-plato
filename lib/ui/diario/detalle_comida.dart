import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../datos/modelos/modelos.dart';
import '../../datos/nutricion/veredicto.dart';
import '../../estado/providers.dart';
import '../comun/widgets.dart';

/// Ficha de una comida ya guardada: la foto, lo que se reconoció y el veredicto
/// de esa comida en concreto.
Future<void> mostrarDetalleComida(BuildContext context, Comida comida) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, controlador) =>
          _DetalleComida(comida: comida, controlador: controlador),
    ),
  );
}

class _DetalleComida extends ConsumerWidget {
  const _DetalleComida({required this.comida, required this.controlador});

  final Comida comida;
  final ScrollController controlador;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final perfil = ref.watch(sesionProvider);
    final meta = ref.watch(metaProvider);
    final delDia = ref.watch(comidasDelDiaProvider).valueOrNull ?? const [];

    if (perfil == null || meta == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Lo comido antes de esta comida, para poder decir cuánto margen quedaba.
    final previo = delDia
        .where((c) => c.id != comida.id && c.fecha.isBefore(comida.fecha))
        .fold(Nutrientes.cero, (acc, c) => acc + c.total);

    final veredicto = evaluarComida(
      comida: comida,
      perfil: perfil,
      meta: meta,
      yaConsumido: previo,
    );

    return ListView(
      controller: controlador,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        if (comida.fotoUrl.isNotEmpty) ...[
          _Foto(ruta: comida.fotoUrl),
          const SizedBox(height: 16),
        ],
        Text(
          comida.descripcion.isNotEmpty
              ? comida.descripcion
              : comida.tipo.etiqueta,
          style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${comida.tipo.etiqueta} · ${Fmt.hora(comida.fecha)} · '
          '${Fmt.kcal(comida.total.kcal)}',
          style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        TarjetaVeredicto(veredicto: veredicto),
        const SizedBox(height: 16),
        Text('Alimentos', style: t.titleSmall),
        const SizedBox(height: 4),
        for (final a in comida.alimentos)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(a.nombre),
            subtitle: Text(
              '${Fmt.cantidad(a.cantidad, a.unidad)} · ${a.fuente.etiqueta}',
              style: t.bodySmall,
            ),
            trailing: Text(Fmt.kcal(a.total.kcal),
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
        const Divider(height: 24),
        _TablaNutrientes(total: comida.total),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmado = await showDialog<bool>(
              context: context,
              builder: (d) => AlertDialog(
                title: const Text('¿Borrar esta comida?'),
                content: Text(comida.fotoUrl.isEmpty
                    ? 'Dejará de contar en el día.'
                    : 'Dejará de contar en el día y se borrará también su foto.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(d, true),
                      child: const Text('Borrar')),
                ],
              ),
            );
            if (confirmado != true || !context.mounted) return;
            try {
              await eliminarComida(ref, comida);
              if (!context.mounted) return;
              Navigator.pop(context);
            } catch (e) {
              if (context.mounted) mostrarError(context, e);
            }
          },
          icon: const Icon(Icons.delete_outline),
          label: const Text('Borrar comida'),
          style: OutlinedButton.styleFrom(foregroundColor: esquema.error),
        ),
      ],
    );
  }
}

class _Foto extends ConsumerWidget {
  const _Foto({required this.ruta});

  final String ruta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(fotoUrlProvider(ruta));
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: url.when(
          loading: () => const ColoredBox(
            color: Colors.black12,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const ColoredBox(
            color: Colors.black12,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
          data: (u) => u.isEmpty
              ? const ColoredBox(
                  color: Colors.black12,
                  child: Center(child: Icon(Icons.image_not_supported_outlined)),
                )
              : Image.network(u, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _TablaNutrientes extends StatelessWidget {
  const _TablaNutrientes({required this.total});

  final Nutrientes total;

  @override
  Widget build(BuildContext context) {
    final filas = <(String, String)>[
      ('Calorías', Fmt.kcal(total.kcal)),
      ('Proteína', Fmt.gramos(total.proteina)),
      ('Carbohidratos', Fmt.gramos(total.carbohidratos)),
      ('  de los cuales azúcares', Fmt.gramos(total.azucares)),
      ('Grasa', Fmt.gramos(total.grasa)),
      ('  de la cual saturada', Fmt.gramos(total.saturada)),
      ('Fibra', Fmt.gramos(total.fibra)),
      ('Sodio', Fmt.miligramos(total.sodio)),
    ];
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (final (etiqueta, valor) in filas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(etiqueta,
                      style: t.bodyMedium
                          ?.copyWith(color: esquema.onSurfaceVariant)),
                ),
                Text(valor,
                    style:
                        t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }
}
