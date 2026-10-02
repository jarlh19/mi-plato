# ADR-0006: En las sugerencias el modelo propone y las reglas disponen

## Estado
Aceptada

## Fecha
2026-09-29

## Contexto

El ADR-0001 dejó una frontera clara: el modelo identifica comida, y todo juicio
sobre la dieta sale de reglas fijas. Esa decisión se tomó para el veredicto de
un plato ya comido.

Ahora hace falta lo contrario en el tiempo: decir qué **conviene comer** en lo
que queda del día para llegar al objetivo, con un botón explícito de generación
por IA.

Y aquí las reglas solas no bastan. La app tiene una tabla de unos cuarenta
alimentos; un generador que solo elija de ahí repite las mismas tres cosas cada
día y no sirve. Proponer comida es justo donde un modelo aporta algo que una
tabla no: variedad, platos reales de la zona, y una frase que explique por qué
encaja.

Pero una sugerencia de comida es más delicada que un veredicto. El veredicto
describe algo que ya pasó; la sugerencia empuja a una acción. Y quien la lee
declaró en su perfil condiciones como hipertensión o diabetes, que endurecen los
topes.

## Decisión

El modelo **propone**, las reglas **disponen**.

1. El hueco del día —kcal y gramos que faltan, margen hasta cada tope, qué
   comidas quedan por registrar— lo calcula la app en Dart puro
   (`huecoDelDia`). No se le pregunta a nadie y no cuesta nada.
2. La Edge Function manda ese hueco al modelo y recibe platos concretos con sus
   nutrientes por 100 g y una frase de por qué.
3. Antes de que nada llegue a la pantalla, `evaluarSugerencias` contrasta cada
   propuesta contra los topes reales de esa persona. Lo que se pasa de calorías,
   sodio, azúcar o grasa saturada se descarta, y lo que tiene números
   imposibles también.
4. El filtro vive en el provider, no en el widget. Así no existe un camino por
   el que una propuesta se pinte sin haber pasado por las reglas.

Lo descartado se cuenta en la interfaz en vez de desaparecer. Enseñar solo lo
que pasó el filtro daría la impresión de que el modelo acierta siempre.

## Alternativas consideradas

### Solo reglas: elegir de la tabla local lo que mejor tape el hueco
- A favor: gratis, instantáneo, reproducible, sin frontera de confianza nueva.
- En contra: cuarenta alimentos dan para muy poco. A la tercera vez sugiere lo
  mismo y se deja de mirar. Además no sabe combinar dos cosas en un plato.
- Rechazada como única fuente, pero es exactamente lo que hace el modo demo,
  que así funciona sin backend y sin gastar.

### IA libre, mostrando lo que devuelva
- A favor: lo más variado y lo más natural de leer; es lo que hace el generador
  de textos de LeoColombia.
- En contra: una sugerencia que se pasa del tope de sodio de alguien con
  hipertensión sale en pantalla con la misma cara de autoridad que el resto, y
  nada la detecta. El coste de equivocarse no es un texto raro, es un consejo de
  salud malo.
- Rechazada.

### Reglas eligen el alimento, el modelo solo redacta
- A favor: barato y seguro; el modelo no puede colar nada.
- En contra: hereda el problema de la tabla corta. Se paga una llamada al modelo
  para no ganar variedad, que era justo lo que se buscaba.
- Rechazada.

## Consecuencias

- Las propuestas pueden salir menos de las que pidió el modelo, y a veces
  ninguna. Es el comportamiento correcto: con el día cubierto, la respuesta
  honesta es que no hay nada que sugerir.
- Las sugerencias no se piden solas. Cuestan dinero y solo se generan al pulsar,
  con su propia cuota diaria (`consumir_cuota('sugerencia')`, 20 al día) separada
  de la de fotos, que es bastante más cara.
- El servidor recibe el hueco, no el diario. No necesita saber qué comió nadie
  para proponer, y lo que no viaja no se puede filtrar.
- El filtro es la pieza crítica del asunto, así que es la que está cubierta por
  tests: los que importan no son los que comprueban que una buena sugerencia
  pasa, sino los que comprueban que las malas se caen.
- Si algún día se quiere que el modelo tenga más margen, el sitio para
  discutirlo es `evaluarSugerencias`, en un solo archivo y con sus tests
  delante.
