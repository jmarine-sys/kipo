-- Gastos recurrentes: registrar una ocurrencia y adelantar la fecha.
-- Corre como 'authenticated', igual que la aplicacion.
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

-- ---- aritmetica de fechas, incluido el caso incomodo -----------------------
select case when avanzar_fecha(date '2026-01-31','monthly') = date '2026-02-28'
            then 'ok  31 de enero + 1 mes = 28 de febrero (no se rompe)'
            else 'FALLO  '||avanzar_fecha(date '2026-01-31','monthly') end;
select case when avanzar_fecha(date '2027-01-31','monthly') = date '2027-02-28'
            then 'ok  respeta los meses cortos' else 'FALLO' end;
select case when avanzar_fecha(date '2026-07-15','yearly') = date '2027-07-15'
            then 'ok  anual' else 'FALLO' end;
select case when avanzar_fecha(date '2026-11-30','quarterly') = date '2027-02-28'
            then 'ok  trimestral cruzando el fin de anio' else 'FALLO' end;

-- ---- una regla con importe fijo --------------------------------------------
insert into scheduled_event (ledger_id, kind, description, category_id, account_id,
                             amount, currency, frequency, next_on)
select my_ledger(), 'recurring', 'Seguro del auto',
       (select id from category where name='Seguros'),
       (select id from account where name='Banco Nacion'),
       45000, 'ARS', 'monthly', date '2026-10-05'
returning id as regla \gset

select count(*) as mov_antes from transaction \gset

select register_scheduled(:'regla', null, null, null) as tx \gset

select case when count(*) = :mov_antes + 1 then 'ok  registra el movimiento'
            else 'FALLO  no lo registro' end from transaction;

select case when next_on = date '2026-11-05'
            then 'ok  adelanta la fecha un mes'
            else 'FALLO  la fecha quedo en '||next_on end
  from scheduled_event where id = :'regla';

select case when scheduled_event_id = :'regla'
            then 'ok  el movimiento queda ligado a su regla'
            else 'FALLO  quedo suelto' end
  from transaction where id = :'tx';

-- el asiento correcto: sale de la cuenta, entra a la categoria
select case when count(*) = 2 and sum(amount) = 0
            then 'ok  dos lineas que balancean'
            else format('FALLO  %s lineas, suman %s', count(*), sum(amount)) end
  from entry where transaction_id = :'tx';

select case when amount = -45000 then 'ok  descuenta de la cuenta'
            else 'FALLO  '||amount end
  from entry where transaction_id = :'tx' and account_id is not null;

select case when amount = 45000 then 'ok  imputa a la categoria'
            else 'FALLO  '||amount end
  from entry where transaction_id = :'tx' and category_id is not null;

-- ---- una regla de importe variable -----------------------------------------
insert into scheduled_event (ledger_id, kind, description, category_id, account_id,
                             amount, currency, frequency, next_on)
select my_ledger(), 'recurring', 'Luz',
       (select id from category where name='Servicios'),
       (select id from account where name='Banco Nacion'),
       null, 'ARS', 'bimonthly', date '2026-10-20'
returning id as variable \gset

\set ON_ERROR_STOP off
-- sin importe, y la regla tampoco lo tiene: debe rechazar
select register_scheduled(:'variable', null, null, null);
\set ON_ERROR_STOP on

select case when next_on = date '2026-10-20'
            then 'ok  si falla no adelanta la fecha (atomico)'
            else 'FALLO  adelanto igual' end
  from scheduled_event where id = :'variable';

select register_scheduled(:'variable', 31800, null, null) as tx2 \gset
select case when amount = 31800 then 'ok  toma el importe que se le pasa'
            else 'FALLO  '||amount end
  from entry where transaction_id = :'tx2' and category_id is not null;

select case when next_on = date '2026-12-20' then 'ok  adelanta dos meses'
            else 'FALLO  '||next_on end
  from scheduled_event where id = :'variable';

-- ---- la vista de lo que viene ----------------------------------------------
insert into scheduled_event (ledger_id, kind, description, category_id, account_id,
                             amount, currency, frequency, next_on)
select my_ledger(), 'recurring', 'Impuesto vencido',
       (select id from category where name='Impuestos'),
       (select id from account where name='Banco Nacion'),
       12000, 'ARS', 'yearly', current_date - 5;

select case when vencido then 'ok  marca como vencido lo que ya paso'
            else 'FALLO  no lo marco' end
  from upcoming where description = 'Impuesto vencido';

select case when count(*) = 3 then 'ok  la vista lista las 3 reglas vigentes'
            else format('FALLO  lista %s', count(*)) end from upcoming;

reset role;

-- ---- saltear un periodo ----------------------------------------------------
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);
select count(*) as antes_skip from transaction \gset
select skip_scheduled((select id from scheduled_event where description='Seguro del auto')) as nueva \gset
select case when :'nueva'::date = date '2026-12-05' then 'ok  saltear adelanta un periodo'
            else 'FALLO  quedo en '||:'nueva' end;
select case when count(*) = :antes_skip then 'ok  saltear NO registra ningun movimiento'
            else 'FALLO  creo un movimiento' end from transaction;
reset role;

-- ---------------------------------------------------------------------------
-- Fin de mes: la regla que la aritmetica de fechas sola no puede sostener.
-- ---------------------------------------------------------------------------
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

