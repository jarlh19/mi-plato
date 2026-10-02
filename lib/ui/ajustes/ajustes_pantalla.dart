import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../estado/providers.dart';
import '../auth/formulario_perfil.dart';
import '../comun/widgets.dart';

/// Ajustes: los mismos datos del onboarding, editables, el control de los datos
/// personales y el aviso de qué es y qué no es esta app.
class AjustesPantalla extends ConsumerWidget {
  const AjustesPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(sesionProvider);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    if (perfil == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          perfil.nombre,
          style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        FormularioPerfil(
          inicial: perfil,
          textoBoton: 'Guardar cambios',
          onGuardar: (nuevo) async {
            try {
              await ref.read(sesionProvider.notifier).guardar(nuevo);
              // Si cambió el peso, entra también en el historial: si no, la
              // curva de progreso se queda desfasada respecto al perfil.
              if (nuevo.pesoKg != perfil.pesoKg) {
                await ref
                    .read(diarioRepoProvider)
                    .registrarPeso(nuevo.id, nuevo.pesoKg);
              }
              if (!context.mounted) return;
              refrescarTodo(ref);
              mostrarAviso(context, 'Datos actualizados');
            } catch (e) {
              if (context.mounted) mostrarError(context, e);
            }
          },
        ),
        const Divider(height: 40),
        const _TusDatos(),
        const Divider(height: 40),
        Text(
          'Esta app orienta, no diagnostica. Las calorías salen de estimar una '
          'porción a partir de una foto, con un error habitual del 20-30%, y '
          'los límites son recomendaciones generales de la OMS para población '
          'adulta sana. Si tienes una condición médica o sigues un tratamiento, '
          'la pauta la marca tu profesional de salud.',
          style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => ref.read(sesionProvider.notifier).cerrarSesion(),
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
  }
}

/// Control sobre los datos personales.
///
/// Esto guarda datos de salud: qué come alguien, cuánto pesa, qué condiciones
/// declara. Quien los genera tiene que poder llevárselos y borrarlos, y ambas
/// cosas tienen que funcionar de verdad, no ser una casilla en una política.
class _TusDatos extends ConsumerStatefulWidget {
  const _TusDatos();

  @override
  ConsumerState<_TusDatos> createState() => _TusDatosEstado();
}

class _TusDatosEstado extends ConsumerState<_TusDatos> {
  bool _ocupado = false;

  Future<void> _exportar() async {
    setState(() => _ocupado = true);
    String json;
    try {
      json = await exportarDatos(ref);
    } catch (e) {
      if (mounted) mostrarError(context, e);
      return;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
    if (!mounted) return;

    // Se enseña el JSON en vez de mandarlo directo al portapapeles: copiar
    // puede fallar (el navegador deniega el permiso si la pestaña no tiene el
    // foco) y entonces la persona se quedaría sin sus datos y sin saber por
    // qué. Aquí siempre están en pantalla y se pueden seleccionar a mano.
    await showDialog<void>(
      context: context,
      builder: (d) => _DialogoExportado(json: json),
    );
  }

  Future<void> _borrarCuenta() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Borrar tu cuenta?'),
        content: const Text(
          'Se borran tu perfil, todas tus comidas, tus fotos y tu historial de '
          'peso. No hay forma de recuperarlos.\n\n'
          'Si quieres conservar el historial, expórtalo antes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(d).colorScheme.error,
              foregroundColor: Theme.of(d).colorScheme.onError,
            ),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await ref.read(sesionProvider.notifier).borrarCuenta();
      // Sin sesión, el router lleva solo a la pantalla de entrada.
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tus datos', style: t.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Tu diario y tu peso son datos de salud. Solo tú puedes verlos: las '
          'fotos están en un almacén privado y nadie más consulta tus registros.',
          style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _ocupado ? null : _exportar,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Exportar mis datos'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _ocupado ? null : _borrarCuenta,
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('Borrar mi cuenta y mis datos'),
          style: OutlinedButton.styleFrom(foregroundColor: esquema.error),
        ),
      ],
    );
  }
}

/// Muestra el volcado y ofrece copiarlo. Si el portapapeles falla, el texto
/// sigue ahí: seleccionable y completo.
class _DialogoExportado extends StatefulWidget {
  const _DialogoExportado({required this.json});

  final String json;

  @override
  State<_DialogoExportado> createState() => _DialogoExportadoEstado();
}

class _DialogoExportadoEstado extends State<_DialogoExportado> {
  /// Resultado del último intento de copia. Va dentro del diálogo y no en un
  /// SnackBar porque este se dibuja detrás de la barrera modal: el aviso que
  /// hace falta leer quedaba tapado justo cuando importaba.
  String _aviso = '';

  Future<void> _copiar() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.json));
      if (!mounted) return;
      final mensajero = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      mensajero
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Copiado al portapapeles')),
        );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _aviso =
            'Tu navegador no dejó copiar. Selecciona el texto de arriba y '
            'cópialo a mano.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kb = (widget.json.length / 1024).toStringAsFixed(1);
    final esquema = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Tus datos'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$kb KB en formato JSON.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.json,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
            if (_aviso.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _aviso,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: esquema.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: _copiar,
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('Copiar'),
        ),
      ],
    );
  }
}
