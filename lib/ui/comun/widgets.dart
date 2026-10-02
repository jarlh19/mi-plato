import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/nutricion/veredicto.dart';
import '../../datos/repos/repos.dart';

/// Muestra un mensaje de error legible. Si viene de la app usamos su texto;
/// cualquier otra cosa se resume para no filtrar detalles técnicos.
void mostrarError(BuildContext context, Object error) {
  final texto = error is ErrorApp
      ? error.mensaje
      : 'Algo salió mal. Inténtalo otra vez.';
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        showCloseIcon: true,
      ),
    );
}

void mostrarAviso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

/// Envoltorio estándar para pintar un AsyncValue sin repetir el when() a mano.
class AsyncVista<T> extends StatelessWidget {
  const AsyncVista({
    super.key,
    required this.valor,
    required this.constructor,
    this.alReintentar,
  });

  final AsyncValue<T> valor;
  final Widget Function(T datos) constructor;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    return valor.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EstadoVacio(
        icono: Icons.cloud_off_outlined,
        titulo: 'No se pudo cargar',
        detalle: e is ErrorApp
            ? e.mensaje
            : 'Revisa tu conexión e inténtalo otra vez.',
        accion: alReintentar == null
            ? null
            : FilledButton.tonal(
                onPressed: alReintentar,
                child: const Text('Reintentar'),
              ),
      ),
      data: constructor,
    );
  }
}

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.detalle = '',
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: t.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: t.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (detalle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                detalle,
                textAlign: TextAlign.center,
                style: t.textTheme.bodyMedium?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (accion != null) ...[const SizedBox(height: 20), accion!],
          ],
        ),
      ),
    );
  }
}

