-- Flujos de inversion y valuacion, en las dos varas.
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

-- cotizaciones para las fechas que se van a usar
insert into fx_rate (ledger_id, on_date, base, quote, rate, source) values
  (my_ledger(), current_date - 200, 'USD','ARS', 1000, 'mep'),
  (my_ledger(), current_date,       'USD','ARS', 1500, 'mep'),
  (my_ledger(), current_date - 200, 'UVA','ARS', 1500, 'uva'),
  (my_ledger(), current_date,       'UVA','ARS', 2100, 'uva')
on conflict (ledger_id, on_date, base, quote, source) do update set rate = excluded.rate;

-- ---- un plazo fijo: constituir y vencer ------------------------------------
select create_plazo_fijo('PF medicion',
                         (select id from account where name='Banco Nacion'),
                         1000000, current_date + 10, 1200000, null,
                         current_date - 200) as pf \gset

-- 1.000.000 pesos a 1000 por dolar = 1000 USD que salieron
select case when round(usd) = -1000
            then 'ok  el aporte se valua al dolar de SU fecha, no al de hoy'
            else format('FALLO  dio %s', round(usd)) end
  from flujo_inversion where account_id = :'pf';

-- 1.000.000 / 1500 UVAs = 666,67 UVAs de poder adquisitivo
select case when round(uva, 2) = -666.67
            then 'ok  y tambien en poder adquisitivo'
            else format('FALLO  dio %s', round(uva,2)) end
  from flujo_inversion where account_id = :'pf';

-- EL numero del proyecto: los pesos no se movieron -siguen siendo 1.000.000-
-- pero el dolar paso de 1000 a 1500. En pesos "no perdiste"; en dolares
-- perdiste un tercio. Es el error 6 del analisis, medido.
select case when round(usd) = 667
            then format('ok  costo 1000 dolares y hoy vale %s: la ilusion, medida', round(usd))
            else format('FALLO  vale %s', round(usd)) end
  from valor_inversion where account_id = :'pf';

-- vencerlo: el flujo tiene que ser el TOTAL que volvio, no el capital
select register_maturity((select id from upcoming where account_id = :'pf'),
                         1200000, null, current_date) as tx \gset

select case when count(*) = 2 and round(max(monto)) = 1200000
            then 'ok  el flujo del vencimiento es el TOTAL, no el capital'
            else format('FALLO  %s flujos, maximo %s', count(*), round(max(monto))) end
  from flujo_inversion where account_id = :'pf';

-- ---- una posicion de mercado -----------------------------------------------
select comprar_activo('DOT','Polkadot','crypto','USDT',8,
                      (select id from account where name='Binance USDT'),
                      400, 100, 'Binance', current_date - 200) as pos \gset

select case when usd = -400
            then 'ok  un aporte en USDT ya esta en dolares'
            else format('FALLO  dio %s', usd) end
  from flujo_inversion where account_id = :'pos';

-- 400 USD x 1000 = 400.000 pesos, / 1500 = 266,67 UVAs
select case when round(uva, 2) = -266.67
            then 'ok  los dolares pasan por pesos de ese dia para dar UVAs'
            else format('FALLO  dio %s', round(uva,2)) end
  from flujo_inversion where account_id = :'pos';

select case when valor_nativo is null and usd is null
            then 'ok  sin precio cargado no inventa un valor'
            else format('FALLO  dijo %s', valor_nativo) end
  from valor_inversion where account_id = :'pos';

insert into price (instrument_id, ledger_id, on_date, price, currency, source)
select (select id from instrument where symbol='DOT'), my_ledger(),
       current_date, 6, 'USDT', 'manual';

select case when valor_nativo = 600 and usd = 600
            then 'ok  100 unidades a 6 valen 600'
            else format('FALLO  nativo %s, usd %s', valor_nativo, usd) end
  from valor_inversion where account_id = :'pos';

-- 600 USD x 1500 = 900.000 pesos, / 2100 = 428,57 UVAs
select case when round(uva, 2) = 428.57
            then 'ok  y en poder adquisitivo de hoy'
            else format('FALLO  dio %s', round(uva,2)) end
  from valor_inversion where account_id = :'pos';

reset role;
