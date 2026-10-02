import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../datos/modelos/modelos.dart';
import '../../datos/nutricion/calculos.dart';
import '../../datos/nutricion/veredicto.dart';

/// Formulario de datos personales, compartido por el onboarding y los ajustes.
///
/// Recalcula el IMC y la meta a cada cambio: ver cómo se mueven las calorías
/// al tocar el nivel de actividad explica el cálculo mejor que un párrafo.
class FormularioPerfil extends StatefulWidget {
  const FormularioPerfil({
    super.key,
    required this.inicial,
    required this.onGuardar,
    this.textoBoton = 'Guardar',
  });

  final Perfil inicial;
  final Future<void> Function(Perfil perfil) onGuardar;
  final String textoBoton;

  @override
  State<FormularioPerfil> createState() => _FormularioPerfilEstado();
}

class _FormularioPerfilEstado extends State<FormularioPerfil> {
  final _form = GlobalKey<FormState>();
  late Perfil _perfil = widget.inicial;
  late final _edad = TextEditingController(text: '${widget.inicial.edad}');
  late final _altura =
      TextEditingController(text: _sinCola(widget.inicial.alturaCm));
  late final _peso = TextEditingController(text: _sinCola(widget.inicial.pesoKg));
  bool _ocupado = false;

  static String _sinCola(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    _edad.dispose();
    _altura.dispose();
    _peso.dispose();
    super.dispose();
  }

  /// Vuelca los tres campos numéricos sobre el perfil. Se llama en cada
  /// pulsación para que la vista previa vaya al día.
  void _sincronizar() {
    setState(() {
      _perfil = _perfil.copiar(
        edad: int.tryParse(_edad.text) ?? _perfil.edad,
        alturaCm: double.tryParse(_altura.text.replaceAll(',', '.')) ??
            _perfil.alturaCm,
        pesoKg:
            double.tryParse(_peso.text.replaceAll(',', '.')) ?? _perfil.pesoKg,
      );
    });
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _ocupado = true);
    try {
      await widget.onGuardar(_perfil.copiar(perfilCompleto: true));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  String? _validarNumero(String? v, {required double min, required double max}) {
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (n == null) return 'Escribe un número';
    if (n < min || n > max) return 'Entre ${_sinCola(min)} y ${_sinCola(max)}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sexo', style: t.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<Sexo>(
            segments: const [
              ButtonSegment(value: Sexo.femenino, label: Text('Mujer')),
              ButtonSegment(value: Sexo.masculino, label: Text('Hombre')),
            ],
            selected: {_perfil.sexo},
            onSelectionChanged: (s) =>
                setState(() => _perfil = _perfil.copiar(sexo: s.first)),
          ),
          const SizedBox(height: 6),
          Text(
            'La fórmula del gasto energético usa un término distinto según el '
            'sexo asignado al nacer; es lo único para lo que se usa este dato.',
            style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _edad,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Edad'),
                  onChanged: (_) => _sincronizar(),
                  validator: (v) => _validarNumero(v, min: 14, max: 100),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _altura,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Altura',
                    suffixText: 'cm',
                  ),
                  onChanged: (_) => _sincronizar(),
                  validator: (v) => _validarNumero(v, min: 120, max: 230),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _peso,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Peso',
                    suffixText: 'kg',
                  ),
                  onChanged: (_) => _sincronizar(),
                  validator: (v) => _validarNumero(v, min: 30, max: 300),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Nivel de actividad', style: t.titleSmall),
          const SizedBox(height: 4),
          for (final nivel in NivelActividad.values)
            ListTile(
              onTap: () =>
                  setState(() => _perfil = _perfil.copiar(actividad: nivel)),
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                _perfil.actividad == nivel
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: _perfil.actividad == nivel
                    ? esquema.primary
                    : esquema.outline,
              ),
              title: Text(nivel.etiqueta),
              subtitle: Text(nivel.detalle, style: t.bodySmall),
            ),
          const SizedBox(height: 16),
          Text('Objetivo', style: t.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<Objetivo>(
            segments: [
              for (final o in Objetivo.values)
                ButtonSegment(value: o, label: Text(o.etiqueta)),
            ],
            selected: {_perfil.objetivo},
            showSelectedIcon: false,
            onSelectionChanged: (s) =>
                setState(() => _perfil = _perfil.copiar(objetivo: s.first)),
          ),
          const SizedBox(height: 22),
          Text('¿Algo que tener en cuenta?', style: t.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Endurece los topes de sodio, azúcar o grasa saturada. Opcional.',
            style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in Condicion.values)
                FilterChip(
                  label: Text(c.etiqueta),
                  selected: _perfil.condiciones.contains(c),
                  onSelected: (activo) => setState(() {
                    final nuevas = {..._perfil.condiciones};
                    activo ? nuevas.add(c) : nuevas.remove(c);
                    _perfil = _perfil.copiar(condiciones: nuevas);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          VistaPreviaMeta(perfil: _perfil),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _ocupado ? null : _guardar,
            child: _ocupado
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.textoBoton),
          ),
        ],
      ),
    );
  }
}

/// Resumen de lo que sale de los datos introducidos: IMC, gasto y meta.
class VistaPreviaMeta extends StatelessWidget {
  const VistaPreviaMeta({super.key, required this.perfil});

  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final meta = metaDiaria(perfil);
    final lectura = lecturaImc(perfil);
    final color = Tema.severidad(
      context,
      switch (lectura.nivel) {
        Severidad.bueno => Tema.bueno,
        Severidad.aviso => Tema.aviso,
        Severidad.malo => Tema.malo,
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Con estos datos', style: t.titleSmall),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.monitor_weight_outlined, size: 20, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IMC ${lectura.titulo}',
                          style: t.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text(lectura.detalle,
                          style: t.bodySmall
                              ?.copyWith(color: esquema.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _Linea('Gasto estimado del día', Fmt.kcal(meta.gasto)),
            _Linea('Tu meta', Fmt.kcal(meta.kcal)),
            _Linea('Proteína', Fmt.gramos(meta.proteina)),
            _Linea('Carbohidratos', Fmt.gramos(meta.carbohidratos)),
            _Linea('Grasa', Fmt.gramos(meta.grasa)),
            if (meta.deficit.abs() > 20)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  meta.deficit > 0
                      ? 'Un déficit de ${Fmt.kcal(meta.deficit)} al día: '
                          'alrededor de ${meta.ritmoSemanalKg.toStringAsFixed(2)} '
                          'kg por semana si se cumple.'
                      : 'Un superávit de ${Fmt.kcal(-meta.deficit)} al día '
                          'para ganar masa poco a poco.',
                  style: t.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(etiqueta,
                style: t.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Text(valor,
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