/// Banner permanente que recuerda que no hay backend configurado.
class AvisoDemo extends StatelessWidget {
  const AvisoDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: esquema.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.science_outlined,
            size: 16,
            color: esquema.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modo demo: el análisis de la foto es simulado y nada se guarda.',
              style: TextStyle(
                fontSize: 12,
                color: esquema.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Anillo de calorías del día. El arco se pinta sobre el total de la meta y se
/// pone rojo en cuanto se pasa, que es la única lectura que importa de un
/// vistazo.
class AnilloCalorias extends StatelessWidget {
  const AnilloCalorias({
    super.key,
    required this.consumidas,
    required this.meta,
    this.tamano = 180,
  });

  final double consumidas;
  final double meta;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final fraccion = meta > 0 ? consumidas / meta : 0.0;
    final pasado = fraccion > 1;
    final restante = meta - consumidas;

    // El anillo está pintado en un canvas: para un lector de pantalla no
    // existe. Se anuncia como una frase completa y se excluyen los textos
    // sueltos de dentro, que por separado no dicen nada ("1942", "te quedan").
    return Semantics(
      label: pasado
          ? 'Llevas ${consumidas.round()} kilocalorías de una meta de '
                '${meta.round()}: ${(-restante).round()} de más.'
          : 'Llevas ${consumidas.round()} kilocalorías de una meta de '
                '${meta.round()}. Te quedan ${restante.round()}.',
      excludeSemantics: true,
      child: SizedBox(
        width: tamano,
        height: tamano,
        child: CustomPaint(
          painter: _PintorAnillo(
            fraccion: fraccion.clamp(0.0, 1.0),
            color: pasado
                ? Tema.severidad(context, Tema.malo)
                : esquema.primary,
            fondo: esquema.surfaceContainerHighest,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pasado ? Fmt.kcal(-restante) : Fmt.kcal(restante),
                  style: t.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  pasado ? 'de más' : 'te quedan',
                  style: t.bodyMedium?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${consumidas.round()} / ${meta.round()} kcal',
                  style: t.labelMedium?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorAnillo extends CustomPainter {
  _PintorAnillo({
    required this.fraccion,
    required this.color,
    required this.fondo,
  });

  final double fraccion;
  final Color color;
  final Color fondo;

  @override
  void paint(Canvas lienzo, Size tamano) {
    const grosor = 14.0;
    final centro = tamano.center(Offset.zero);
    final radio = (math.min(tamano.width, tamano.height) - grosor) / 2;
    final rect = Rect.fromCircle(center: centro, radius: radio);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..color = fondo;
    lienzo.drawCircle(centro, radio, base);

    if (fraccion <= 0) return;
    final arco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..color = color;
    // Empieza arriba (-90°) y avanza en sentido horario.
    lienzo.drawArc(rect, -math.pi / 2, 2 * math.pi * fraccion, false, arco);
  }

  @override
  bool shouldRepaint(_PintorAnillo anterior) =>
      anterior.fraccion != fraccion || anterior.color != color;
}

/// Barra de un macronutriente frente a su meta. [esTecho] invierte la lectura:
/// en sodio o azúcar, llenar la barra es malo.
class BarraNutriente extends StatelessWidget {
  const BarraNutriente({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.meta,
    required this.texto,
    this.esTecho = false,
  });

  final String etiqueta;
  final double valor;
  final double meta;
  final String texto;
  final bool esTecho;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final fraccion = meta > 0 ? (valor / meta).clamp(0.0, 1.0) : 0.0;
    final excedido = meta > 0 && valor > meta;

    final color = esTecho
        ? (excedido
              ? Tema.severidad(context, Tema.malo)
              : fraccion > 0.75
              ? Tema.severidad(context, Tema.aviso)
              : esquema.primary)
        : (fraccion >= 0.9
              ? Tema.severidad(context, Tema.bueno)
              : esquema.primary);

    return Semantics(
      // La barra es decorativa; lo que importa es el número frente a la meta,
      // y si es un tope, que se haya pasado.
      label: esTecho
          ? '$etiqueta: $texto${excedido ? ", por encima del tope" : ""}'
          : '$etiqueta: $texto',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(etiqueta, style: t.bodyMedium)),
                Text(
                  texto,
                  style: t.bodyMedium?.copyWith(
                    color: excedido && esTecho
                        ? Tema.severidad(context, Tema.malo)
                        : esquema.onSurfaceVariant,
                    fontWeight: excedido && esTecho ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fraccion,
                minHeight: 8,
                backgroundColor: esquema.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una línea del veredicto: icono de color, frase y por qué importa.
class FilaPunto extends StatelessWidget {
  const FilaPunto({super.key, required this.punto});

  final Punto punto;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final (icono, base) = switch (punto.nivel) {
      Severidad.bueno => (Icons.check_circle_outline, Tema.bueno),
      Severidad.aviso => (Icons.error_outline, Tema.aviso),
      Severidad.malo => (Icons.cancel_outlined, Tema.malo),
    };
    final color = Tema.severidad(context, base);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El icono lleva la severidad; sin etiqueta, un lector de pantalla
          // solo oiría la frase y perdería si juega a favor o en contra.
          Semantics(
            label: switch (punto.nivel) {
              Severidad.bueno => 'A favor',
              Severidad.aviso => 'Ojo',
              Severidad.malo => 'En contra',
            },
            child: Icon(icono, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  punto.texto,
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (punto.detalle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    punto.detalle,
                    style: t.bodySmall?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta con el veredicto completo, separado en a favor y en contra.
class TarjetaVeredicto extends StatelessWidget {
  const TarjetaVeredicto({
    super.key,
    required this.veredicto,
    this.titulo = 'Para tu objetivo',
  });

  final Veredicto veredicto;
  final String titulo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final pros = veredicto.pros;
    final contras = veredicto.contras;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: t.titleSmall),
            const SizedBox(height: 4),
            Text(
              veredicto.resumen,
              style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
            ),
            if (pros.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Encabezado(texto: 'A favor', color: Tema.bueno),
              for (final p in pros) FilaPunto(punto: p),
            ],
            if (contras.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Encabezado(texto: 'En contra', color: Tema.malo),
              for (final p in contras) FilaPunto(punto: p),
            ],
          ],
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        texto.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Tema.severidad(context, color),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
