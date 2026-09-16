-- El portafolio es el borde.  OD-33 / ADR-026.
--
-- El caso que lo demuestra: dentro del broker la plata cambia de forma tres
-- veces -dolares, bitcoin, dolares otra vez- y NADA de eso es un aporte. Lo
-- unico que cruzo el borde fueron los 1000 que entraron desde el banco.
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

insert into fx_rate (ledger_id, on_date, base, quote, rate, source) values
  (my_ledger(), current_date - 200, 'USD','ARS', 1000, 'cripto'),
  (my_ledger(), current_date,       'USD','ARS', 1600, 'cripto')
on conflict (ledger_id, on_date, base, quote, source) do update set rate = excluded.rate;

insert into portfolio (ledger_id, name, fx_source)
values (my_ledger(), 'Mi Binance', 'cripto');
select id as pf from portfolio where name = 'Mi Binance' \gset

-- El efectivo del broker: una cuenta comun, pero ADENTRO del portafolio.
insert into account (ledger_id, name, kind, valuation, unit, is_spendable, institution, portfolio_id)
values (my_ledger(), 'Binance efectivo', 'asset', 'balance', 'USD', false, 'Binance', :'pf');
select id as bin from account where name = 'Binance efectivo' \gset

-- El banco de afuera, desde donde sale la plata de verdad.
insert into account (ledger_id, name, kind, valuation, unit, is_spendable, institution)
values (my_ledger(), 'Banco dolares', 'asset', 'balance', 'USD', true, 'Banco');
select id as bco from account where name = 'Banco dolares' \gset

insert into category (ledger_id, name, kind) values (my_ledger(), 'Intereses cripto', 'income');
select id as cat from category where name = 'Intereses cripto' \gset

-- ---------------------------------------------------------------------------
-- Dia 1: entran 1000 dolares desde el banco. ESTO es un aporte.
-- ---------------------------------------------------------------------------
select create_transaction(
  current_date - 200, 'transfer',
  jsonb_build_array(
    jsonb_build_object('account_id', :'bco', 'amount','-1000','unit','USD'),
    jsonb_build_object('account_id', :'bin', 'amount','1000','unit','USD')),
  'Deposito al broker');

select case when count(*) = 1 and round(min(usd)) = -1000
            then 'ok  el deposito desde el banco es un aporte de 1000 dolares'
            else format('FALLO  %s flujos, usd %s', count(*), round(min(usd))) end
  from flujo_portafolio where portfolio_id = :'pf';

select case when round(usd) = 1000
            then 'ok  el efectivo quieto en el broker VALE: 1000 dolares'
            else format('FALLO  el portafolio vale %s', round(usd)) end
  from valor_portafolio where portfolio_id = :'pf';

-- ---------------------------------------------------------------------------
-- Dia 140: con esa plata se compran 0,01 LTC a 50.000. Misma plata, otra forma.
--
-- OJO con el simbolo: toda la bateria corre contra LA MISMA base y
-- comprar_activo REUTILIZA el instrumento si ya existe -que es lo correcto-.
-- Usar 'BTC' acá hacía que este test heredara la posicion del test 12: dos
-- flujos donde tenia que haber uno, y el portafolio valuado en 1407.
-- ---------------------------------------------------------------------------
select comprar_activo('LTC','Litecoin','crypto','USD',8, :'bin',
                      500, 0.01, 'Binance', current_date - 60) as btc \gset

update account set portfolio_id = :'pf' where id = :'btc';

select case when count(*) = 1
            then 'ok  comprar ADENTRO no es un aporte nuevo: sigue habiendo 1 flujo'
            else format('FALLO  aparecieron %s flujos', count(*)) end
  from flujo_portafolio where portfolio_id = :'pf';

insert into price (instrument_id, ledger_id, on_date, price, currency, source)
select a.instrument_id, my_ledger(), current_date, 60000, 'USD', 'manual'
  from account a where a.id = :'btc';

-- 500 de efectivo + 0,01 LTC a 60.000 = 500 + 600 = 1100
select case when round(usd) = 1100
            then 'ok  el portafolio vale efectivo MAS posiciones: 500 + 600'
            else format('FALLO  vale %s', round(usd)) end
  from valor_portafolio where portfolio_id = :'pf';

-- ---------------------------------------------------------------------------
-- El broker paga un interes. Es rendimiento generado adentro, no plata tuya.
-- ---------------------------------------------------------------------------
select create_transaction(
  current_date - 10, 'income',
  jsonb_build_array(
    jsonb_build_object('account_id',  :'bin', 'amount','20','unit','USD'),
    jsonb_build_object('category_id', :'cat', 'amount','-20','unit','USD')),
  'Interes del broker');

select case when count(*) = 1
            then 'ok  el interes que paga el broker NO es aporte: es rendimiento'
            else format('FALLO  aparecieron %s flujos', count(*)) end
  from flujo_portafolio where portfolio_id = :'pf';

select case when round(usd) = 1120
            then 'ok  pero SI sube el valor del portafolio: 1100 a 1120'
            else format('FALLO  vale %s', round(usd)) end
  from valor_portafolio where portfolio_id = :'pf';

-- ---------------------------------------------------------------------------
-- Se retiran 300 al banco. Eso SI cruza el borde, en el otro sentido.
-- ---------------------------------------------------------------------------
select create_transaction(
  current_date, 'transfer',
  jsonb_build_array(
    jsonb_build_object('account_id', :'bin', 'amount','-300','unit','USD'),
    jsonb_build_object('account_id', :'bco', 'amount','300','unit','USD')),
  'Retiro del broker');

select case when count(*) = 2 and round(sum(usd)) = -700
            then 'ok  el retiro cruza el borde: aporte neto 1000 - 300 = 700'
            else format('FALLO  %s flujos, neto %s', count(*), round(sum(usd))) end
  from flujo_portafolio where portfolio_id = :'pf';

-- Y la comprobacion que resume el ADR entero: la plata se movio cinco veces
-- adentro y el aporte sigue llevando la fecha en que CRUZO, no la de la compra.
select case when min(fecha) = current_date - 200
            then 'ok  el aporte lleva la fecha del DEPOSITO, no la de la compra'
            else format('FALLO  el primer flujo es del %s', min(fecha)) end
  from flujo_portafolio where portfolio_id = :'pf' and usd < 0;
