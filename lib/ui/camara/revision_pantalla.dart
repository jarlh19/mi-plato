import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../datos/modelos/modelos.dart';
import '../../datos/nutricion/veredicto.dart';
import '../../datos/repos/repos.dart';
import '../../estado/providers.dart';
import '../comun/widgets.dart';
import 'buscador_alimento.dart';

/// Revisión de lo que el modelo reconoció, antes de guardarlo.
///
/// Esta pantalla existe porque la estimación de porciones a partir de una foto
/// falla: el paso de corregir gramos es lo que separa un número inventado de
/// un registro utilizable.
class RevisionPantalla extends ConsumerWidget {
  const RevisionPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borrador = ref.watch(borradorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar comida'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Descartar',
          onPressed: () {
            ref.read(borradorProvider.notifier).limpiar();
            context.pop();
          },
        ),
      ),
      body: borrador.when(
        loading: () => const _Analizando(),
        error: (e, _) => EstadoVacio(
          icono: Icons.image_not_supported_outlined,
          titulo: 'No se pudo leer la foto',
          // Solo el mensaje pensado para la persona: `e.toString()` de un
          // error de red o del SDK filtra detalles internos sin ayudar a nadie.
          detalle: e is ErrorApp
              ? e.mensaje
              : 'Prueba con otra foto o añade los alimentos a mano.',
          accion: FilledButton.tonal(
            onPressed: () {
              ref.read(borradorProvider.notifier).empezarAMano();
            },
            child: const Text('Añadir a mano'),
          ),
        ),
        data: (b) => b == null
            ? const EstadoVacio(
                icono: Icons.restaurant_outlined,
                titulo: 'No hay ninguna comida en curso',
                detalle: 'Vuelve al diario y toca "Registrar comida".',
              )
            : _Formulario(borrador: b),
      ),
    );
  }
}

class _Analizando extends StatelessWidget {
  const _Analizando();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text('Reconociendo el plato…', style: t.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Suele tardar unos segundos.',
            style: t.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Formulario extends ConsumerWidget {
  const _Formulario({required this.borrador});

  final Borrador borrador;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final perfil = ref.watch(sesionProvider);
    final meta = ref.watch(metaProvider);
    final notifier = ref.read(borradorProvider.notifier);

    if (perfil == null || meta == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final comidasHoy = ref.watch(comidasDelDiaProvider).valueOrNull ?? const [];
    final previo = comidasHoy.fold(Nutrientes.cero, (acc, c) => acc + c.total);
    final veredicto = borrador.alimentos.isEmpty
        ? null
        : evaluarComida(
            comida: borrador.comidaProvisional(perfil.id),
            perfil: perfil,
            meta: meta,
            yaConsumido: previo,
          );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (borrador.foto != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.memory(borrador.foto!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (borrador.descripcion.isNotEmpty)
                Text(
                  borrador.descripcion,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              if (borrador.aviso.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: esquema.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: esquema.onTertiaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          borrador.aviso,
                          style: t.bodySmall?.copyWith(
                            color: esquema.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SegmentedButton<TipoComida>(
                // Cuatro segmentos en 375 px dejan ~85 px por etiqueta:
                // con el tamaño por defecto "Desayuno" parte en dos líneas.
                style: SegmentedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                segments: [
                  for (final tipo in TipoComida.values)
                    ButtonSegment(value: tipo, label: Text(tipo.etiqueta)),
                ],
                selected: {borrador.tipo},
                showSelectedIcon: false,
                onSelectionChanged: (s) => notifier.cambiarTipo(s.first),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Text('Alimentos', style: t.titleSmall)),
                  Text(
                    Fmt.kcal(borrador.total.kcal),
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (borrador.alimentos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Todavía no hay nada. Añade lo que comiste.',
                    style: t.bodyMedium?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
                ),
              for (var i = 0; i < borrador.alimentos.length; i++)
                _FilaAlimento(
                  alimento: borrador.alimentos[i],
                  onCantidad: (c) => notifier.cambiarCantidad(i, c),
                  onQuitar: () => notifier.quitar(i),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final elegido = await elegirAlimento(context);
                  if (elegido != null) notifier.agregar(elegido);
                },
                icon: const Icon(Icons.add),
                label: const Text('Añadir alimento'),
              ),
              if (veredicto != null) ...[
                const SizedBox(height: 20),
                TarjetaVeredicto(veredicto: veredicto),
              ],
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              onPressed: borrador.alimentos.isEmpty
                  ? null
                  : () async {
                      try {
                        // No hace falta refrescar aquí: `guardar` ya invalida
                        // lo que cambió, y solo el día que corresponde.
                        await notifier.guardar();
                        if (!context.mounted) return;
                        context.pop();
                        mostrarAviso(context, 'Comida registrada');
                      } catch (e) {
                        if (context.mounted) mostrarError(context, e);
                      }
                    },
              child: const Text('Guardar en el diario'),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilaAlimento extends StatelessWidget {
  const _FilaAlimento({
    required this.alimento,
    required this.onCantidad,
    required this.onQuitar,
  });

  final Alimento alimento;

  /// Recibe la cantidad en la unidad del alimento, no siempre en gramos.
  final ValueChanged<double> onCantidad;

  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final cantidad = alimento.cantidad;

    // Una botella de gaseosa pasa de 600: el tope de un líquido tiene que dar
    // para servirla entera, el de un plato no.
    final tope = alimento.esLiquido ? 1000.0 : 600.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    alimento.nombre,
                    style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  Fmt.kcal(alimento.total.kcal),
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Quitar',
                  onPressed: onQuitar,
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Menos',
                  onPressed: cantidad <= 10
                      ? null
                      : () => onCantidad(cantidad - 10),
                ),
                Expanded(
                  child: Slider(
                    value: cantidad.clamp(0, tope),
                    max: tope,
                    divisions: (tope / 10).round(),
                    label: Fmt.cantidad(cantidad, alimento.unidad),
                    onChanged: (v) => onCantidad(v.roundToDouble()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Más',
                  onPressed: cantidad >= tope
                      ? null
                      : () => onCantidad(cantidad + 10),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '${Fmt.cantidad(cantidad, alimento.unidad)} · '
                '${alimento.fuente.etiqueta}',
                style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
