import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config.dart';
import '../../estado/providers.dart';
import '../ajustes/ajustes_pantalla.dart';
import '../comun/widgets.dart';
import '../progreso/progreso_pantalla.dart';
import 'diario_pantalla.dart';

/// Carcasa de la app: las tres pestañas y el botón de registrar una comida.
class InicioPantalla extends ConsumerStatefulWidget {
  const InicioPantalla({super.key, this.pestanaInicial = 0});

  final int pestanaInicial;

  @override
  ConsumerState<InicioPantalla> createState() => _InicioPantallaEstado();
}

class _InicioPantallaEstado extends ConsumerState<InicioPantalla> {
  late int _pestana = widget.pestanaInicial;

  Future<void> _tomarFoto(ImageSource origen) async {
    try {
      final archivo = await ImagePicker().pickImage(
        source: origen,
        // Se reduce antes de subir: el modelo no gana nada con más resolución
        // y una foto de 4 MB tarda y cuesta más en cada análisis.
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      if (!mounted) return;

      // Se lanza el análisis y se navega enseguida: la pantalla de revisión ya
      // sabe pintar el estado de carga.
      ref.read(borradorProvider.notifier).analizar(bytes);
      if (mounted) context.push('/revisar');
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  void _abrirOpciones() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (hoja) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto del plato'),
              onTap: () {
                Navigator.pop(hoja);
                _tomarFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(hoja);
                _tomarFoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Añadir a mano'),
              subtitle: const Text('Sin foto, buscando en la tabla'),
              onTap: () {
                Navigator.pop(hoja);
                ref.read(borradorProvider.notifier).empezarAMano();
                context.push('/revisar');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (Config.modoDemo) const AvisoDemo(),
          Expanded(
            child: IndexedStack(
              index: _pestana,
              children: const [
                DiarioPantalla(),
                ProgresoPantalla(),
                AjustesPantalla(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _pestana == 0
          ? FloatingActionButton.extended(
              onPressed: _abrirOpciones,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Registrar comida'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: (i) => setState(() => _pestana = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Diario',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Progreso',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
