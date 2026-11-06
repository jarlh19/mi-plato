-- Esquema de Mi Plato para Supabase.
-- Ejecutar completo en el SQL Editor del proyecto (una sola vez).
--
-- Todo lo que hay aquí son datos de salud de una persona concreta: lo que come,
-- cuánto pesa, qué condiciones declara. Cada tabla lleva RLS y nadie ve filas
-- que no sean suyas. No hay rol de administrador con acceso al diario ajeno.

-- En Supabase toda tabla, secuencia y función nueva del esquema public nace
-- abierta para anon y authenticated, o sea para cualquiera con la clave
-- pública, y Postgres le da además execute a PUBLIC sobre toda función nueva.
-- Aquí no: cada tabla recibe su grant explícito más abajo (y RLS decide las
-- filas), y las funciones que la app llama se habilitan una por una al final.
-- El revoke a PUBLIC va sin "in schema" porque los privilegios por defecto de
-- un esquema solo suman a los globales. service_role conserva lo suyo.
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke all on functions from anon, authenticated;
alter default privileges revoke execute on functions from public;

-- ---------------------------------------------------------------- perfiles --
create table if not exists public.perfiles (
  id              uuid primary key references auth.users on delete cascade,
  nombre          text not null default '',
  sexo            text not null default 'femenino' check (sexo in ('femenino','masculino')),
  edad            int  not null default 30 check (edad between 14 and 100),
  altura_cm       numeric(5,1) not null default 165 check (altura_cm between 120 and 230),
  peso_kg         numeric(5,1) not null default 65 check (peso_kg between 30 and 300),
  actividad       text not null default 'ligero'
                    check (actividad in ('sedentario','ligero','moderado','alto','muyAlto')),
  objetivo        text not null default 'mantener'
                    check (objetivo in ('bajarPeso','mantener','subirMasa')),
  condiciones     text[] not null default '{}',
  perfil_completo boolean not null default false,
  creado_en       timestamptz not null default now()
);

-- Cada usuario nuevo de auth recibe su fila de perfil con el nombre del
-- registro. El resto de datos los completa el onboarding de la app.
create or replace function public.crear_perfil()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.perfiles (id, nombre)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'nombre', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists al_crear_usuario on auth.users;
create trigger al_crear_usuario
  after insert on auth.users
  for each row execute function public.crear_perfil();

-- ----------------------------------------------------------------- comidas --
-- Los alimentos van en jsonb y no en una tabla aparte a propósito: una comida
-- es una foto congelada en el tiempo. Si mañana se corrige la ficha de "arroz
-- blanco" en la base nutricional, el desayuno de ayer no debe cambiar.
create table if not exists public.comidas (
  id          uuid primary key default gen_random_uuid(),
  perfil_id   uuid not null references public.perfiles on delete cascade,
  fecha       timestamptz not null default now(),
  tipo        text not null default 'almuerzo'
                check (tipo in ('desayuno','almuerzo','cena','snack')),
  alimentos   jsonb not null default '[]'::jsonb,
  foto_url    text not null default '',
  descripcion text not null default '',
  creado_en   timestamptz not null default now()
);

-- El diario siempre se lee por persona y por rango de fechas.
create index if not exists comidas_perfil_fecha
  on public.comidas (perfil_id, fecha desc);

-- ------------------------------------------------------------------- pesos --
create table if not exists public.pesos (
  id        uuid primary key default gen_random_uuid(),
  perfil_id uuid not null references public.perfiles on delete cascade,
  fecha     date not null default current_date,
  peso_kg   numeric(5,1) not null check (peso_kg between 30 and 300),
  -- Un pesaje por día: volver a pesarse el mismo día corrige el anterior en
  -- vez de añadir ruido a la curva.
  unique (perfil_id, fecha)
);

create index if not exists pesos_perfil_fecha
  on public.pesos (perfil_id, fecha);

-- --------------------------------------------------------------------- RLS --
alter table public.perfiles enable row level security;
alter table public.comidas  enable row level security;
alter table public.pesos    enable row level security;

drop policy if exists perfil_propio_leer on public.perfiles;
create policy perfil_propio_leer on public.perfiles
  for select using (id = auth.uid());

drop policy if exists perfil_propio_editar on public.perfiles;
create policy perfil_propio_editar on public.perfiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- El insert lo hace el trigger (security definer); la app nunca crea perfiles.

drop policy if exists comidas_propias on public.comidas;
create policy comidas_propias on public.comidas
  for all using (perfil_id = auth.uid()) with check (perfil_id = auth.uid());

drop policy if exists pesos_propios on public.pesos;
create policy pesos_propios on public.pesos
  for all using (perfil_id = auth.uid()) with check (perfil_id = auth.uid());

-- ----------------------------------------------------------------- storage --
-- Bucket privado: son fotos de lo que alguien come en su casa. La app guarda la
-- ruta y pide un enlace firmado cada vez que necesita mostrarla.
insert into storage.buckets (id, name, public)
values ('comidas', 'comidas', false)
on conflict (id) do nothing;

