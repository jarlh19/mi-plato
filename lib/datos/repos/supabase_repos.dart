import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/formato.dart';
import '../modelos/modelos.dart';
import '../nutricion/sugerencias.dart';
import 'repos.dart';

/// Implementación real contra Supabase. El esquema está en `supabase/schema.sql`.

Map<String, dynamic> _fila(dynamic e) => Map<String, dynamic>.from(e as Map);

Never _traducir(Object e) {
  if (e is ErrorApp) throw e;
  if (e is AuthException) throw ErrorApp(e.message);
  if (e is PostgrestException) throw ErrorApp(e.message);
  if (e is StorageException) throw ErrorApp(e.message);
  throw ErrorApp('No se pudo conectar. Revisa tu internet.');
}

class SbAuthRepo implements AuthRepo {
  SbAuthRepo(this._c);

  final SupabaseClient _c;
  Perfil? _actual;

  @override
  Perfil? get perfilActual => _actual;

  @override
  Stream<Perfil?> get cambios =>
      _c.auth.onAuthStateChange.asyncMap((evento) async {
        final usuario = evento.session?.user;
        if (usuario == null) {
          _actual = null;
          return null;
        }
        _actual = await _perfilDe(usuario.id);
        return _actual;
      });

  Future<Perfil> _perfilDe(String id) async {
    final fila = await _c.from('perfiles').select().eq('id', id).maybeSingle();
    if (fila == null) throw ErrorApp('Tu perfil aún no está creado.');
    return Perfil.desdeJson(_fila(fila));
  }

  @override
  Future<Perfil> iniciarSesion({
    required String email,
    required String clave,
  }) async {
    try {
      final res = await _c.auth.signInWithPassword(
        email: email.trim(),
        password: clave,
      );
      final id = res.user?.id;
      if (id == null) throw ErrorApp('Correo o contraseña incorrectos.');
      return _actual = await _perfilDe(id);
    } catch (e) {
      _traducir(e);
    }
  }

  @override
  Future<Perfil> registrar({
    required String nombre,
    required String email,
    required String clave,
  }) async {
    try {
      final res = await _c.auth.signUp(
        email: email.trim(),
        password: clave,
        data: {'nombre': nombre},
      );
      final id = res.user?.id;
      if (id == null) {
        throw ErrorApp('Revisa tu correo para confirmar la cuenta.');
      }
      // El trigger `crear_perfil` inserta la fila; la leemos en vez de
      // construirla aquí para arrancar con lo que hay de verdad en la base.
      return _actual = await _perfilDe(id);
    } catch (e) {
      _traducir(e);
    }
  }

  @override
  Future<void> cerrarSesion() async {
    await _c.auth.signOut();
    _actual = null;
  }

  @override
  Future<void> borrarCuenta() async {
    try {
      // El RPC elimina la fila de auth.users; el perfil, las comidas, los
      // pesos y la cuota caen en cascada. Las fotos las borra quien llama,
      // antes de esto: Storage no participa en las cascadas de Postgres.
      await _c.rpc('borrar_mi_cuenta');
      await _c.auth.signOut();
      _actual = null;
    } catch (e) {
      _traducir(e);
    }
  }

  @override
  Future<Perfil> guardarPerfil(Perfil perfil) async {
    try {
      final fila = await _c
          .from('perfiles')
          .update(perfil.aJson()..remove('id'))
          .eq('id', perfil.id)
          .select()
          .single();
      return _actual = Perfil.desdeJson(_fila(fila));
    } catch (e) {
      _traducir(e);
    }
  }
}

class SbDiarioRepo implements DiarioRepo {
  SbDiarioRepo(this._c);

  final SupabaseClient _c;

  @override
  Future<List<Comida>> comidasDe(String perfilId, DateTime dia) async {
    final desde = Fmt.soloFecha(dia);
    final hasta = desde.add(const Duration(days: 1));
    try {
      final filas = await _c
          .from('comidas')
          .select()
          .eq('perfil_id', perfilId)
          .gte('fecha', desde.toUtc().toIso8601String())
          .lt('fecha', hasta.toUtc().toIso8601String())
          .order('fecha');
      return filas.map((f) => Comida.desdeJson(_fila(f))).toList();
    } catch (e) {
      _traducir(e);
    }
  }

