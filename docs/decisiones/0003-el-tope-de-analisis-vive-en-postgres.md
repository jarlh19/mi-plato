# ADR-0003: El tope diario de análisis se cuenta en Postgres

## Estado
Aceptada

## Fecha
2026-09-01

## Contexto

Cada análisis de foto es una llamada de pago al modelo, del orden de un céntimo
de dólar. Sin ningún tope, tres cosas corrientes vacían la cuenta: una sesión
robada, un bucle en el cliente, o alguien con curiosidad y un `curl`.

Es el riesgo LLM10 (consumo ilimitado) de OWASP, y en este proyecto es también
la única parte que puede costar dinero de verdad.

## Decisión

El contador vive en la tabla `analisis_uso` y se incrementa desde la función
`consumir_cuota_analisis()`, que la Edge Function llama antes de tocar el
modelo. El límite es una **constante dentro de la función SQL**, no un
argumento.

## Alternativas consideradas

### Contador en memoria de la Edge Function
- A favor: cero infraestructura.
- En contra: las funciones son efímeras y se escalan en varias instancias; cada
  una tendría su propio contador y el tope real sería el límite multiplicado
  por el número de instancias.
- Rechazada.

### Límite como parámetro del RPC, decidido por la Edge Function
- A favor: cambiar el tope sin migrar la base.
- En contra: `authenticated` puede llamar al RPC directamente. Un parámetro es
  una sugerencia, no un control: bastaría `rpc('consumir_cuota_analisis', {limite: 999999})`.
- Rechazada. El control tiene que estar del lado que el cliente no puede
  reescribir.

### Rate limiting por IP en una pasarela
- A favor: frena también a quien no tiene cuenta.
- En contra: la función ya exige JWT válido, así que no hay tráfico anónimo que
  frenar; y una IP compartida penalizaría a varias personas a la vez.
- Descartada por ahora; sería la capa siguiente si apareciera abuso con muchas
  cuentas creadas a propósito.

## Consecuencias

- El tope se cambia editando `schema.sql` y volviendo a ejecutar la función.
- El `select ... for update` serializa dos fotos simultáneas de la misma
  persona; sin él ambas leerían el mismo valor y las dos pasarían.
- Al agotarse la cuota la app no se queda muerta: se puede seguir registrando a
  mano desde la tabla local, que no cuesta nada.
