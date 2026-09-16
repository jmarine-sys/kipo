-- Plazos fijos: constituir y vencer.  ADR-014, caso 5.12 de modelo-de-datos.
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

-- patrimonio en ARS antes de todo
select coalesce(sum(e.amount),0) as pat0 from entry e
  join account a on a.id = e.account_id where e.unit = 'ARS' \gset

select coalesce(sum(amount),0) as banco0 from entry e
  where account_id = (select id from account where name='Banco Nacion') \gset

-- ---- constituir ------------------------------------------------------------
select create_plazo_fijo('Plazo fijo 90 días',
                         (select id from account where name='Banco Nacion'),
                         1000000, current_date + 90, 1090000, 'Santander',
                         current_date) as pf \gset

select case when valuation = 'accrual' and not is_spendable
                 and matures_on = current_date + 90 and expected_amount = 1090000
            then 'ok  crea la cuenta como devengable e inmovilizada'
            else 'FALLO  quedo mal configurada' end
  from account where id = :'pf';

select case when coalesce(sum(amount),0) = 1000000
            then 'ok  el capital quedo en el plazo fijo'
            else format('FALLO  tiene %s', coalesce(sum(amount),0)) end
  from entry where account_id = :'pf';

select case when coalesce(sum(amount),0) = :banco0 - 1000000
            then 'ok  salio del banco'
            else 'FALLO  el banco quedo mal' end
  from entry where account_id = (select id from account where name='Banco Nacion');

-- LA aserción: mover plata al plazo fijo NO cambia el patrimonio
select case when coalesce(sum(e.amount),0) = :pat0
            then 'ok  constituirlo NO mueve el patrimonio'
            else format('FALLO  el patrimonio paso de %s a %s', :pat0, coalesce(sum(e.amount),0)) end
  from entry e join account a on a.id = e.account_id where e.unit = 'ARS';

select case when count(*) = 1 then 'ok  agenda su vencimiento'
            else 'FALLO  no lo agendo' end
  from upcoming where kind = 'maturity' and account_id = :'pf';

select case when capital = 1000000 and counter_account_name = 'Banco Nacion'
            then 'ok  la agenda sabe cuanto hay y a donde vuelve'
            else format('FALLO  capital %s, vuelve a %s', capital, counter_account_name) end
  from upcoming where account_id = :'pf';

-- ---- validaciones ----------------------------------------------------------
\set ON_ERROR_STOP off
select create_plazo_fijo('Imposible', (select id from account where name='Banco Nacion'),
                         100000, current_date + 30, 90000, null, current_date);
select create_plazo_fijo('Ayer', (select id from account where name='Banco Nacion'),
                         100000, current_date - 1, 110000, null, current_date);
\set ON_ERROR_STOP on
select case when count(*) = 0 then 'ok  rechaza que vuelva menos que el capital, y vencer en el pasado'
            else format('FALLO  creo %s invalidos', count(*)) end
  from account where name in ('Imposible','Ayer');

-- ---- vencer ----------------------------------------------------------------
select coalesce(sum(e.amount),0) as pat1 from entry e
  join account a on a.id = e.account_id where e.unit = 'ARS' \gset

select register_maturity((select id from upcoming where account_id = :'pf'),
                         null, null, current_date) as tx \gset

select case when count(*) = 3 and sum(amount) = 0
            then 'ok  tres lineas que balancean'
            else format('FALLO  %s lineas, suman %s', count(*), sum(amount)) end
  from entry where transaction_id = :'tx';

select case when coalesce(sum(amount),0) = 0
            then 'ok  el plazo fijo queda en cero'
            else format('FALLO  quedo con %s', coalesce(sum(amount),0)) end
  from entry where account_id = :'pf';

select case when amount = -90000
            then 'ok  el interes se reconoce como ingreso'
            else format('FALLO  imputo %s', amount) end
  from entry e join category c on c.id = e.category_id
 where e.transaction_id = :'tx' and c.is_system and c.kind = 'income';

-- y la otra aserción central: el patrimonio sube EXACTAMENTE el interes
select case when coalesce(sum(e.amount),0) = :pat1 + 90000
            then 'ok  el patrimonio sube exactamente el interes'
            else format('FALLO  esperaba %s, hay %s', :pat1 + 90000, coalesce(sum(e.amount),0)) end
  from entry e join account a on a.id = e.account_id where e.unit = 'ARS';

select case when archived_at is not null then 'ok  archiva el plazo fijo cumplido'
            else 'FALLO  quedo activo' end from account where id = :'pf';

select case when count(*) = 0 then 'ok  sale de la agenda'
            else 'FALLO  sigue agendado' end from upcoming where account_id = :'pf';

-- ---- vencer con un importe distinto al esperado ----------------------------
select create_plazo_fijo('PF corto', (select id from account where name='Banco Nacion'),
                         500000, current_date + 30, 540000, null, current_date) as pf2 \gset
select register_maturity((select id from upcoming where account_id = :'pf2'),
                         535000, null, current_date) as tx2 \gset
select case when amount = -35000
            then 'ok  calcula el interes sobre lo que REALMENTE volvio'
            else format('FALLO  imputo %s', amount) end
  from entry e join category c on c.id = e.category_id
 where e.transaction_id = :'tx2' and c.is_system and c.kind = 'income';

reset role;
