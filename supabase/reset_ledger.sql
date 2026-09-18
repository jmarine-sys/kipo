-- kipo · DEJA TU LIBRO COMO RECIEN CREADO.
--
-- Borra TODO lo que cargaste y vuelve a sembrar lo minimo llamando a la MISMA
-- funcion que usa el alta de un usuario nuevo (`sembrar_libro`), para que "probar
-- desde cero" sea de verdad el cero que ve alguien que se registra hoy.
--
-- SOLO para la etapa de prueba, ANTES de la puesta en marcha (ADR-018). Despues
-- de esa linea los datos son historia y esta ruta deja de estar permitida.
--
-- COMO SE CORRE. Es SQL comun a proposito: andaba solo en psql porque usaba \if
-- y \set, y el editor web de Supabase no los entiende. Ahora sirve en los dos:
--
--   1. Cambia la linea marcada abajo de 'NO' a 'BORRAR_TODO'.
--   2. Pegalo entero en el SQL Editor, o corre:
--        psql "$DB_URL" -f supabase/reset_ledger.sql
--
-- Sin ese cambio no hace nada: tener que editarlo ES la confirmacion.
--
-- QUE NO BORRA, y por que: las cotizaciones del dolar y de la UVA (`fx_rate`).
-- No son algo que hayas cargado vos, son una copia de datos publicos que el flujo
-- diario mantiene solo. Borrarlas dejaria la medicion muda hasta la proxima
-- corrida, sin ganar nada. Si las queres afuera igual, descomenta su linea.
--
-- Todo pasa dentro de un solo bloque, que Postgres corre como UNA transaccion: o
-- queda entero o no queda nada. No hace falta `begin` ni `commit`.

do $$
declare
  -- ┌──────────────────────────────────────────────────────────────┐
  -- │  CAMBIA 'NO' POR 'BORRAR_TODO' PARA QUE ESTO HAGA ALGO        │
  -- └──────────────────────────────────────────────────────────────┘
  confirmo text := 'NO';

  v_ledger  uuid;
  v_cats    int;
  v_cuentas int;
  v_movs    int;
begin
  if confirmo is distinct from 'BORRAR_TODO' then
    raise exception
      'ABORTADO: nada se borro. Cambia la linea `confirmo` a BORRAR_TODO y volve a correrlo.';
  end if;

  select id into v_ledger from ledger limit 1;
  if v_ledger is null then
    raise exception 'No hay ningun libro que resetear';
  end if;

  select count(*) into v_movs from transaction;

  -- El orden importa: primero lo que referencia, despues lo referenciado.
  delete from entry;
  delete from transaction;
  delete from scheduled_event;
  delete from budget;
  delete from price;
  delete from account;        -- incluye las posiciones y los plazos fijos
  delete from instrument;
  delete from portfolio;
  delete from category;
  delete from ledger_invite;  -- codigos de invitacion a medio usar

  -- delete from fx_rate;     -- descomentar para empezar tambien sin cotizaciones

  perform sembrar_libro(v_ledger);

  select count(*) into v_cats    from category;
  select count(*) into v_cuentas from account;

  -- Se comprueba en vez de confiar: si maniana la siembra cambia y esto no se
  -- entera, el mensaje mentiria sobre el estado en el que te deja. Y como todo
  -- corre en una transaccion, fallar aca deshace el borrado entero.
  if v_cats <> 6 or v_cuentas <> 0 then
    raise exception 'El reseteo dejo % categorias y % cuentas; se esperaban 6 y 0',
      v_cats, v_cuentas;
  end if;

  raise notice 'Se borraron % movimientos y todo lo demas que habias cargado.', v_movs;
  raise notice 'Libro como recien creado: % categorias, ninguna cuenta.', v_cats;
  raise notice 'Al entrar a la app te va a recibir la puesta en marcha.';
end $$;
