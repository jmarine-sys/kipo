-- kipo · DEJA TU LIBRO COMO RECIEN CREADO.
--
-- Borra TODO lo que vos cargaste y vuelve a sembrar lo minimo, llamando a la
-- MISMA funcion que usa el alta de un usuario nuevo (sembrar_libro). Antes este
-- archivo tenia su propia copia de la siembra y habia quedado vieja: resetear
-- para "probar desde cero" te dejaba en un cero que ya no existia.
--
-- SOLO para la etapa de prueba, ANTES de la puesta en marcha (ADR-018). Despues
-- de esa linea los datos son historia y esta ruta deja de estar permitida.
--
--   psql "$DB" -v reset_confirm=BORRAR_TODO -f supabase/reset_ledger.sql
--
-- QUE NO BORRA, y por que: las cotizaciones del dolar y de la UVA (`fx_rate`).
-- No son algo que hayas cargado vos, son una copia de datos publicos que el
-- flujo diario mantiene solo. Borrarlas dejaria la medicion muda hasta la
-- proxima corrida, sin ganar nada. Si igual las queres afuera, descomenta su
-- linea mas abajo.

\if :{?reset_confirm}
\else
\warn 'ABORTADO: falta -v reset_confirm=BORRAR_TODO'
\quit
\endif

\set ON_ERROR_STOP on
begin;

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

do $$
declare v_ledger uuid; v_cats int; v_cuentas int;
begin
  select id into v_ledger from ledger limit 1;
  perform sembrar_libro(v_ledger);

  select count(*) into v_cats    from category;
  select count(*) into v_cuentas from account;

  -- Se comprueba en vez de confiar: si maniana la siembra cambia y esto no se
  -- entera, el mensaje mentiria sobre el estado en el que te deja.
  if v_cats <> 6 or v_cuentas <> 0 then
    raise exception 'El reseteo dejo % categorias y % cuentas; se esperaban 6 y 0',
      v_cats, v_cuentas;
  end if;

  raise notice 'Libro como recien creado: % categorias, ninguna cuenta.', v_cats;
  raise notice 'Al entrar a la app te va a recibir la puesta en marcha.';
end $$;

commit;
