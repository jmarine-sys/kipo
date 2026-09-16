-- CEDEARs: separar el rendimiento del activo del movimiento del dolar.  OD-17.
--
-- El caso que lo demuestra: la accion NO se mueve y el CCL sube. El precio del
-- CEDEAR en pesos se duplica sin que hayas ganado un dolar.
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

insert into fx_rate (ledger_id, on_date, base, quote, rate, source) values
  (my_ledger(), current_date - 100, 'USD','ARS', 1400, 'ccl'),
  (my_ledger(), current_date,       'USD','ARS', 2000, 'ccl'),
  (my_ledger(), current_date - 100, 'USD','ARS', 1300, 'mep'),
  (my_ledger(), current_date,       'USD','ARS', 1800, 'mep')
on conflict (ledger_id, on_date, base, quote, source) do update set rate = excluded.rate;

-- Una cuenta en pesos para operar en el broker
insert into account (ledger_id, name, kind, valuation, unit, is_spendable, institution)
values (my_ledger(), 'Balanz pesos', 'asset', 'balance', 'ARS', false, 'Balanz');

-- MELI a 2000 USD, ratio 200: un CEDEAR equivale a 10 USD de la accion.
-- (se usa otro simbolo que AAPL porque el test 01 ya lo tiene creado al MEP)
-- Con CCL 1400, el CEDEAR cotiza a 14.000 pesos. Compramos 10 por 140.000.
select comprar_activo('MELI-CEDEAR','Mercado Libre (CEDEAR)','cedear','ARS',0,
                      (select id from account where name='Balanz pesos'),
                      140000, 10, 'Balanz', current_date - 100, 200, 'MELI') as ced \gset

select case when fx_source = 'ccl'
            then 'ok  un CEDEAR nace midiendose al CCL, no al dolar del libro'
            else format('FALLO  nacio con %s', fx_source) end
  from valor_inversion where account_id = :'ced';

select case when round(usd) = -100
            then 'ok  140.000 pesos al CCL de ese dia son 100 dolares invertidos'
            else format('FALLO  dio %s', round(usd)) end
  from flujo_inversion where account_id = :'ced';

-- Pasa el tiempo. AAPL sigue en 200 USD. El CCL paso de 1400 a 2000, asi que el
-- CEDEAR ahora cotiza 10 x 2000 = 20.000 pesos.
insert into price (instrument_id, ledger_id, on_date, price, currency, source)
select (select id from instrument where symbol='MELI-CEDEAR'), my_ledger(),
       current_date, 20000, 'ARS', 'manual';

select case when valor_nativo = 200000
            then 'ok  en pesos la posicion se duplico: 140.000 a 200.000'
            else format('FALLO  vale %s', valor_nativo) end
  from valor_inversion where account_id = :'ced';

-- Y aca esta todo: al CCL, ese "aumento" desaparece. No ganaste un dolar,
-- porque la accion no se movio: se movio el tipo de cambio.
select case when round(usd) = 100
            then 'ok  al CCL vale los mismos 100 dolares: la suba era el dolar'
            else format('FALLO  dio %s', round(usd)) end
  from valor_inversion where account_id = :'ced';

-- Contraste: si se midiera al MEP aparecería una ganancia que no existe.
select case when round(convertir(200000,'ARS',current_date,'USD','mep')) = 111
            then 'ok  al MEP mostraria 111 dolares: una ganancia fantasma de 11%'
            else format('FALLO  dio %s', round(convertir(200000,'ARS',current_date,'USD','mep'))) end;

-- ---- y cuando la accion SI se mueve, se ve ---------------------------------
-- MELI sube 10%. Con CCL 2000, el CEDEAR pasa a 11 x 2000 = 22.000.
insert into price (instrument_id, ledger_id, on_date, price, currency, source)
select (select id from instrument where symbol='MELI-CEDEAR'), my_ledger(),
       current_date, 22000, 'ARS', 'manual'
on conflict (instrument_id, on_date, source) do update set price = excluded.price;

select case when round(usd) = 110
            then 'ok  si la accion sube 10%, el CEDEAR marca 110 dolares'
            else format('FALLO  dio %s', round(usd)) end
  from valor_inversion where account_id = :'ced';

reset role;
