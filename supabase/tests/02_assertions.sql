\set ON_ERROR_STOP on
-- Cada assert falla RUIDOSAMENTE. Un test que no puede fallar no prueba nada.
create or replace function assert_eq(p_label text, p_got numeric, p_want numeric)
returns void language plpgsql as $$
begin
  if p_got is distinct from p_want then
    raise exception 'FALLO  %  -> obtuvo %, esperaba %', p_label, p_got, p_want;
  end if;
  raise notice 'ok  %  = %', p_label, p_got;
end $$;

-- ---- saldos por cuenta (modelo-de-datos.md §6) ----
select assert_eq('saldo Banco ARS',       (select balance from account_balance where name='Banco ARS'),        92500);
select assert_eq('saldo Visa (pasivo)',   (select balance from account_balance where name='Visa'),                 0);
select assert_eq('saldo Efectivo USD',    (select balance from account_balance where name='Efectivo USD'),      1000);
select assert_eq('saldo Mercado Pago',    (select balance from account_balance where name='Mercado Pago'),     12400);
select assert_eq('saldo Balanz efectivo', (select balance from account_balance where name='Balanz efectivo'), 550000);
select assert_eq('unidades Balanz AAPL',  (select balance from account_balance where name='Balanz AAPL'),          0);
select assert_eq('unidades Binance BTC',  (select balance from account_balance where name='Binance BTC'),    0.00512);
select assert_eq('saldo Plazo fijo',      (select balance from account_balance where name='Plazo fijo 90d'),       0);

-- ---- ADR-004: pagar el resumen NO es un gasto ----
select assert_eq('gasto imputado a Restaurantes (no se duplica)',
  (select coalesce(sum(e.amount),0) from entry e
     join category c on c.id=e.category_id where c.name='Restaurantes'), 18000);

-- ---- EL ASSERT QUE IMPORTA: el error 1 del analisis ----
-- En septiembre se movieron 1.450.000 a dolares, 500.000 a Balanz y 1.000.000 a un
-- plazo fijo. Si el ahorro y la inversion se restaran del resultado, este numero seria
-- negativo. La formula correcta ni los ve, porque no tocan ninguna categoria.
select assert_eq('resultado de septiembre (ingresos - gastos)',
  (select -sum(e.amount) from entry e
     join transaction t on t.id=e.transaction_id
    where e.category_id is not null
      and t.occurred_on between date '2026-09-01' and date '2026-09-30'), 1964900);

-- ---- "cuanto tengo disponible" (punto 8 del brief) ----
select assert_eq('disponible en ARS',
  (select sum(balance) from account_balance where is_spendable and unit='ARS'), 104900);
