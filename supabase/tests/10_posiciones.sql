-- Posiciones de mercado: comprar, valuar, vender.  ADR-012 familia 'market'.
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

-- ---- comprar ---------------------------------------------------------------
select comprar_activo('ETH','Ethereum','crypto','USDT',8,
                      (select id from account where name='Binance USDT'),
                      500, 0.2, 'Binance', current_date) as pos \gset

select case when unidades = 0.2 and invertido = 500
            then 'ok  registra unidades e invertido'
            else format('FALLO  unidades %s, invertido %s', unidades, invertido) end
  from posicion where account_id = :'pos';

select case when valor is null and ganancia is null
            then 'ok  sin precio cargado NO inventa un valor'
            else format('FALLO  dijo valor %s', valor) end
  from posicion where account_id = :'pos';

-- OJO con la invariante: en un intercambio los montos NO suman cero entre si
-- -son -500 USDT y +0.2 ETH- y lo que los relaciona es el cociente (ADR-010).
-- Lo verificable es que haya dos unidades y que ninguna quede en cero.
select case when count(*) = 2 and count(distinct unit) = 2
                 and count(*) filter (where amount = 0) = 0
            then 'ok  comprar es un intercambio de dos unidades, sin sumar cero'
            else format('FALLO  %s lineas, %s unidades', count(*), count(distinct unit)) end
  from entry where transaction_id = (
    select transaction_id from entry where account_id = :'pos' limit 1);

select case when round(abs(max(amount) filter (where unit='USDT'))
                     / max(amount) filter (where unit='ETH')) = 2500
            then 'ok  el precio unitario es el cociente: 500/0.2 = 2500'
            else 'FALLO  el cociente no da' end
  from entry where transaction_id = (
    select transaction_id from entry where account_id = :'pos' limit 1);

-- ---- valuar ----------------------------------------------------------------
insert into price (instrument_id, ledger_id, on_date, price, currency, source)
select (select id from instrument where symbol='ETH'), my_ledger(),
       current_date, 3000, 'USDT', 'manual';

select case when valor = 600 and ganancia = 100
            then 'ok  valua a precio de mercado y calcula la ganancia'
            else format('FALLO  valor %s, ganancia %s', valor, ganancia) end
  from posicion where account_id = :'pos';

-- ---- venta parcial ---------------------------------------------------------
select vender_activo(:'pos', 0.05,
                     (select id from account where name='Binance USDT'),
                     150, current_date) as tx \gset

select case when unidades = 0.15 and invertido = 350
            then 'ok  la venta parcial baja unidades e invertido'
            else format('FALLO  unidades %s, invertido %s', unidades, invertido) end
  from posicion where account_id = :'pos';

-- 0.15 x 3000 = 450 de valor, contra 350 invertidos
select case when valor = 450 and ganancia = 100
            then 'ok  la ganancia se mantiene tras una venta parcial'
            else format('FALLO  valor %s, ganancia %s', valor, ganancia) end
  from posicion where account_id = :'pos';

select case when count(*) = 2 and count(*) filter (where category_id is not null) = 0
            then 'ok  vender NO toca ninguna categoria de ingreso'
            else 'FALLO  imputo a una categoria' end
  from entry where transaction_id = :'tx';

-- ---- no se puede vender lo que no se tiene ---------------------------------
\set ON_ERROR_STOP off
select vender_activo(:'pos', 99, (select id from account where name='Binance USDT'), 100, current_date);
\set ON_ERROR_STOP on
select case when unidades = 0.15 then 'ok  rechaza vender mas de lo que hay'
            else format('FALLO  quedaron %s', unidades) end
  from posicion where account_id = :'pos';

-- ---- venta total -----------------------------------------------------------
select vender_activo(:'pos', 0.15,
                     (select id from account where name='Binance USDT'),
                     450, current_date);

select case when count(*) = 0 then 'ok  la posicion vendida entera sale de la lista'
            else 'FALLO  sigue apareciendo' end
  from posicion where account_id = :'pos';

select case when archived_at is not null then 'ok  se archiva, no se borra'
            else 'FALLO  quedo activa' end from account where id = :'pos';

select case when coalesce(sum(amount),0) = 0 then 'ok  queda en cero unidades'
            else format('FALLO  quedan %s', sum(amount)) end
  from entry where account_id = :'pos';

reset role;

-- ---------------------------------------------------------------------------
-- La lamina: un bono cotiza por 100 nominales, no por uno.  OD-39.
--
-- Sin esto una tenencia de 10.000 nominales valdria CIEN VECES de mas, y no
-- fallaria: mostraria un patrimonio enorme y perfectamente creible.
-- ---------------------------------------------------------------------------
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

insert into account (ledger_id, name, kind, valuation, unit, is_spendable)
values (my_ledger(), 'Broker bonos', 'asset', 'balance', 'ARS', false);

-- 10.000 nominales de un bono, pagando 8.000.000 de pesos.
select comprar_activo('AL30','Bonar 2030','bond','ARS',0,
                      (select id from account where name='Broker bonos'),
                      8000000, 10000, 'Balanz', current_date) as bono \gset

