/* Prueba schema.sql contra un Postgres de verdad, en memoria (PGlite), antes
   de correrlo en Supabase. Imita lo mínimo de Supabase que el esquema usa
   (roles, privilegios por defecto, auth.uid, storage) y prueba lo que alguien
   podría hacer con la API: leer o tocar el diario de otro, saltarse la cuota de
   análisis y llamar funciones sin sesión.
   Se corre con `npm run probar` desde esta carpeta. */
import { PGlite } from '@electric-sql/pglite'
import { readFileSync } from 'node:fs'

const db = new PGlite()
// Lo mínimo de Supabase: roles, privilegios por defecto del esquema public
// (en Supabase todo lo nuevo nace con permisos para anon y authenticated) y
// los esquemas auth y storage.
await db.exec(`
  create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
  grant usage on schema public to anon, authenticated, service_role;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
  alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
  create schema auth; create schema storage;
  grant usage on schema auth, storage to anon, authenticated;
  create table auth.users (id uuid primary key, email text, raw_user_meta_data jsonb default '{}');
  create function auth.uid() returns uuid language sql stable as $$
    select (nullif(current_setting('request.jwt.claims', true), '')::json ->> 'sub')::uuid $$;
  grant execute on function auth.uid() to anon, authenticated;
  create table storage.buckets (id text primary key, name text, public boolean);
  create table storage.objects (id serial primary key, bucket_id text, name text);
  create function storage.foldername(name text) returns text[] language sql immutable as $$
    select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1] $$;
  grant execute on function storage.foldername(text) to anon, authenticated;
  alter table storage.objects enable row level security;
  grant all on storage.objects to anon, authenticated;
  grant usage on sequence storage.objects_id_seq to anon, authenticated;
`)
await db.exec(readFileSync(new URL('schema.sql', import.meta.url), 'utf8'))

const ANA = '00000000-0000-0000-0000-00000000000a'
const BETO = '00000000-0000-0000-0000-00000000000b'
await db.exec(`insert into auth.users (id, email, raw_user_meta_data) values
  ('${ANA}', 'ana@x.pe', '{"nombre":"Ana"}'),
  ('${BETO}', 'beto@x.pe', '{"nombre":"Beto"}')`)

// Como llega una consulta por la API: con el rol y el token del usuario.
const como = async (uid, rol = 'authenticated') => {
  await db.query('reset role')
  await db.query(`select set_config('request.jwt.claims', $1, false)`, [uid ? JSON.stringify({ sub: uid, role: rol }) : ''])
  await db.query(`set role ${rol}`)
}
const editor = async () => { await db.query('reset role'); await db.query(`select set_config('request.jwt.claims', '', false)`) }
const intenta = async (sql, params) => { try { return (await db.query(sql, params)).rows } catch (e) { return e } }
const cuenta = async (sql, params) => { await editor(); return (await db.query(sql, params)).rows[0].n }

let fallos = 0
const ok = (cond, msg) => { console.log((cond ? '  ok  ' : ' FALLA ') + msg); if (!cond) fallos++ }

console.log('— Diario —')
ok(await cuenta('select count(*)::int n from perfiles') === 2, 'el registro crea un perfil por usuario')

await como(ANA)
const propio = await intenta(`update perfiles set peso_kg = 70, perfil_completo = true where id = $1 returning peso_kg`, [ANA])
ok(Array.isArray(propio) && Number(propio[0]?.peso_kg) === 70, 'cada quien edita su perfil')
await como(ANA)
await intenta(`update perfiles set nombre = 'otro' where id = $1`, [BETO])
ok(await cuenta(`select count(*)::int n from perfiles where id = $1 and nombre = 'Beto'`, [BETO]) === 1, 'nadie edita el perfil de otro')

await como(ANA)
await intenta(`insert into comidas (perfil_id, tipo) values ($1, 'desayuno')`, [ANA])
await como(ANA)
const ajena = await intenta(`insert into comidas (perfil_id, tipo) values ($1, 'cena')`, [BETO])
ok(await cuenta('select count(*)::int n from comidas where perfil_id = $1', [ANA]) === 1 && ajena instanceof Error,
  'cada quien anota sus comidas y no las de otro')
await como(BETO)
const vistas = await intenta('select count(*)::int n from comidas')
ok(Array.isArray(vistas) && vistas[0].n === 0, 'nadie ve el diario de otro')

await como(ANA)
await intenta(`insert into storage.objects (bucket_id, name) values ('comidas', $1)`, [`${ANA}/1.jpg`])
await como(ANA)
const fotoAjena = await intenta(`insert into storage.objects (bucket_id, name) values ('comidas', $1)`, [`${BETO}/1.jpg`])
ok(await cuenta(`select count(*)::int n from storage.objects`) === 1 && fotoAjena instanceof Error,
  'las fotos van solo a la carpeta propia')

