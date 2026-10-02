# ADR-0002: Los alimentos se guardan dentro de la comida, no en una tabla aparte

## Estado
Aceptada

## Fecha
2026-09-01

## Contexto

Una comida contiene varios alimentos, cada uno con nombre, gramos y valores
nutricionales por 100 g. El modelo relacional obvio sería una tabla `alimentos`
con clave foránea a `comidas`, y quizá un catálogo `alimentos_base` normalizado
al que apuntaran las filas.

El detalle que rompe ese modelo: los valores nutricionales cambian. USDA
corrige fichas, la tabla local se afina, y el modelo estima distinto la misma
comida en dos momentos.

## Decisión

Los alimentos viven en una columna `jsonb` dentro de `comidas`, con sus valores
por 100 g copiados en el momento del registro.

## Alternativas consideradas

### Tabla `alimentos` con FK a `comidas`
- A favor: consultas SQL agregadas directas ("proteína media del mes").
- En contra: no resuelve el problema de fondo, solo lo mueve; habría que
  duplicar igualmente los valores para congelarlos.
- Rechazada por no aportar sobre el jsonb.

### Catálogo normalizado + referencia desde la comida
- A favor: sin duplicación, corregir una ficha corrige todo el historial.
- En contra: **corregir una ficha corrige todo el historial**. El desayuno de
  hace tres meses cambiaría de calorías al actualizar la base, y el gráfico de
  progreso se reescribiría solo. Un diario tiene que decir lo que se registró.
- Rechazada.

## Consecuencias

- Una comida guardada es inmutable frente a cambios en las fuentes de datos.
- El campo `referencia` (`usda:173410`, `local:arroz-blanco-cocido`) conserva de
  dónde salió cada cifra, para poder auditarla sin depender de ella.
- Los totales por día se agregan en el cliente y no en SQL, porque sumar dentro
  de un jsonb exigiría desarmar el array en Postgres. Con siete días de comidas
  eso cabe de sobra en memoria; si algún día se quisieran informes de meses,
  ese es el punto que habría que revisar (una vista materializada, no un cambio
  de modelo).