select case when quote_size = 100
            then 'ok  un bono nace cotizando por 100 nominales'
            else format('FALLO  nacio con lamina %s', quote_size) end
  from instrument where symbol = 'AL30';

-- El broker muestra 85.100. Eso es por CADA 100 nominales.
insert into price (instrument_id, ledger_id, on_date, price, currency, source)
select (select id from instrument where symbol='AL30'), my_ledger(),
       current_date, 85100, 'ARS', 'manual';

-- 10.000 x 85.100 / 100 = 8.510.000. Sin dividir daria 851.000.000.
select case when valor_nativo = 8510000
            then 'ok  10.000 nominales a 85.100 por cien valen 8.510.000'
            else format('FALLO  dio %s', valor_nativo) end
  from valor_inversion where account_id = :'bono';

select case when valor = 8510000
            then 'ok  y la lista de posiciones dice lo mismo'
            else format('FALLO  la posicion dice %s', valor) end
  from posicion where account_id = :'bono';

-- Contraprueba: una accion cotiza por unidad y no se toca.
select comprar_activo('YPFD','YPF','stock','ARS',0,
                      (select id from account where name='Broker bonos'),
                      87350, 10, 'Balanz', current_date) as accion \gset

select case when quote_size = 1
            then 'ok  una accion sigue cotizando por unidad'
            else format('FALLO  la accion nacio con lamina %s', quote_size) end
  from instrument where symbol = 'YPFD';

reset role;

-- ---------------------------------------------------------------------------
-- Comprar en una moneda algo que cotiza en otra.  OD-58
--
-- Todo lo de arriba compra con una cuenta en la MISMA moneda en la que cotiza el
-- activo, y por eso la suite entera se perdio el defecto: `invertido` salia en
-- la moneda de la cuenta y se restaba de un `valor` en la moneda de cotizacion.
-- El caso que faltaba es el mas comun de todos: mandar pesos y comprar cripto.
-- ---------------------------------------------------------------------------
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

insert into account (ledger_id, name, kind, valuation, unit, is_spendable, institution)
values (my_ledger(), 'Binance pesos', 'asset', 'balance', 'ARS', false, 'Binance');

-- 1.500.000 pesos por 0,01 BTC, con el BTC a 100.000 USDT. Con el dolar a 1.500
-- eso es exactamente 1.000 USD: la posicion no gano ni perdio nada.
select comprar_activo('BTCX','Bitcoin','crypto','USDT',8,
                      (select id from account where name='Binance pesos'),
                      1500000, 0.01, 'Binance', current_date) as btc \gset

insert into price (instrument_id, ledger_id, on_date, price, currency, source)
select (select id from instrument where symbol='BTCX'), my_ledger(),
       current_date, 100000, 'USDT', 'manual';

-- Primero SIN cotizacion: lo invertido no es cero, es desconocido. Con el
-- coalesce que tenia la vista esto daba invertido = 0 y la posicion entera como
-- ganancia -un numero enorme y perfectamente creible-.
select case when invertido is null and ganancia is null
            then 'ok  sin cotizacion dice que no sabe, no cero'
            else format('FALLO  invertido %s, ganancia %s', invertido, ganancia) end
  from posicion where account_id = :'btc';

insert into fx_rate (ledger_id, on_date, base, quote, rate, source)
values (my_ledger(), current_date, 'USD','ARS', 1500, 'mep');

select case when round(invertido, 2) = 1000.00 and round(ganancia, 2) = 0.00
            then 'ok  lo invertido se convierte a la moneda en que cotiza'
            else format('FALLO  invertido %s, ganancia %s', invertido, ganancia) end
  from posicion where account_id = :'btc';

-- Y al reves: un CEDEAR cotiza en PESOS y se paga con los dolares del broker.
-- Ademas nace midiendose al CCL (ADR-024), no al dolar del libro: con el mep
-- -1.500- lo invertido daria 1.500.000 y una ganancia de 100.000 de la nada.
insert into account (ledger_id, name, kind, valuation, unit, is_spendable, institution)
values (my_ledger(), 'Balanz dolares', 'asset', 'balance', 'USD', false, 'Balanz');

insert into fx_rate (ledger_id, on_date, base, quote, rate, source)
values (my_ledger(), current_date, 'USD','ARS', 1600, 'ccl');

select comprar_activo('AAPLX','Apple','cedear','ARS',0,
                      (select id from account where name='Balanz dolares'),
                      1000, 50, 'Balanz', current_date, 20, 'AAPL') as ced \gset

insert into price (instrument_id, ledger_id, on_date, price, currency, source)
select (select id from instrument where symbol='AAPLX'), my_ledger(),
       current_date, 32000, 'ARS', 'manual';

select case when round(invertido, 2) = 1600000.00 and round(ganancia, 2) = 0.00
            then 'ok  usa la fuente de LA POSICION (ccl), no la del libro'
            else format('FALLO  invertido %s, ganancia %s', invertido, ganancia) end
  from posicion where account_id = :'ced';

reset role;