-- La ruta es "<uid>/<timestamp>.jpg", así que la primera carpeta identifica al
-- dueño y basta para decidir el acceso.
drop policy if exists fotos_leer on storage.objects;
create policy fotos_leer on storage.objects
  for select using (
    bucket_id = 'comidas'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists fotos_subir on storage.objects;
create policy fotos_subir on storage.objects
  for insert with check (
    bucket_id = 'comidas'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists fotos_borrar on storage.objects;
create policy fotos_borrar on storage.objects
  for delete using (
    bucket_id = 'comidas'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ------------------------------------------------------- cuota de análisis --
-- Cada análisis de foto es una llamada de pago al modelo. Sin tope, una cuenta
-- robada o un bucle en el cliente puede vaciar la cuenta de Anthropic en una
-- noche. El contador vive aquí, y no en la Edge Function, por dos razones:
-- Postgres lo incrementa de forma atómica (dos fotos a la vez no se cuelan por
-- el mismo hueco) y el límite no es un parámetro que el cliente pueda inflar.
-- `tipo` separa los contadores: una foto cuesta bastante más que una tanda de
-- sugerencias, así que cada cosa lleva su propio tope y gastar en una no deja
-- sin la otra.
create table if not exists public.analisis_uso (
  perfil_id uuid not null references public.perfiles on delete cascade,
  fecha     date not null default current_date,
  tipo      text not null default 'analisis'
            check (tipo in ('analisis', 'sugerencia')),
  usos      int  not null default 0,
  primary key (perfil_id, fecha, tipo)
);

alter table public.analisis_uso enable row level security;

-- Solo lectura: quien escribe es la función, que corre como definer.
drop policy if exists uso_propio_leer on public.analisis_uso;
create policy uso_propio_leer on public.analisis_uso
  for select using (perfil_id = auth.uid());

-- Cuándo se llenó el tope total del día. Una fila por día y tipo: es lo que
-- revisa Jorge para saber si hay que subir el tope o si alguien abusa. El
-- esquema privado no está expuesto por la API.
create schema if not exists privado;
revoke all on schema privado from public, anon, authenticated;

create table if not exists privado.topes_alcanzados (
  fecha        date not null,
  tipo         text not null,
  usos         int  not null,
  alcanzado_en timestamptz not null default now(),
  primary key (fecha, tipo)
);

-- Consume una unidad de cuota del tipo pedido y devuelve cuántas quedan hoy,
-- -1 si a la persona ya no le queda ninguna, o -2 si se llenó el tope total
-- del día, entre todas las cuentas.
--
-- El tipo es un argumento, pero **los límites no**: son constantes de esta
-- función. Si el número fuera un parámetro, cualquiera con sesión podría llamar
-- al RPC con un valor enorme y saltarse el tope, y cada llamada cuesta dinero
-- real (OWASP LLM10).
create or replace function public.consumir_cuota(p_tipo text)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  limite   int;
  global   int;
  hoy      int;
  actuales int;
begin
  if auth.uid() is null then
    raise exception 'Sin sesión';
  end if;

  limite := case p_tipo
    -- Una foto es una llamada con imagen: la cara.
    when 'analisis'   then 30
    -- Una tanda de sugerencias es solo texto, cuesta una fracción.
    when 'sugerencia' then 20
    else null
  end;

  if limite is null then
    raise exception 'Tipo de cuota desconocido: %', p_tipo;
  end if;

  -- Tope total del día, entre todas las cuentas: muchas cuentas nuevas, cada
  -- una con su cuota, igual vaciarían la cuenta de la IA. Se mira antes que
  -- el de la persona para no descontarle un uso que no va a tener.
  global := case p_tipo when 'analisis' then 300 when 'sugerencia' then 300 end;
  select coalesce(sum(usos), 0) into hoy
  from public.analisis_uso
  where fecha = current_date and tipo = p_tipo;
  if hoy >= global then
    insert into privado.topes_alcanzados (fecha, tipo, usos)
    values (current_date, p_tipo, hoy)
    on conflict (fecha, tipo) do nothing;
    return -2;
  end if;

  insert into public.analisis_uso (perfil_id, fecha, tipo, usos)
  values (auth.uid(), current_date, p_tipo, 0)
  on conflict (perfil_id, fecha, tipo) do nothing;

  -- El bloqueo de fila serializa dos peticiones simultáneas de la misma
  -- persona; sin él ambas leerían el mismo valor y las dos pasarían.
  select usos into actuales
  from public.analisis_uso
  where perfil_id = auth.uid() and fecha = current_date and tipo = p_tipo
  for update;

  if actuales >= limite then
    return -1;
  end if;

  update public.analisis_uso
  set usos = actuales + 1
  where perfil_id = auth.uid() and fecha = current_date and tipo = p_tipo;

  return limite - actuales - 1;
end;
$$;

-- ------------------------------------------------------- borrar mi cuenta --
-- Esto guarda datos de salud: qué come alguien, cuánto pesa, qué condiciones
-- declara. La retención es "hasta que la persona lo borre", así que el borrado
-- tiene que existir de verdad y funcionar de una vez.
--
-- Al eliminar la fila de auth.users caen en cascada el perfil, las comidas, los
-- pesos y la cuota. Las fotos de Storage NO caen con la cascada: la app las
-- borra antes de llamar aquí (ver `SbAuthRepo.borrarCuenta`).
create or replace function public.borrar_mi_cuenta()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sin sesión';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

-- -------------------------------------------------------------- tablas ----
-- Las tablas de la app, con los permisos que usa la API. Qué filas ve o toca
-- cada quien lo decide RLS. Si agregas una tabla, agrégala aquí y actívale RLS.
grant select, insert, update, delete on
  public.perfiles,
  public.comidas,
  public.pesos,
  public.analisis_uso
to anon, authenticated;

-- ------------------------------------------------------------ funciones ----
-- Nadie llama por la API a las funciones de este archivo, salvo las de abajo.
-- `revoke ... from public` solo no alcanza: Supabase le da el permiso a anon
-- y authenticated aparte. La del trigger no lo necesita: Postgres revisa ese
-- permiso al crear el trigger, no cada vez que corre. Si agregas una función
-- que la app llama con .rpc(), dale su grant aquí.
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on all functions in schema public to service_role;
grant execute on function public.consumir_cuota(text) to authenticated;
grant execute on function public.borrar_mi_cuenta() to authenticated;
