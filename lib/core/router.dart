import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../datos/modelos/modelos.dart';
import '../estado/providers.dart';
import '../ui/auth/login_pantalla.dart';
import '../ui/auth/perfil_inicial_pantalla.dart';
import '../ui/camara/revision_pantalla.dart';
import '../ui/diario/inicio_pantalla.dart';

/// Puente entre Riverpod y go_router: cada cambio de sesión reevalúa el
/// `redirect`, así entrar, salir o completar el perfil mueve la app sola a la
/// pantalla correcta.
class _RefrescoSesion extends ChangeNotifier {
  _RefrescoSesion(Ref ref) {
    ref.listen<Perfil?>(sesionProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresco = _RefrescoSesion(ref);
  ref.onDispose(refresco.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresco,
    redirect: (context, estado) {
      final perfil = ref.read(sesionProvider);
      final ruta = estado.matchedLocation;
      final enLogin = ruta == '/login';
      final enOnboarding = ruta == '/perfil';

      if (perfil == null) return enLogin ? null : '/login';

      // Sin altura, peso ni objetivo no hay IMC ni meta que calcular, así que
      // el onboarding es obligatorio antes de tocar nada más.
      if (!perfil.perfilCompleto) return enOnboarding ? null : '/perfil';

      if (enLogin || enOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPantalla()),
      GoRoute(path: '/perfil', builder: (_, _) => const PerfilInicialPantalla()),
      GoRoute(
        path: '/',
        builder: (_, _) => const InicioPantalla(),
        routes: [
          GoRoute(path: 'revisar', builder: (_, _) => const RevisionPantalla()),
        ],
      ),
      GoRoute(
        path: '/progreso',
        builder: (_, _) => const InicioPantalla(pestanaInicial: 1),
      ),
      GoRoute(
        path: '/ajustes',
        builder: (_, _) => const InicioPantalla(pestanaInicial: 2),
      ),
    ],
  );
});