console.log('\n— Cuota de análisis —')
await como(ANA)
let quedan
for (let i = 0; i < 30; i++) quedan = (await db.query(`select consumir_cuota('analisis') q`)).rows[0].q
ok(quedan === 0, 'treinta análisis al día')
ok((await db.query(`select consumir_cuota('analisis') q`)).rows[0].q === -1, 'y el treinta y uno no pasa')
ok((await db.query(`select consumir_cuota('sugerencia') q`)).rows[0].q === 19, 'las sugerencias llevan su propio tope')
const raro = await intenta(`select consumir_cuota('otra')`)
ok(raro instanceof Error && /desconocido/.test(raro.message), 'un tipo de cuota inventado se rechaza')
await como(ANA)
const tocarCuota = await intenta(`update analisis_uso set usos = 0 where perfil_id = $1`, [ANA])
ok(await cuenta(`select usos n from analisis_uso where perfil_id = $1 and tipo = 'analisis'`, [ANA]) === 30
  && (tocarCuota instanceof Error || tocarCuota.length === 0), 'nadie se reinicia la cuota a mano')

// Tope total del día, entre todas las cuentas: muchas cuentas nuevas, cada
// una con su cuota, igual vaciarían la cuenta de la IA.
await editor()
await db.query(`insert into analisis_uso (perfil_id, fecha, tipo, usos) values ($1, current_date, 'sugerencia', 300)`, [BETO])
await como(ANA)
ok((await db.query(`select consumir_cuota('sugerencia') q`)).rows[0].q === -2,
  'con el tope total del día lleno, la cuota responde -2 aunque a la persona le queden')
ok(await cuenta(`select usos n from analisis_uso where perfil_id = $1 and tipo = 'sugerencia'`, [ANA]) === 1,
  'y no le descuenta nada a la persona')
ok(await cuenta(`select count(*)::int n from privado.topes_alcanzados where fecha = current_date and tipo = 'sugerencia'`) === 1,
  'el primer choque con el tope total del día queda anotado')
await como(ANA)
await db.query(`select consumir_cuota('sugerencia')`)
ok(await cuenta(`select count(*)::int n from privado.topes_alcanzados`) === 1, 'una sola vez por día y tipo')

console.log('\n— Funciones —')
await editor()
const puede = async (rol, firma) => (await db.query(`select has_function_privilege($1, $2, 'execute') p`, [rol, firma])).rows[0].p
// Todas las funciones del esquema, no una lista: si alguien agrega una y se
// olvida de cerrarla, esto falla.
const funciones = (await db.query(`select p.oid::regprocedure::text firma from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public'`)).rows.map((f) => f.firma)
const permitidas = { anon: [], authenticated: ['borrar_mi_cuenta()', 'consumir_cuota(text)'] }
ok(funciones.length >= 3, `revisa las ${funciones.length} funciones del esquema`)
for (const rol of ['anon', 'authenticated']) {
  const abiertas = []
  for (const f of funciones) if (await puede(rol, `public.${f}`)) abiertas.push(f)
  ok(abiertas.sort().join() === permitidas[rol].sort().join(),
    `${rol} ${permitidas[rol].length ? 'ejecuta solo ' + permitidas[rol].join(' y ') : 'no ejecuta ninguna'} (ejecuta: ${abiertas.join(', ') || 'nada'})`)
}
await como(null, 'anon')
const sinSesion = await intenta(`select consumir_cuota('analisis')`)
ok(sinSesion instanceof Error && /permission denied/.test(sinSesion.message), 'sin sesión ni siquiera se llega a la cuota')
await editor()
const porDefecto = (await db.query(`select coalesce(array_agg(a::text), '{}') acl from pg_default_acl d, unnest(d.defaclacl) a
  where d.defaclobjtype = 'f' and d.defaclnamespace = 'public'::regnamespace`)).rows[0].acl
ok(!porDefecto.some((a) => /^(anon|authenticated)=/.test(a)), 'una función nueva ya no nace abierta para anon ni authenticated')

console.log('\n— Borrar mi cuenta —')
await como(ANA)
await db.query('select borrar_mi_cuenta()')
ok(await cuenta('select count(*)::int n from auth.users where id = $1', [ANA]) === 0
  && await cuenta('select count(*)::int n from comidas where perfil_id = $1', [ANA]) === 0
  && await cuenta('select count(*)::int n from perfiles where id = $1', [BETO]) === 1,
  'borrar la cuenta se lleva todo lo de esa persona y nada de otra')

console.log(fallos ? `\n${fallos} FALLAS` : '\nTodo en orden')
process.exit(fallos ? 1 : 0)
