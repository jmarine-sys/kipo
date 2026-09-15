-- Escritura atomica de movimientos.
-- Cada llamada va SUELTA (autocommit), que es exactamente como la hace el navegador:
-- asi el trigger diferido de ADR-010 dispara al confirmar, como en produccion.
-- Dentro de un bloque DO no disparia hasta el final del bloque y el test mentiria.

set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

-- ---- 1. camino feliz: el cliente NUNCA nombra el libro (ADR-003) ----
select create_transaction(
  date '2026-10-01', 'expense',
  jsonb_build_array(
    jsonb_build_object('account_id',(select id from account where name='Banco ARS'),
                       'amount','-31000','unit','ARS'),
    jsonb_build_object('category_id',(select id from category where name='Supermercado'),
                       'amount','31000','unit','ARS')),
  'Compra grande') as nuevo_movimiento \gset

\if :{?nuevo_movimiento}
\echo 'ok  registra un movimiento y devuelve su id'
\endif

select case when ledger_id is not null
            then 'ok  el ledger_id lo puso la base, no el cliente'
            else 'FALLO  ledger_id quedo nulo' end
  from transaction where id = :'nuevo_movimiento';

-- cuantas transacciones hay antes de los intentos que deben fallar
select count(*) as antes from transaction \gset

-- ---- 2. ATOMICIDAD: si no balancea no debe quedar NADA ----
\set ON_ERROR_STOP off
select create_transaction(
  date '2026-10-02', 'expense',
  jsonb_build_array(
    jsonb_build_object('account_id',(select id from account where name='Banco ARS'),
                       'amount','-500','unit','ARS'),
    jsonb_build_object('category_id',(select id from category where name='Supermercado'),
                       'amount','999','unit','ARS')),
  'Desbalanceada');

-- ---- 3. un movimiento no puede tener una sola linea ----
select create_transaction(
  date '2026-10-03', 'expense',
  jsonb_build_array(
    jsonb_build_object('account_id',(select id from account where name='Banco ARS'),
                       'amount','-1','unit','ARS')));
\set ON_ERROR_STOP on

-- ---- verificacion: ninguno de los dos dejo rastro ----
select case when count(*) = :antes
            then format('ok  los 2 intentos fallidos no dejaron huerfanos (%s movimientos)', count(*))
            else format('FALLO  FUGA: habia %s y ahora hay %s', :antes, count(*)) end
  from transaction;

select case when count(*) = 0
            then 'ok  tampoco quedaron lineas sueltas'
            else format('FALLO  %s lineas huerfanas', count(*)) end
  from entry e where not exists (select 1 from transaction t where t.id = e.transaction_id);

reset role;

-- ---- 4. la vista de lectura respeta RLS y trae los nombres ----
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);
select case when count(*) > 0
            then format('ok  entry_detail devuelve %s lineas con nombre de cuenta', count(*))
            else 'FALLO  entry_detail no trajo nada' end
  from entry_detail where account_name is not null;

select set_config('test.uid','99999999-9999-9999-9999-999999999999', false);
select case when count(*) = 0
            then 'ok  entry_detail no filtra datos a un extranio (RLS en la vista)'
            else format('FALLO GRAVE  un extranio vio %s lineas', count(*)) end
  from entry_detail;
reset role;
