-- Los 13 casos de uso de docs/modelo-de-datos.md §5, ejecutados contra el esquema real.
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'test@kipo.local');

select set_config('test.uid', '11111111-1111-1111-1111-111111111111', false);

-- el trigger de alta ya creo el libro, las categorias y "Efectivo ARS"
create temp view l as select id from ledger limit 1;

-- cuentas del inventario real del usuario
insert into instrument (ledger_id, symbol, name, kind, quote_currency, decimals, ratio, underlying_symbol)
  select id,'AAPL-CEDEAR','Apple (CEDEAR)','cedear','ARS',0,20,'AAPL' from l;
insert into instrument (ledger_id, symbol, name, kind, quote_currency, decimals)
  select id,'BTC','Bitcoin','crypto','USD',8 from l;

insert into account (ledger_id,name,kind,valuation,unit,is_spendable,fx_source,institution)
  select id,'Banco ARS','asset','balance','ARS',true,null,'Santander' from l;
insert into account (ledger_id,name,kind,valuation,unit,is_spendable,fx_source)
  select id,'Efectivo USD','asset','balance','USD',true,'blue' from l;
insert into account (ledger_id,name,kind,valuation,unit,is_spendable)
  select id,'Mercado Pago','asset','balance','ARS',true from l;
insert into account (ledger_id,name,kind,valuation,unit,is_spendable)
  select id,'Visa','liability','balance','ARS',false from l;
insert into account (ledger_id,name,kind,valuation,unit,is_spendable,fx_source)
  select id,'Balanz efectivo','asset','balance','ARS',false,'mep' from l;
insert into account (ledger_id,name,kind,valuation,unit,instrument_id,is_spendable,fx_source)
  select l.id,'Balanz AAPL','asset','market','AAPL-CEDEAR',i.id,false,'mep'
    from l, instrument i where i.symbol='AAPL-CEDEAR';
insert into account (ledger_id,name,kind,valuation,unit,is_spendable)
  select id,'Binance USDT','asset','balance','USDT',false from l;
insert into account (ledger_id,name,kind,valuation,unit,instrument_id,is_spendable)
  select l.id,'Binance BTC','asset','market','BTC',i.id,false
    from l, instrument i where i.symbol='BTC';
insert into account (ledger_id,name,kind,valuation,unit,is_spendable,matures_on,expected_amount)
  select id,'Plazo fijo 90d','asset','accrual','ARS',false,date '2026-12-14',1090000 from l;

-- helper: arma una transaccion con sus lineas
create or replace function mk(p_kind text, p_desc text, p_when date,
                              p_acc text[], p_cat text[], p_amt numeric[], p_unit text[])
returns uuid language plpgsql as $$
declare v_tx uuid; v_l uuid; i int;
begin
  select id into v_l from ledger limit 1;
  insert into transaction (ledger_id, occurred_on, description, kind, created_by)
    values (v_l, p_when, p_desc, p_kind, '11111111-1111-1111-1111-111111111111')
    returning id into v_tx;
  for i in 1 .. array_length(p_amt,1) loop
    insert into entry (transaction_id, ledger_id, account_id, category_id, amount, unit)
    values (v_tx, v_l,
      (select id from account  where ledger_id=v_l and name=p_acc[i]),
      (select id from category where ledger_id=v_l and name=p_cat[i]),
      p_amt[i], p_unit[i]);
  end loop;
  return v_tx;
end $$;

begin;
-- 5.1 gasto con debito
select mk('expense','Chino de la esquina',date '2026-09-02',
  array['Banco ARS',null], array[null,'Supermercado'],
  array[-25000,25000]::numeric[], array['ARS','ARS']);
-- 5.2 gasto con tarjeta (ADR-004)
select mk('expense','Cena',date '2026-09-03',
  array['Visa',null], array[null,'Restaurantes'],
  array[-18000,18000]::numeric[], array['ARS','ARS']);
-- 5.4 sueldo
select mk('income','Sueldo septiembre',date '2026-09-05',
  array['Banco ARS',null], array[null,'Sueldo'],
  array[2000000,-2000000]::numeric[], array['ARS','ARS']);
-- 5.3 pago del resumen: NINGUNA categoria participa
select mk('transfer','Pago resumen Visa',date '2026-09-10',
  array['Banco ARS','Visa'], array[null,null],
  array[-18000,18000]::numeric[], array['ARS','ARS']);
-- 5.5 compra de dolar blue: 2 unidades, el tipo de cambio es el cociente (ADR-010)
select mk('exchange','USD 1000 @ 1450',date '2026-09-11',
  array['Banco ARS','Efectivo USD'], array[null,null],
  array[-1450000,1000]::numeric[], array['ARS','USD']);
-- 5.6 transferencia a Balanz
select mk('transfer','A Balanz',date '2026-09-12',
  array['Banco ARS','Balanz efectivo'], array[null,null],
  array[-500000,500000]::numeric[], array['ARS','ARS']);
-- 5.7 compra de CEDEARs
select mk('trade','50 AAPL @ 3000',date '2026-09-12',
  array['Balanz efectivo','Balanz AAPL'], array[null,null],
  array[-150000,50]::numeric[], array['ARS','AAPL-CEDEAR']);
-- 5.8 venta de CEDEARs: el patrimonio NO cambia (error 7)
select mk('trade','Venta 50 AAPL @ 4000',date '2026-09-13',
  array['Balanz AAPL','Balanz efectivo'], array[null,null],
  array[-50,200000]::numeric[], array['AAPL-CEDEAR','ARS']);
-- 5.9 cripto con 8 decimales
select mk('trade','BTC',date '2026-09-13',
  array['Binance USDT','Binance BTC'], array[null,null],
  array[-500,0.00512]::numeric[], array['USDT','BTC']);
-- 5.10 interes mensual de Mercado Pago (ADR-013)
select mk('income','Interes MP septiembre',date '2026-09-30',
  array['Mercado Pago',null], array[null,'Intereses'],
  array[12400,-12400]::numeric[], array['ARS','ARS']);
-- 5.11 constituir plazo fijo (ADR-014)
select mk('transfer','Plazo fijo 90d',date '2026-09-15',
  array['Banco ARS','Plazo fijo 90d'], array[null,null],
  array[-1000000,1000000]::numeric[], array['ARS','ARS']);
-- 5.12 vencimiento: 3 lineas, UNA unidad, suma cero
select mk('income','Vencimiento plazo fijo',date '2026-12-14',
  array['Plazo fijo 90d','Banco ARS',null], array[null,null,'Intereses'],
  array[-1000000,1090000,-90000]::numeric[], array['ARS','ARS','ARS']);
-- 5.13 ajuste de saldo (ADR-005)
select mk('adjustment','Ajuste banco',date '2026-09-14',
  array['Banco ARS',null], array[null,'Ajustes'],
  array[-4500,4500]::numeric[], array['ARS','ARS']);
commit;