insert into scheduled_event (ledger_id, kind, description, category_id, account_id,
                             amount, currency, frequency, next_on, month_end)
select my_ledger(), 'recurring', 'Alquiler fin de mes',
       (select id from category where name = 'Servicios'),
       (select id from account  where name = 'Banco ARS'),
       500000, 'ARS', 'monthly', date '2026-01-15', true;

select case when next_on = date '2026-01-31'
            then 'ok  al crearla con fin de mes, el 15 se corrige al 31'
            else format('FALLO  quedo en %s', next_on) end
  from scheduled_event where description = 'Alquiler fin de mes';

-- El caso que motivo todo: enero -> febrero, donde la aritmetica sola cae al 28
-- y ya no vuelve a subir.
update scheduled_event set next_on = avanzar_fecha(next_on, 'monthly')
 where description = 'Alquiler fin de mes';

select case when next_on = date '2026-02-28'
            then 'ok  febrero es 28: el ultimo dia, no una degradacion'
            else format('FALLO  dio %s', next_on) end
  from scheduled_event where description = 'Alquiler fin de mes';

-- Y ACA esta la diferencia. Sin la regla, de 28-feb en adelante se queda en 28.
update scheduled_event set next_on = avanzar_fecha(next_on, 'monthly')
 where description = 'Alquiler fin de mes';

select case when next_on = date '2026-03-31'
            then 'ok  marzo VUELVE al 31: sin la regla se habria quedado en 28'
            else format('FALLO  dio %s, se degrado', next_on) end
  from scheduled_event where description = 'Alquiler fin de mes';

-- Contraprueba: una regla comun no se toca.
insert into scheduled_event (ledger_id, kind, description, category_id, account_id,
                             amount, currency, frequency, next_on)
select my_ledger(), 'recurring', 'Netflix el 10',
       (select id from category where name = 'Servicios'),
       (select id from account  where name = 'Banco ARS'),
       9000, 'ARS', 'monthly', date '2026-01-10';

select case when next_on = date '2026-01-10'
            then 'ok  una regla sin fin de mes queda donde la pusieron'
            else format('FALLO  la movio a %s', next_on) end
  from scheduled_event where description = 'Netflix el 10';

reset role;

-- ---------------------------------------------------------------------------
-- Cuotas: proyectar cuando cae la deuda, sin contarla dos veces.  OD-23.
-- ---------------------------------------------------------------------------
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

-- Una heladera de 120.000 en 12 cuotas, comprada el 15 de octubre.
select create_transaction(
  date '2026-10-15', 'expense',
  jsonb_build_array(
    jsonb_build_object('account_id', (select id from account where name='Visa'),
                       'amount','-120000','unit','ARS'),
    jsonb_build_object('category_id',(select id from category where name='Supermercado'),
                       'amount','120000','unit','ARS')),
  'Heladera', 12) as heladera \gset

-- Lo primero y mas importante: la contabilidad NO cambia. La deuda entra entera
-- el dia 1 (ADR-004) y las cuotas son solo una proyeccion.
select case when sum(abs(amount)) = 120000
            then 'ok  la deuda se registra entera: las cuotas no la parten'
            else format('FALLO  la deuda quedo en %s', sum(abs(amount))) end
  from entry where transaction_id = :'heladera' and account_id is not null;

select case when count(*) = 12
            then 'ok  doce cuotas proyectadas de una sola compra'
            else format('FALLO  proyecto %s', count(*)) end
  from cuota where transaction_id = :'heladera';

select case when sum(monto) = 120000
            then 'ok  las doce suman exactamente lo comprado'
            else format('FALLO  suman %s', sum(monto)) end
  from cuota where transaction_id = :'heladera';

-- La primera cae en el resumen del mes SIGUIENTE a la compra.
select case when mes = date '2026-11-01'
            then 'ok  comprado en octubre, la primera cuota cae en noviembre'
            else format('FALLO  la primera cae en %s', mes) end
  from cuota where transaction_id = :'heladera' and numero = 1;

select case when mes = date '2027-10-01'
            then 'ok  y la ultima, doce meses despues'
            else format('FALLO  la ultima cae en %s', mes) end
  from cuota where transaction_id = :'heladera' and numero = 12;

-- El numero que el usuario queria: cuanto viene en cada resumen.
select case when total = 10000
            then 'ok  el resumen de noviembre trae 10.000 de esta compra'
            else format('FALLO  trae %s', total) end
  from resumen_tarjeta
 where tarjeta = 'Visa' and mes = date '2026-11-01';

-- Contraprueba: un consumo comun no genera cuotas ni ensucia la proyeccion.
select create_transaction(
  date '2026-10-16', 'expense',
  jsonb_build_array(
    jsonb_build_object('account_id', (select id from account where name='Visa'),
                       'amount','-5000','unit','ARS'),
    jsonb_build_object('category_id',(select id from category where name='Supermercado'),
                       'amount','5000','unit','ARS')),
  'Cafe');

select case when count(*) = 0
            then 'ok  un consumo de una sola cuota no aparece en la proyeccion'
            else format('FALLO  aparecieron %s cuotas', count(*)) end
  from cuota where description = 'Cafe';

reset role;
