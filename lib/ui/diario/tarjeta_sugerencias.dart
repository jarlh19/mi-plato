import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../datos/repos/repos.dart';
import '../../datos/nutricion/sugerencias.dart';
import '../../estado/providers.dart';

/// Qué comer en lo que queda del día.
///
/// El hueco lo calcula la app y se enseña siempre; las propuestas concretas las
/// pide la persona pulsando, porque cuestan dinero y no sirven de nada si nadie
/// las va a leer.
class TarjetaSugerencias extends ConsumerWidget {
  const TarjetaSugerencias({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hueco = ref.watch(huecoProvider);
    final estado = ref.watch(sugerenciasProvider);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    if (hueco == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Qué te falta comer', style: t.titleSmall),
            const SizedBox(height: 6),
            Text(
              _resumenDelHueco(hueco),
              style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (!hueco.hayHueco)
              Text(
                hueco.kcal < 100
                    ? 'Ya cubriste tu meta de hoy. Sugerirte más comida sería '
                        'empujarte a pasarte.'
                    : 'No queda ninguna comida por registrar hoy.',
                style: t.bodyMedium,
              )
            else
              estado.when(
                loading: () => const _Cargando(),
                error: (e, _) => _Error(
                  mensaje: e is ErrorApp ? e.mensaje : 'No se pudo generar.',
                  onReintentar: () =>
                      ref.read(sugerenciasProvider.notifier).generar(),
                ),
                data: (s) => s == null
                    ? _Boton(
                        onPulsar: () =>
                            ref.read(sugerenciasProvider.notifier).generar(),
                      )
                    : _Resultado(
                        sugerencias: s,
                        onOtra: () =>
                            ref.read(sugerenciasProvider.notifier).generar(),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

String _resumenDelHueco(HuecoDelDia h) {
  if (h.kcal < 0) {
    return 'Te pasaste ${Fmt.kcal(-h.kcal)} de tu meta de hoy.';
  }
  // Dos frases y no una lista pegada con "y": lo que queda y lo que falta son
  // cosas distintas, y encadenarlas daba "faltan X y faltan Y".
  final faltan = <String>[
    if (h.proteina >= 10) '${Fmt.gramos(h.proteina)} de proteína',
    if (h.fibra >= 5) '${Fmt.gramos(h.fibra)} de fibra',
  ];
  final quedan = 'Te quedan ${Fmt.kcal(h.kcal)} para hoy';
  if (faltan.isEmpty) return '$quedan.';
  return '$quedan. Te faltan ${faltan.join(' y ')}.';
}

class _Boton extends StatelessWidget {
  const _Boton({required this.onPulsar});

  final VoidCallback onPulsar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonalIcon(
          onPressed: onPulsar,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Sugerir con IA'),
        ),
        const SizedBox(height: 6),
        Text(
          'Propone el modelo; lo que no encaja con tus topes no se muestra.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Buscando qué te encaja...'),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          mensaje,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: esquema.error,
              ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onReintentar,
          child: const Text('Reintentar'),
        ),
      ],
    );
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado({required this.sugerencias, required this.onOtra});

  final Sugerencias sugerencias;
  final VoidCallback onOtra;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final descartadas = sugerencias.descartadas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sugerencias.nota.isNotEmpty) ...[
          Text(
            sugerencias.nota,
            style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
        ],
        if (sugerencias.vacio)
          Text(
            'Ninguna propuesta encajó con lo que te queda hoy.',
            style: t.bodyMedium,
          )
        else
          for (final s in sugerencias.aceptadas) _Fila(sugerencia: s),

        // Lo descartado se dice, no se esconde: enseñar solo lo que pasó el
        // filtro haría creer que el modelo acierta siempre.
        if (descartadas.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            descartadas.length == 1
                ? 'Se descartó 1 propuesta: ${descartadas.first.rechazo!.etiqueta.toLowerCase()}.'
                : 'Se descartaron ${descartadas.length} propuestas que no '
                    'encajaban con tus topes.',
            style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onOtra,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Otra sugerencia'),
          ),
        ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.sugerencia});

  final Sugerencia sugerencia;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final a = sugerencia.alimento;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  a.nombre,
                  style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Fmt.kcal(a.total.kcal),
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Text(
            '${Fmt.cantidad(a.cantidad, a.unidad)} · '
            '${sugerencia.comida.etiqueta} · '
            '${Fmt.gramos(a.total.proteina)} de proteína',
            style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
          if (sugerencia.porque.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(sugerencia.porque, style: t.bodySmall),
          ],
        ],
      ),
    );
  }
}
