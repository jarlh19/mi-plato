# ADR-0001: El veredicto nutricional lo calculan reglas fijas, no el modelo

## Estado
Aceptada

## Fecha
2026-09-01

## Contexto

La app hace dos cosas distintas con una foto de comida:

1. **Reconocer**: qué alimentos hay en el plato y cuánto pesa cada porción.
2. **Juzgar**: si eso encaja con el IMC y el objetivo de quien lo come, y por
   qué.

La primera solo la puede hacer un modelo de visión. La segunda podría hacerla
también el modelo — bastaba con pasarle el perfil y pedirle el consejo en la
misma llamada, ahorrando código.

Restricciones que pesan:

- El consejo se muestra como si fuera una evaluación de salud. Quien lo lee va
  a tomar decisiones sobre lo que come.
- Dos fotos idénticas deben producir el mismo veredicto. Si el consejo cambia
  entre ejecuciones, deja de ser información y pasa a ser ruido.
- Cuando alguien pregunte "¿por qué me dice que el sodio está alto?", tiene que
  haber una respuesta que no sea "porque lo dijo el modelo".

## Decisión

El modelo devuelve **solo datos**: nombre del alimento, gramos estimados y
confianza. Todo juicio —IMC, gasto energético, meta diaria, pros y contras— lo
calculan funciones puras de Dart en `lib/datos/nutricion/`, con umbrales
tomados de fuentes citadas en el código (OMS, Mifflin-St Jeor, Dietary
Guidelines).

Los números nutricionales tampoco los pone el modelo cuando hay alternativa:
salen de USDA FoodData Central, y la estimación del modelo queda de reserva
marcada como tal en la interfaz (`FuenteDatos`).

## Alternativas consideradas

### Pedir el veredicto completo al modelo en la misma llamada
- A favor: menos código, redacción más natural, un solo viaje de red.
- En contra: no es reproducible, no es auditable, y un error de razonamiento
  sobre datos de salud no deja rastro para diagnosticarlo. La salida del modelo
  es entrada no confiable (OWASP LLM05), y aquí la estaríamos convirtiendo
  directamente en consejo médico.
- Rechazada.

### Modelo para el veredicto, reglas solo como validación posterior
- A favor: texto más rico, con una red de seguridad.
- En contra: si las reglas ya deciden qué es aceptable, el modelo solo aporta
  la redacción, y a cambio duplica el coste y añade una fuente de variación.
- Rechazada por no compensar.

## Consecuencias

- Cada frase del veredicto se puede rastrear hasta un umbral concreto en
  `veredicto.dart`, y está cubierta por tests.
- El texto es más seco que el que escribiría un modelo. Es un precio aceptado.
- Añadir una regla nueva es escribir una función y su test, no reescribir un
  prompt. Ver `code-review`: la lógica vive en la capa que la posee.
- Si algún día se quisiera texto más natural, el sitio para hacerlo es la
  redacción de un punto ya decidido, nunca la decisión.
