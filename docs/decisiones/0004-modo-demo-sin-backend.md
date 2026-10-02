# ADR-0004: La app arranca en modo demo cuando faltan credenciales

## Estado
Aceptada

## Fecha
2026-09-01

## Contexto

Para ver funcionar esta app hacen falta un proyecto de Supabase, un esquema
ejecutado, una clave de Anthropic y opcionalmente una de FoodData Central. Es
mucho antes del primer `flutter run`, tanto para quien retoma el proyecto como
para enseñárselo a alguien.

## Decisión

Sin `SUPABASE_URL` y `SUPABASE_ANON_KEY`, la app entra en **modo demo**: los
repositorios se resuelven a implementaciones en memoria, el reconocimiento de
foto devuelve un plato de ejemplo fijo, y una cuenta de prueba llega sembrada
con una semana de comidas y pesajes.

Un único punto decide qué implementación se usa (`lib/estado/providers.dart`),
comparando contra `Config.hayBackend`.

## Alternativas consideradas

### Fallar al arrancar si faltan credenciales
- A favor: imposible confundir demo con producción.
- En contra: nadie puede mirar la app sin montar una cuenta de Supabase.
- Rechazada.

### Datos de ejemplo pero análisis real de foto
- A favor: se probaría lo más interesante.
- En contra: sigue exigiendo la clave de pago, que es justo la barrera que se
  quería quitar.
- Rechazada.

## Consecuencias

- La interfaz entera se puede recorrer y probar en cualquier máquina con
  Flutter y nada más.
- **Riesgo asumido**: confundir el modo demo con la app real. Se mitiga con un
  banner permanente en la parte superior y con un aviso explícito en el
  resultado de cada análisis simulado ("no se analizó tu foto").
- Las implementaciones en memoria son también los dobles de los tests, así que
  el coste de mantenerlas se amortiza.
- Contrapartida real: cada método nuevo de un repositorio hay que escribirlo
  dos veces. Es el precio de que la app arranque sin nada.
