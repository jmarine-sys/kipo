-- Medir en dolares o en poder adquisitivo — ADR-009 generalizada.
--
-- Sin esto la pregunta central del proyecto -"¿mis inversiones rinden 10% anual
-- en dolares?"- no tiene respuesta, porque nada se puede expresar en dolares
-- salvo lo que ya esta en dolares.
--
-- LA IDEA: la unidad de medida es apenas un DIVISOR.
--
--   en dolares            -> dividir por la cotizacion de ese dia
--   en poder adquisitivo  -> dividir por la UVA de ese dia
--
-- Es la misma maquinaria, asi que la medida es un parametro y no una constante.
-- Eso permite responder dos preguntas distintas con el mismo codigo:
--
--   "¿le gano al dolar?"      medir en USD
--   "¿le gano a la inflacion?" medir en UVA
--
-- Y no son la misma pregunta: si el dolar sube menos que los precios -atraso
-- cambiario- se puede tener +0% en dolares y estar perdiendo poder adquisitivo.

-- La UVA entra como una cotizacion mas: "cuantos pesos vale una UVA". No hace
-- falta una tabla nueva porque es exactamente la misma forma de dato.
alter table fx_rate drop constraint if exists fx_rate_source_check;
alter table fx_rate add constraint fx_rate_source_check
  check (source in ('oficial','mep','blue','ccl','cripto','mayorista','uva','manual'));

-- Que dolar usa el libro por defecto.
--
-- SECURITY DEFINER por la misma razon que my_ledger(): ADR-020 le niega al
-- cliente todo acceso a la tabla 'ledger', asi que una funcion SECURITY INVOKER
-- que la consulte falla con permiso denegado. Se expone el DATO, no la tabla.
create or replace function my_fx_source() returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select l.default_fx_source
    from ledger l
    join ledger_member m on m.ledger_id = l.id
   where m.user_id = auth.uid()
   limit 1
$$;

revoke all on function my_fx_source() from public;
grant execute on function my_fx_source() to authenticated;

-- ---------------------------------------------------------------------------
-- La cotizacion vigente para una fecha.
--
-- Usa la ULTIMA anterior o igual, no la mas cercana: un sabado no cotiza, y el
-- valor que regia ese dia es el del viernes, no el del lunes siguiente. Tomar el
-- lunes seria usar informacion que en ese momento no existia.
-- ---------------------------------------------------------------------------

create or replace function cotizacion(
  p_fecha  date,
  p_fuente text,
  p_base   text default 'USD',
  p_quote  text default 'ARS'
) returns numeric
language sql
stable
set search_path = public, pg_temp
as $$
  select rate from fx_rate
   where ledger_id = my_ledger()
     and base = p_base and quote = p_quote and source = p_fuente
     and on_date <= p_fecha
   order by on_date desc
   limit 1
$$;

grant execute on function cotizacion(date, text, text, text) to authenticated;

-- De que dia es el dato que se esta usando.
--
-- Hace falta porque "hay una cotizacion" NO es lo mismo que "hay una cotizacion
-- reciente": con la regla de la ultima anterior o igual, un dato de marzo cubre
-- formalmente a septiembre, y valuar septiembre con el dolar de marzo no es
-- medir, es inventar. La pantalla tiene que poder avisarlo.
create or replace function cotizacion_al(
  p_fecha  date,
  p_fuente text,
  p_base   text default 'USD',
  p_quote  text default 'ARS'
) returns date
language sql
stable
set search_path = public, pg_temp
as $$
  select on_date from fx_rate
   where ledger_id = my_ledger()
     and base = p_base and quote = p_quote and source = p_fuente
     and on_date <= p_fecha
   order by on_date desc
   limit 1
$$;

grant execute on function cotizacion_al(date, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Cuanto vale un monto en la medida elegida, a la vara de SU fecha.
--
-- Devuelve NULL si falta el dato. A proposito: es preferible que la pantalla
-- diga "no se" a que muestre un numero calculado con una cotizacion inventada.
-- Brief §20, transparencia.
-- ---------------------------------------------------------------------------

create or replace function convertir(
  p_monto  numeric,
  p_unidad text,
  p_fecha  date,
  p_medida text default 'USD',   -- 'USD' o 'UVA'
  p_fuente text default null     -- que dolar; null = el del libro
) returns numeric
language plpgsql
stable
set search_path = public, pg_temp
as $$
declare
  v_fuente text;
  v_usd    numeric;
  v_ars    numeric;
  v_uva    numeric;
begin
  if p_monto is null then return null; end if;

  -- Una unidad que no es moneda -BTC, un CEDEAR- no se convierte aca: primero
  -- hay que valuarla con su precio.
  if p_unidad not in ('ARS','USD','USDT','USDC','DAI') then
    return null;
  end if;

  v_fuente := coalesce(p_fuente, my_fx_source());

  if p_medida = 'USD' then
    -- USDT, USDC y DAI se toman como dolar. Es una aproximacion deliberada: se
    -- despegan unas centesimas y esa diferencia es ruido frente a lo que se mide.
    if p_unidad <> 'ARS' then return p_monto; end if;
    v_usd := cotizacion(p_fecha, v_fuente);
    if v_usd is null or v_usd = 0 then return null; end if;
    return p_monto / v_usd;

  elsif p_medida = 'UVA' then
    v_uva := cotizacion(p_fecha, 'uva', 'UVA', 'ARS');
    if v_uva is null or v_uva = 0 then return null; end if;

    if p_unidad = 'ARS' then
      v_ars := p_monto;
    else
      -- primero a pesos de ese dia, despues a UVAs
      v_usd := cotizacion(p_fecha, v_fuente);
      if v_usd is null then return null; end if;
      v_ars := p_monto * v_usd;
    end if;
    return v_ars / v_uva;
  end if;

  raise exception 'Medida desconocida: %. Se admiten USD y UVA', p_medida;
end $$;

grant execute on function convertir(numeric, text, date, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Que datos faltan para poder medir.
-- La pantalla necesita poder decir "no puedo calcularlo y esto es lo que falta",
-- no simplemente mostrar un hueco.
-- ---------------------------------------------------------------------------

create view medicion_faltante as
  with fechas as (
    select distinct t.occurred_on as fecha
      from entry e
      join account a on a.id = e.account_id
      join transaction t on t.id = e.transaction_id
     where a.valuation in ('market','accrual')
    union
    select current_date
  ),
  evaluada as (
    select f.fecha,
           cotizacion_al(f.fecha, my_fx_source())       as dolar_al,
           cotizacion_al(f.fecha, 'uva', 'UVA', 'ARS')  as uva_al
      from fechas f
  )
  select fecha,
         dolar_al,
         uva_al,
         (dolar_al is null) as sin_dolar,
         (uva_al   is null) as sin_uva,
         -- Mas de una semana de desfasaje ya no es una cotizacion: es una
         -- suposicion. Con el dolar moviendose como se mueve, usar el dato de
         -- hace un mes distorsiona mas que no mostrar nada.
         (dolar_al is not null and fecha - dolar_al > 7) as dolar_viejo,
         (uva_al   is not null and fecha - uva_al   > 7) as uva_viejo
    from evaluada
   where dolar_al is null
      or uva_al   is null
      or fecha - dolar_al > 7
      or fecha - uva_al   > 7;

alter view medicion_faltante set (security_invoker = on);
grant select on medicion_faltante to authenticated;
