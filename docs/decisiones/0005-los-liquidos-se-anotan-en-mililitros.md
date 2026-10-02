# ADR-0005: Los líquidos se anotan en mililitros, pero se guardan en gramos

## Estado
Aceptada

## Fecha
2026-09-29

## Contexto

La app pedía toda porción en gramos, bebidas incluidas. Eso es pedir algo que
nadie puede dar: nadie pesa un vaso de jugo ni una lata de gaseosa. Los envases
vienen rotulados en mililitros y los vasos se miden en mililitros, así que
obligar a convertir a gramos garantizaba un número inventado justo en el paso
que la app presenta como "corrige la estimación".

Al mismo tiempo, los nutrientes no se pueden pedir en mililitros: USDA
FoodData Central —y cualquier base nutricional seria— publica los valores **por
100 g**, también los de las bebidas. Toda la aritmética de la app
(`calculos.dart`, `veredicto.dart`) está construida sobre gramos.

Y los dos números no son intercambiables. Un mililitro de agua pesa un gramo,
pero el azúcar disuelto sube la densidad (una gaseosa va por 1.04 g/ml) y la
grasa la baja (el aceite, 0.92). Tratar 350 ml como 350 g se queda corto en un
4% de las calorías de una lata.

## Decisión

La unidad canónica sigue siendo el gramo. `Alimento.gramos` no cambia de
significado y nada del cálculo se toca.

Cada alimento lleva además una `densidad` en gramos por mililitro, que vale 0
en los sólidos. Cuando es mayor que cero, el alimento es líquido y la interfaz
lo muestra y lo edita en mililitros: `cantidad`, `unidad` y `conCantidad()`
hacen la traducción en el borde, una sola vez.

La densidad **no la aporta el modelo de visión**. El modelo dice en qué unidad
estimó la porción (`"g"` o `"ml"`); la densidad sale de una tabla del servidor
(`DENSIDADES` en la Edge Function) y de la tabla local en el cliente. Es un dato
físico constante, y aceptarlo del modelo sería aceptar un número arbitrario por
el que se multiplican las calorías (OWASP LLM05).

Para un líquido que no está en la tabla se usa 1.00, la del agua. El error
máximo así es de un 5%, muy por debajo del 20-30% que ya arrastra estimar una
porción desde una foto.

## Alternativas consideradas

### Guardar la porción en mililitros cuando el alimento es líquido
- A favor: se guarda exactamente lo que la persona escribió, sin conversión.
- En contra: obliga a que cada cálculo pregunte antes en qué unidad está el
  alimento. La suma de un plato con bebida deja de ser una suma. `veredicto.dart`
  calcula kcal por 100 g del plato entero, y con dos unidades conviviendo esa
  cuenta necesita la densidad igualmente, pero repartida por todo el código.
- Rechazada: mueve la conversión del borde al centro.

### Dos tablas nutricionales, una por 100 g y otra por 100 ml
- A favor: ninguna conversión en tiempo de ejecución.
- En contra: duplica la fuente de verdad, y USDA no publica la de 100 ml, así
  que habría que generarla aplicando… la densidad. El mismo dato, con una copia
  más que mantener.
- Rechazada.

### Pedirle la densidad al modelo junto al alimento
- A favor: cubre cualquier bebida, también las que no están en la tabla.
- En contra: es un factor multiplicativo sobre las calorías salido de una
  fuente no confiable. Un error suyo no se distingue de un dato bueno.
- Rechazada por lo mismo que el ADR-0001: el modelo identifica, no cuantifica lo
  que se puede saber sin él.

## Consecuencias

- Las etiquetas de bebidas vienen **por 100 ml**, no por 100 g. Quien añada una
  entrada a `tabla_local.dart` copiando una etiqueta tiene que dividir por la
  densidad primero. Está advertido en el doc de `Alimento.densidad`, que es
  donde se va a mirar.
- El tope del deslizador sube a 1000 en líquidos: una botella personal son 500
  ml y el tope de 600 de los sólidos no daba para servirla.
- `Alimento.densidad` (masa por volumen) y `Alimento.densidadCalorica` (kcal por
  100 g) son cosas distintas que en castellano comparten la palabra. La segunda
  llevaba antes el nombre corto; se le puso apellido al aparecer la primera.
- Añadir una bebida nueva es una línea en la tabla local y, si se quiere que el
  reconocimiento la acierte, un patrón en `DENSIDADES`. Sin el patrón funciona
  igual, con la densidad del agua.
