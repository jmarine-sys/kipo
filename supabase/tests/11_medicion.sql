-- Medir en dolares y en poder adquisitivo.
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

-- viernes y lunes, con un salto entre medio
insert into fx_rate (ledger_id, on_date, base, quote, rate, source) values
  (my_ledger(), date '2026-03-13', 'USD','ARS', 1400, 'mep'),
  (my_ledger(), date '2026-03-16', 'USD','ARS', 1500, 'mep'),
  (my_ledger(), date '2026-03-13', 'UVA','ARS', 2000, 'uva'),
  (my_ledger(), date '2026-03-16', 'UVA','ARS', 2020, 'uva');

-- ---- que cotizacion rige un sabado -----------------------------------------
select case when cotizacion(date '2026-03-14','mep') = 1400
            then 'ok  el sabado rige la del viernes, no la del lunes'
            else format('FALLO  uso %s', cotizacion(date '2026-03-14','mep')) end;

select case when cotizacion(date '2026-03-12','mep') is null
            then 'ok  antes del primer dato no inventa nada'
            else 'FALLO  devolvio algo' end;

-- ---- a dolares -------------------------------------------------------------
select case when round(convertir(140000,'ARS',date '2026-03-14','USD'), 2) = 100.00
            then 'ok  pesos a dolares a la cotizacion de SU fecha'
            else format('FALLO  dio %s', convertir(140000,'ARS',date '2026-03-14','USD')) end;

select case when convertir(500,'USDT',date '2026-03-14','USD') = 500
            then 'ok  USDT se toma como dolar'
            else 'FALLO' end;

select case when round(convertir(140000,'ARS',date '2026-03-17','USD'), 4) = round(140000::numeric/1500, 4)
            then 'ok  despues del salto usa la nueva'
            else format('FALLO  dio %s', convertir(140000,'ARS',date '2026-03-17','USD')) end;

-- ---- a poder adquisitivo ---------------------------------------------------
select case when convertir(100000,'ARS',date '2026-03-14','UVA') = 50
            then 'ok  pesos a UVAs: 100.000 / 2.000 = 50'
            else format('FALLO  dio %s', convertir(100000,'ARS',date '2026-03-14','UVA')) end;

-- 100 USD x 1400 = 140.000 pesos, / 2.000 = 70 UVAs
select case when convertir(100,'USD',date '2026-03-14','UVA') = 70
            then 'ok  dolares a UVAs: pasa por pesos de ese dia'
            else format('FALLO  dio %s', convertir(100,'USD',date '2026-03-14','UVA')) end;

-- ---- lo que NO puede calcular lo dice ---------------------------------------
select case when convertir(100000,'ARS',date '2020-01-01','USD') is null
            then 'ok  sin cotizacion devuelve NULL, no un numero inventado'
            else 'FALLO  invento un valor' end;

select case when convertir(0.5,'BTC',date '2026-03-14','USD') is null
            then 'ok  una unidad que no es moneda no se convierte sin su precio'
            else 'FALLO  la convirtio igual' end;

-- Una cotizacion de marzo cubre formalmente a septiembre, pero valuar con un
-- dato de hace medio anio no es medir. La vista tiene que marcarlo.
select case when count(*) filter (where dolar_viejo) > 0
            then format('ok  marca %s fechas con cotizacion desfasada', count(*) filter (where dolar_viejo))
            else 'FALLO  no detecto el desfasaje' end
  from medicion_faltante;

-- Una inversion anterior a la primera cotizacion cargada: el caso real de quien
-- empieza a usar la app teniendo ya cosas compradas.
select comprar_activo('SOL','Solana','crypto','USDT',8,
                      (select id from account where name='Binance USDT'),
                      200, 2, 'Binance', date '2026-01-15');

select case when count(*) > 0 then 'ok  detecta tambien las fechas sin ningun dato'
            else 'FALLO  no marco la fecha anterior a toda cotizacion' end
  from medicion_faltante where sin_dolar;

-- ---- la diferencia entre las dos varas -------------------------------------
-- El dolar subio 7,1% (1400 a 1500) y los precios 1% (2000 a 2020). Un monto
-- quieto en pesos pierde contra el dolar pero casi no pierde poder adquisitivo.
select case when convertir(140000,'ARS',date '2026-03-17','USD') < 100
                 and convertir(140000,'ARS',date '2026-03-17','UVA') > 69
            then 'ok  las dos varas dan resultados distintos, como debe ser'
            else 'FALLO  dieron lo mismo' end;

reset role;

-- ---------------------------------------------------------------------------
-- Con que dolar mide cada cosa, elegible y visible.  OD-59, OD-60
-- ---------------------------------------------------------------------------
select case when (select default_fx_source from ledger where id = my_ledger()) = 'mep'
            then 'ok  un libro nace midiendo al mep'
            else 'FALLO  nacio con otro' end;

select cambiar_dolar('blue');
select case when (select dolar from mi_libro where activo) = 'blue'
            then 'ok  el duenio puede cambiar el dolar del libro, y se ve'
            else 'FALLO  no cambio o no se ve' end;

-- La UVA no es un dolar: es la OTRA vara de medicion (ADR-023). Elegirla como
-- fuente haria que el patrimonio "en dolares" se calculara dividiendo por el
-- valor de la UVA, y el numero saldria perfectamente creible.
--
-- Va envuelto en una funcion y no en un `do $$`: este archivo se lee con
-- grep '^(ok|FALLO)' y un `raise notice` sale con el prefijo de psql. La
-- excepcion hay que atraparla en algun lado, y una funcion que DEVUELVE el
-- resultado entra en el molde del resto del archivo.
reset role;
create or replace function _prueba_uva() returns text
language plpgsql as $$
begin
  perform cambiar_dolar('uva');
  return 'FALLO  acepto la uva como dolar del libro';
exception when check_violation then
  return 'ok  rechaza la uva como dolar del libro: es la otra vara';
end $$;
select _prueba_uva();
drop function _prueba_uva();
set role rls_probe;

select cambiar_dolar('mep');   -- se deja como estaba para lo que venga despues

-- Y la aclaracion que ADR-011 se exige: que dolar uso cada cosa.
select case when exists (select 1 from dolar_en_uso where fuente = 'mep')
            then 'ok  se puede decir con que dolar se midio'
            else 'FALLO  dolar_en_uso no lo dice' end;
