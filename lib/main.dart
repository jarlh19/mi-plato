import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/router.dart';
import 'core/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');

  // Sin credenciales la app corre en modo demo con datos en memoria y un
  // análisis de foto simulado.
  if (Config.hayBackend) {
    await Supabase.initialize(
      url: Config.supabaseUrl,
      publishableKey: Config.supabaseAnonKey,
    );
  }

  runApp(const ProviderScope(child: MiPlatoApp()));
}

class MiPlatoApp extends ConsumerWidget {
  const MiPlatoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: Config.nombreApp,
      debugShowCheckedModeBanner: false,
      theme: Tema.claro(),
      darkTheme: Tema.oscuro(),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
