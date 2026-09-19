-- kipo · DEJA TU CUENTA COMO RECIEN CREADA.
--
-- Borra TODO lo que cargaste —en TODOS tus libros— y deja uno solo, sembrado
-- con la MISMA funcion que usa el alta de un usuario nuevo (`sembrar_libro`),
-- para que "probar desde cero" sea de verdad el cero que ve alguien que se
-- registra hoy.
--
-- SOLO para la etapa de prueba, ANTES de la puesta en marcha (ADR-018). Despues
-- de esa linea los datos son historia y esta ruta deja de estar permitida.
--
-- COMO SE CORRE:
--   1. Cambia la linea marcada abajo de 'NO' a 'BORRAR_TODO'.
--   2. Pegalo entero en el SQL Editor, o corre:
--        psql "$DB_URL" -f supabase/reset_ledger.sql
--
-- Sin ese cambio no hace nada: tener que editarlo ES la confirmacion.
--
-- QUE PASA CON LOS LIBROS Y CON LA GENTE. Desde ADR-032 se pueden tener varios
-- libros y desde ADR-028 se pueden compartir. Este script deja UN libro —el mas
-- viejo, el que creo tu alta— y UNA persona: vos. Los demas libros se borran con
-- todo lo suyo, y quien hayas invitado probando pierde el acceso. Si querias
-- conservar alguna de las dos cosas, este no es el script.
--
-- QUE NO BORRA: las cotizaciones del dolar y de la UVA (`fx_rate`). No son algo
-- que hayas cargado vos, son una copia de datos publicos que el flujo diario
-- mantiene solo. Borrarlas dejaria la medicion muda hasta la proxima corrida,
-- sin ganar nada. Si las queres afuera igual, descomenta su linea.
--
-- Todo pasa dentro de un solo bloque, que Postgres corre como UNA transaccion:
-- o queda entero o no queda nada.

do $$
declare
  -- ┌──────────────────────────────────────────────────────────────┐
  -- │  CAMBIA 'NO' POR 'BORRAR_TODO' PARA QUE ESTO HAGA ALGO        │
  -- └──────────────────────────────────────────────────────────────┘
  confirmo text := 'NO';

  v_ledger  uuid;
  v_duenio  uuid;
  v_libros  int;
  v_gente   int;
  v_cats    int;
  v_cuentas int;
  v_movs    int;
begin
  if confirmo is distinct from 'BORRAR_TODO' then
    raise exception
      'ABORTADO: nada se borro. Cambia la linea `confirmo` a BORRAR_TODO y volve a correrlo.';
  end if;

  -- El libro que sobrevive es el PRIMERO que existio. `limit 1` a secas elegia
  -- cualquiera, y con varios libros eso significaba resembrar uno al azar y
  -- dejar los otros vacios y sin categorias.
  select id into v_ledger from ledger order by created_at, id limit 1;
  if v_ledger is null then
    raise exception 'No hay ningun libro que resetear';
  end if;

  select count(*) into v_movs   from transaction;
  select count(*) into v_libros from ledger;
  select count(*) into v_gente  from ledger_member where ledger_id = v_ledger;

  -- El orden importa: primero lo que referencia, despues lo referenciado.
  delete from entry;
  delete from transaction;
  delete from scheduled_event;
  delete from budget;
  delete from price;
  delete from portfolio_account;   -- cae por cascada, pero explicito no depende de eso
  delete from account;             -- incluye las posiciones y los plazos fijos
  delete from instrument;
  delete from portfolio;
  delete from category;
  delete from ledger_invite;

  -- delete from fx_rate;          -- descomentar para empezar tambien sin cotizaciones

  -- Los libros de mas, con su membresia y lo que les cuelgue.
  delete from ledger where id <> v_ledger;

  -- Y la gente que invitaste probando. Sin esto el reseteo dejaba a un tercero
  -- con acceso a tu libro, que es lo contrario de "como recien creado".
  -- Sobrevive quien entro primero: el que lo creo.
  select user_id into v_duenio from ledger_member
   where ledger_id = v_ledger order by joined_at, user_id limit 1;

  delete from ledger_member where ledger_id = v_ledger and user_id <> v_duenio;
  update ledger_member set role = 'owner' where ledger_id = v_ledger;

  -- Y que estes mirando ese libro, explicito y no por descarte: `my_ledger()`
  -- sabe caer al primero, pero dejarlo dicho no depende de ese respaldo.
  delete from active_ledger;
  insert into active_ledger (user_id, ledger_id) values (v_duenio, v_ledger);

  perform sembrar_libro(v_ledger);

  select count(*) into v_cats    from category;
  select count(*) into v_cuentas from account;

  -- Se comprueba en vez de confiar: si maniana la siembra cambia y esto no se
  -- entera, el mensaje mentiria sobre el estado en el que te deja. Y como todo
  -- corre en una transaccion, fallar aca deshace el borrado entero.
  if v_cats <> 6 or v_cuentas <> 0
     or (select count(*) from ledger) <> 1
     or (select count(*) from ledger_member) <> 1 then
    raise exception
      'El reseteo dejo % libros, % miembros, % categorias y % cuentas; se esperaban 1, 1, 6 y 0',
      (select count(*) from ledger), (select count(*) from ledger_member), v_cats, v_cuentas;
  end if;

  raise notice 'Se borraron % movimientos y todo lo demas que habias cargado.', v_movs;
  if v_libros > 1 then
    raise notice 'Y % libro/s de mas: queda solo el original.', v_libros - 1;
  end if;
  if v_gente > 1 then
    raise notice 'Y % persona/s que habias invitado: ya no tienen acceso.', v_gente - 1;
  end if;
  raise notice 'Libro como recien creado: % categorias, ninguna cuenta.', v_cats;
  raise notice 'Al entrar a la app te va a recibir la puesta en marcha.';
end $$;
