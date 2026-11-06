import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mi_plato/datos/repos/repos.dart';
import 'package:mi_plato/datos/repos/supabase_repos.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Borrar la cuenta tiene que llevarse **todas** las fotos. Storage devuelve
/// como mucho 100 archivos por listado: quien guardó más y borra su cuenta no
/// puede quedarse con fotos de lo que come sin dueño que las borre.
///
/// El Storage de aquí es falso pero responde como el real: lista por páginas
/// con `limit` y `offset`, y borra lo que le llega en `prefixes`.
class StorageFalso {
  StorageFalso(this.perfilId, int cuantas)
    : archivos = {for (var i = 0; i < cuantas; i++) '$perfilId/foto-$i.jpg'};

  final String perfilId;
  final Set<String> archivos;

  /// Apagado, el DELETE responde bien pero no borra nada.
  bool borra = true;

  late final cliente = MockClient((pedido) async {
    final cuerpo = jsonDecode(pedido.body) as Map<String, dynamic>;
    if (pedido.method == 'POST' &&
        pedido.url.path.endsWith('/object/list/comidas')) {
      final prefijo = cuerpo['prefix'] as String;
      final limite = (cuerpo['limit'] as num?)?.toInt() ?? 100;
      final desde = (cuerpo['offset'] as num?)?.toInt() ?? 0;
      final nombres =
          archivos
              .where((r) => r.startsWith('$prefijo/'))
              .map((r) => r.substring(prefijo.length + 1))
              .toList()
            ..sort();
      final pagina = nombres.skip(desde).take(limite);
      return http.Response(
        jsonEncode([
          for (final n in pagina) {'name': n, 'id': n},
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (pedido.method == 'DELETE' &&
        pedido.url.path.endsWith('/object/comidas')) {
      final rutas = (cuerpo['prefixes'] as List).cast<String>();
      if (borra) archivos.removeAll(rutas);
      return http.Response(
        jsonEncode([
          for (final r in rutas) {'name': r},
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('no esperado: ${pedido.method} ${pedido.url}', 404);
  });

  SbFotosRepo repo() => SbFotosRepo(
    SupabaseClient(
      'http://storage.falso',
      'clave-anon-de-prueba',
      httpClient: cliente,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
  );
}

void main() {
  test('borrar todas las fotos se lleva más de una página', () async {
    final storage = StorageFalso('perfil-1', 250);
    await storage.repo().eliminarTodas('perfil-1');
    expect(
      storage.archivos,
      isEmpty,
      reason: 'quedaron ${storage.archivos.length} fotos',
    );
  });

  test('con pocas fotos también borra todas', () async {
    final storage = StorageFalso('perfil-1', 3);
    await storage.repo().eliminarTodas('perfil-1');
    expect(storage.archivos, isEmpty);
  });

  test('sin fotos no falla', () async {
    final storage = StorageFalso('perfil-1', 0);
    await storage.repo().eliminarTodas('perfil-1');
    expect(storage.archivos, isEmpty);
  });

  test('no toca las fotos de otra persona', () async {
    final storage = StorageFalso('perfil-1', 120)
      ..archivos.addAll({'perfil-2/foto-0.jpg', 'perfil-2/foto-1.jpg'});
    await storage.repo().eliminarTodas('perfil-1');
    expect(storage.archivos, {'perfil-2/foto-0.jpg', 'perfil-2/foto-1.jpg'});
  });

  test(
    'si Storage no borra, corta con un error y no da vueltas para siempre',
    () async {
      final storage = StorageFalso('perfil-1', 150)..borra = false;
      await expectLater(
        storage.repo().eliminarTodas('perfil-1'),
        throwsA(isA<ErrorApp>()),
      );
      expect(storage.archivos, hasLength(150));
    },
  );
}
