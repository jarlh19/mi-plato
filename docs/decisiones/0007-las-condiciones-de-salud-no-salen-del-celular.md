# ADR-0007: Las condiciones de salud no salen del celular

## Estado
Aceptada

## Fecha
2026-11-06

## Contexto

El pedido de sugerencias (ADR-0006) mandaba a la Edge Function, y de ahí a
Anthropic, las condiciones que la persona marcó en su perfil: diabetes,
hipertensión, colesterol alto. Son datos de salud, sensibles para la Ley 29733,
que pide consentimiento expreso y por escrito para tratarlos y, más aún, para
mandarlos a un tercero fuera del Perú. La app no lo pedía. Salió en la ficha de
datos del escudo de seguridad (estándar E9).

## Decisión

No se mandan. El pedido lo arma `pedidoDeSugerencias`, que recibe el objetivo y
el hueco del día, no el perfil: con esa firma no hay cómo agregar un dato del
perfil sin que se note en la revisión. Lleva tres cosas: el objetivo, el hueco y
las comidas que faltan.

El efecto de las condiciones sí llega. Los topes del hueco salen de
`metaDiaria`, que ya los ajusta: con hipertensión el sodio libre se calcula
sobre 1500 mg y no 2000, y con diabetes el azúcar libre sobre el 5 % de las
calorías y no el 10 %. Y lo que el modelo proponga pasa igual por
`evaluarSugerencias`, que descarta lo que se pase de los topes de esa persona.

La Edge Function deja de leer el campo y su instrucción ya no nombra
enfermedades: le pide no acercarse al límite de azúcar, grasa saturada y sodio.

## Alternativas descartadas

- **Pedir consentimiento expreso** (casilla aparte, con fecha y versión del
  texto) y mandar las condiciones solo a quien acepta. Mejora un poco la
  puntería del modelo, pero suma una pantalla, un registro que guardar y un
  dato sensible que sale del país, para algo que las reglas locales ya
  aseguran.
- **Dejarlo como estaba.** Incumple la ley.

## Consecuencias

- Las sugerencias pueden ser algo menos finas para quien declara una
  condición (el modelo no sabe por qué el margen de azúcar es chico), pero
  nunca llega a la pantalla una que pase los topes.
- Pruebas: `test/condiciones_no_salen_test.dart` comprueba que el pedido no
  nombra ninguna condición, que con condiciones los topes del hueco son más
  estrictos y que la app y la Edge Function usan este camino.
- La Edge Function solo se revisó de sintaxis (no hay Deno en la laptop); se
  despliega con `supabase functions deploy sugerir-comidas`, con señal de Jorge.