  @override
  Future<Comida> guardar(Comida comida) async {
    try {
      final datos = comida.aJson();
      // Con id vacío dejamos que Postgres genere el uuid.
      if (comida.id.isEmpty) datos.remove('id');
      final fila = await _c.from('comidas').upsert(datos).select().single();
      return Comida.desdeJson(_fila(fila));
    } catch (e) {
      _traducir(e);
    }
  }

  @override
  Future<void> eliminar(String comidaId) async {
    try {
      await _c.from('comidas').delete().eq('id', comidaId);
    } catch (e) {
      _traducir(e);
    }
  }

  @override
  Future<List<ResumenDia>> resumen(String perfilId, {int dias = 7}) async {
    final hoy = Fmt.soloFecha(DateTime.now());
    final desde = hoy.subtract(Duration(days: dias - 1));
    try {
      final filas = await _c
          .from('comidas')
          .select()
          .eq('perfil_id', perfilId)
          .gte('fecha', desde.toUtc().toIso8601String())
          .order('fecha');
      final comidas = filas.map((f) => Comida.desdeJson(_fila(f))).toList();

      // Se agrupa en el cliente en vez de en SQL porque los nutrientes viven
      // dentro de un jsonb y sumarlos en Postgres exigiría desarmar el array.
      // Son siete días de comidas: cabe de sobra en memoria.
      return List.generate(dias, (i) {
        final dia = desde.add(Duration(days: i));
        final delDia = comidas
            .where((c) => Fmt.soloFecha(c.fecha) == dia)
            .toList();
        return ResumenDia(
          fecha: dia,
          total: delDia.fold(Nutrientes.cero, (acc, c) => acc + c.total),
          comidas: delDia.length,
        );
      });
    } catch (e) {
      _traducir(e);
    }
  }

  @override
  Future<List<Comida>> todasLasComidas(String perfilId) async {
    try {
      final filas = await _c
          .from('comidas')
          .select()
          .eq('perfil_id', perfilId)
          .order('fecha');
      return filas.map((f) => Comida.desdeJson(_fila(f))).toList();
    } catch (e) {
      _traducir(e);
    }
  }

  @override
  Future<List<RegistroPeso>> pesos(String perfilId) async {
    try {
      final filas = await _c
          .from('pesos')
          .select()
          .eq('perfil_id', perfilId)
          .order('fecha');
      return filas.map((f) => RegistroPeso.desdeJson(_fila(f))).toList();
    } catch (e) {
      _traducir(e);
    }
  }

  @override
  Future<RegistroPeso> registrarPeso(String perfilId, double pesoKg) async {
    try {
      final fila = await _c
          .from('pesos')
          .upsert({
            'perfil_id': perfilId,
            'fecha': Fmt.soloFecha(DateTime.now()).toIso8601String(),
            'peso_kg': pesoKg,
          }, onConflict: 'perfil_id,fecha')
          .select()
          .single();
      return RegistroPeso.desdeJson(_fila(fila));
    } catch (e) {
      _traducir(e);
    }
  }
}

/// Llama a la Edge Function que reconoce el plato.
///
/// El cliente solo manda la imagen: la clave de Anthropic y la de la base
/// nutricional viven como secretos de la función, fuera del alcance del APK.
class SbVisionRepo implements VisionRepo {
  SbVisionRepo(this._c);

  final SupabaseClient _c;

  @override
  Future<AnalisisFoto> analizar({
    required Uint8List foto,
    required String tipoMime,
  }) async {
    try {
      final res = await _c.functions.invoke(
        Config.funcionAnalisis,
        body: {'imagen': base64Encode(foto), 'tipo_mime': tipoMime},
      );
      final datos = res.data;
      if (datos is! Map) {
        throw ErrorApp('El análisis devolvió una respuesta inesperada.');
      }
      final json = Map<String, dynamic>.from(datos);
      if (json['error'] != null) throw ErrorApp(json['error'] as String);

      return AnalisisFoto(
        descripcion: (json['descripcion'] ?? '') as String,
        aviso: (json['aviso'] ?? '') as String,
        alimentos: ((json['alimentos'] ?? const []) as List)
            .map((a) => Alimento.desdeJson(Map<String, dynamic>.from(a as Map)))
            .toList(),
      );
    } on FunctionException catch (e) {
      throw ErrorApp(
        e.details is Map && (e.details as Map)['error'] != null
            ? (e.details as Map)['error'] as String
            : 'No se pudo analizar la foto. Inténtalo de nuevo.',
      );
    } catch (e) {
      _traducir(e);
    }
  }
}

