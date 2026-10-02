import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../datos/modelos/modelos.dart';
import '../../datos/nutricion/tabla_local.dart';

/// Buscador sobre la tabla local, para completar lo que la foto no captó (la
/// bebida, el aceite del sofrito) o registrar sin foto.
///
/// Devuelve el alimento con su porción de referencia; los gramos se afinan
/// después en la pantalla de revisión.
Future<Alimento?> elegirAlimento(BuildContext context) {
  return showModalBottomSheet<Alimento>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (_, controlador) => _Buscador(controlador: controlador),
    ),
  );
}

class _Buscador extends StatefulWidget {
  const _Buscador({required this.controlador});

  final ScrollController controlador;

  @override
  State<_Buscador> createState() => _BuscadorEstado();
}

class _BuscadorEstado extends State<_Buscador> {
  String _texto = '';

  @override
  Widget build(BuildContext context) {
    final resultados = buscarLocal(_texto);
    final t = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Buscar alimento',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _texto = v),
          ),
        ),
        Expanded(
          child: resultados.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nada con ese nombre. La tabla local cubre platos '
                      'comunes; para el resto, la foto reconoce más.',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium
                          ?.copyWith(color: esquema.onSurfaceVariant),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: widget.controlador,
                  itemCount: resultados.length,
                  itemBuilder: (_, i) {
                    final base = resultados[i];
                    final porcion = base.aAlimento();
                    return ListTile(
                      title: Text(base.nombre),
                      subtitle: Text(
                        'Porción de ${Fmt.cantidad(base.porcionTipica, base.unidad)} · '
                        '${Fmt.kcal(porcion.total.kcal)}',
                        style: t.bodySmall,
                      ),
                      trailing: Text(
                        '${base.por100g.kcal.round()} kcal/100 g',
                        style: t.bodySmall
                            ?.copyWith(color: esquema.onSurfaceVariant),
                      ),
                      onTap: () => Navigator.pop(context, porcion),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
