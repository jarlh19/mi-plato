import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../estado/providers.dart';
import '../comun/widgets.dart';
import 'formulario_perfil.dart';

/// Onboarding. Sin altura, peso, edad y objetivo no hay IMC ni meta diaria, así
/// que esta pantalla es obligatoria antes de entrar al diario.
class PerfilInicialPantalla extends ConsumerWidget {
  const PerfilInicialPantalla({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(sesionProvider);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    if (perfil == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cuéntanos de ti')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Hola, ${perfil.nombre.split(' ').first}',
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Con estos datos se calculan tu IMC, lo que gastas al día y la meta '
            'contra la que se compara cada plato. Puedes cambiarlos cuando '
            'quieras desde Ajustes.',
            style: t.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FormularioPerfil(
            inicial: perfil,
            textoBoton: 'Empezar',
            onGuardar: (nuevo) async {
              try {
                await ref.read(sesionProvider.notifier).guardar(nuevo);
                // El peso inicial abre el historial: sin él la pantalla de
                // progreso arranca vacía y no hay con qué comparar.
                await ref
                    .read(diarioRepoProvider)
                    .registrarPeso(nuevo.id, nuevo.pesoKg);
                if (context.mounted) refrescarTodo(ref);
              } catch (e) {
                if (context.mounted) mostrarError(context, e);
              }
            },
          ),
        ],
      ),
    );
  }
}