/// Sugerencias de qué comer en lo que queda del día.
///
/// Manda el hueco ya calculado, no el diario entero: el servidor no necesita
/// saber qué comió nadie para proponer, y lo que no se envía no se puede
/// filtrar. Lo que vuelve son propuestas sin evaluar; las reglas de
/// `sugerencias.dart` deciden cuáles se muestran.
class SbSugerenciasRepo implements SugerenciasRepo {
  SbSugerenciasRepo(this._c);

  final SupabaseClient _c;

  @override
  Future<PropuestaSugerencias> sugerir({
    required Perfil perfil,
    required HuecoDelDia hueco,
  }) async {
    try {
      final res = await _c.functions.invoke(
        Config.funcionSugerencias,
        body: {
          'objetivo': perfil.objetivo.name,
          'condiciones': [for (final c in perfil.condiciones) c.name],
          'hueco': {
            'kcal': hueco.kcal.round(),
            'proteina': hueco.proteina.round(),
            'carbohidratos': hueco.carbohidratos.round(),
            'grasa': hueco.grasa.round(),
            'fibra': hueco.fibra.round(),
            'azucar_libre': hueco.azucarLibre.round(),
            'saturada_libre': hueco.saturadaLibre.round(),
            'sodio_libre': hueco.sodioLibre.round(),
          },
          'comidas_pendientes': [
            for (final t in hueco.comidasPendientes) t.name,
          ],
        },
      );
      final datos = res.data;
      if (datos is! Map) {
        throw ErrorApp('Las sugerencias devolvieron una respuesta inesperada.');
      }
      final json = Map<String, dynamic>.from(datos);
      if (json['error'] != null) throw ErrorApp(json['error'] as String);

      return PropuestaSugerencias(
        nota: (json['nota'] ?? '') as String,
        sugerencias: [
          for (final s in (json['sugerencias'] ?? const []) as List)
            _aSugerencia(Map<String, dynamic>.from(s as Map)),
        ],
      );
    } on FunctionException catch (e) {
      throw ErrorApp(
        e.details is Map && (e.details as Map)['error'] != null
            ? (e.details as Map)['error'] as String
            : 'No se pudieron generar sugerencias. Inténtalo de nuevo.',
      );
    } catch (e) {
      _traducir(e);
    }
  }

  Sugerencia _aSugerencia(Map<String, dynamic> j) => Sugerencia(
    alimento: Alimento.desdeJson(
      Map<String, dynamic>.from(j['alimento'] as Map),
    ),
    porque: (j['porque'] ?? '') as String,
    comida: tipoComidaDesde(j['comida'] as String?),
  );
}

/// Fotos de las comidas.
///
/// El bucket es privado: son fotos de lo que alguien come en su casa. Se
/// guarda la ruta, no una URL pública, y para mostrarla se firma un enlace
/// temporal.
class SbFotosRepo implements FotosRepo {
  SbFotosRepo(this._c);

  final SupabaseClient _c;

  @override
  Future<String> subir({
    required String perfilId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final ruta =
        '$perfilId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    try {
      await _c.storage
          .from(Config.bucketFotos)
          .uploadBinary(
            ruta,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$extension'),
          );
      return ruta;
    } catch (e) {
      _traducir(e);
    }
  }

  @override
  Future<void> eliminar(String ruta) async {
    if (ruta.isEmpty) return;
    try {
      await _c.storage.from(Config.bucketFotos).remove([ruta]);
    } catch (e) {
      _traducir(e);
    }
  }

  @override
  Future<void> eliminarTodas(String perfilId) async {
    try {
      final archivos = await _c.storage
          .from(Config.bucketFotos)
          .list(path: perfilId);
      if (archivos.isEmpty) return;
      await _c.storage.from(Config.bucketFotos).remove([
        for (final a in archivos) '$perfilId/${a.name}',
      ]);
    } catch (e) {
      _traducir(e);
    }
  }
}

/// Enlace temporal para ver una foto guardada. Una hora basta: la pantalla se
/// vuelve a construir cada vez que se abre.
Future<String> urlFirmada(SupabaseClient c, String ruta) =>
    c.storage.from(Config.bucketFotos).createSignedUrl(ruta, 3600);
