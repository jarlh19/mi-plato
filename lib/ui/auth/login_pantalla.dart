import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../datos/repos/memoria.dart';
import '../../estado/providers.dart';
import '../comun/widgets.dart';

class LoginPantalla extends ConsumerStatefulWidget {
  const LoginPantalla({super.key});

  @override
  ConsumerState<LoginPantalla> createState() => _LoginPantallaEstado();
}

class _LoginPantallaEstado extends ConsumerState<LoginPantalla> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _clave = TextEditingController();

  bool _registrando = false;
  bool _ocupado = false;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _ocupado = true);
    try {
      final sesion = ref.read(sesionProvider.notifier);
      if (_registrando) {
        await sesion.registrar(
          nombre: _nombre.text,
          email: _email.text,
          clave: _clave.text,
        );
      } else {
        await sesion.iniciarSesion(_email.text, _clave.text);
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _entrarDemo() async {
    setState(() => _ocupado = true);
    try {
      await ref
          .read(sesionProvider.notifier)
          .iniciarSesion(AlmacenMemoria.emailDemo, 'demo1234');
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 56,
                      color: esquema.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      Config.nombreApp,
                      style: t.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fotografía tu plato y mira cómo encaja en tu día.',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(
                        color: esquema.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_registrando) ...[
                      TextFormField(
                        controller: _nombre,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Escribe tu nombre'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Correo'),
                      validator: (v) => (v ?? '').contains('@')
                          ? null
                          : 'Escribe un correo válido',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _clave,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                      validator: (v) =>
                          (v ?? '').length < 6 ? 'Mínimo 6 caracteres' : null,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _ocupado ? null : _enviar,
                      child: _ocupado
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_registrando ? 'Crear cuenta' : 'Entrar'),
                    ),
                    TextButton(
                      onPressed: _ocupado
                          ? null
                          : () => setState(() => _registrando = !_registrando),
                      child: Text(
                        _registrando
                            ? 'Ya tengo cuenta'
                            : 'Crear una cuenta nueva',
                      ),
                    ),
                    if (Config.modoDemo) ...[
                      const Divider(height: 32),
                      Text(
                        'Sin Supabase configurado. Puedes recorrer la app con '
                        'una cuenta de ejemplo que ya tiene una semana de '
                        'registros.',
                        textAlign: TextAlign.center,
                        style: t.bodySmall?.copyWith(
                          color: esquema.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _ocupado ? null : _entrarDemo,
                        icon: const Icon(Icons.science_outlined),
                        label: const Text('Entrar en modo demo'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
