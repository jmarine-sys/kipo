-- GENERADO POR scripts/pendientes.sh — no editar a mano.
--
-- Migraciones desde 20260916140000, en orden. Pegar entero en el SQL Editor de
-- Supabase. Es idempotente: se puede correr dos veces sin romper nada.
--
--   20260916140000_medicion.sql
--   20260916150000_cartera.sql
--   20260916160000_cerradas.sql
--   20260916170000_cedears.sql
--   20260916180000_limpieza.sql

-- ===========================================================================
-- 20260916140000_medicion.sql
-- ===========================================================================

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

-- ===========================================================================
-- 20260916150000_cartera.sql
-- ===========================================================================

-- Los flujos de cada inversion, ya convertidos a la vara de SU fecha.
--
-- Con esto el cliente puede calcular XIRR sin saber nada de cotizaciones: pide
-- los flujos y el valor de hoy, y aplica la formula.

-- ---------------------------------------------------------------------------
-- Cada movimiento de plata que entro o salio de una inversion.
--
-- La pata que importa es la de la CUENTA contraria, no la de la categoria: en el
-- vencimiento de un plazo fijo hay tres lineas -capital que sale, total que
-- vuelve, interes que se imputa- y sumarlas todas daria el capital en vez del
-- total. El flujo real es lo que entro a tu bolsillo.
--
-- El signo ya viene bien de la partida doble: cuando comprás, la cuenta de
-- efectivo va en negativo, que es exactamente lo que XIRR espera de un aporte.
-- ---------------------------------------------------------------------------

create view flujo_inversion as
  select a.id                                   as account_id,
         a.valuation,
         t.occurred_on                          as fecha,
         c.amount                               as monto,
         c.unit                                 as unidad,
         convertir(c.amount, c.unit, t.occurred_on, 'USD') as usd,
         convertir(c.amount, c.unit, t.occurred_on, 'UVA') as uva
    from entry pe
    join account a on a.id = pe.account_id
                  and a.valuation in ('market', 'accrual')
    join transaction t on t.id = pe.transaction_id
    join entry c on c.transaction_id = pe.transaction_id
                and c.account_id is not null
                and c.account_id <> a.id;

alter view flujo_inversion set (security_invoker = on);
grant select on flujo_inversion to authenticated;

-- ---------------------------------------------------------------------------
-- Cuanto vale hoy cada inversion, en cada vara.
--
-- Entra al calculo como un flujo POSITIVO con fecha de hoy: es lo que recibirias
-- si vendieras todo ahora.
-- ---------------------------------------------------------------------------

create view valor_inversion as
  select a.id            as account_id,
         a.name,
         a.valuation,
         a.institution,
         a.matures_on,
         i.symbol,
         i.kind,
         i.quote_currency,
         coalesce(sal.saldo, 0) as saldo,
         case
           -- una posicion vale unidades por precio, y sin precio no vale "cero":
           -- vale desconocido
           when a.valuation = 'market' then coalesce(sal.saldo, 0) * pr.price
           -- un plazo fijo vale su capital hasta que vence (ADR-014)
           else coalesce(sal.saldo, 0)
         end as valor_nativo,
         case when a.valuation = 'market' then i.quote_currency else a.unit end as moneda,
         pr.on_date as precio_al,
         convertir(
           case when a.valuation = 'market' then coalesce(sal.saldo, 0) * pr.price
                else coalesce(sal.saldo, 0) end,
           case when a.valuation = 'market' then i.quote_currency else a.unit end,
           current_date, 'USD') as usd,
         convertir(
           case when a.valuation = 'market' then coalesce(sal.saldo, 0) * pr.price
                else coalesce(sal.saldo, 0) end,
           case when a.valuation = 'market' then i.quote_currency else a.unit end,
           current_date, 'UVA') as uva
    from account a
    left join instrument i on i.id = a.instrument_id
    left join lateral (
      select sum(e.amount) as saldo from entry e where e.account_id = a.id
    ) sal on true
    left join lateral (
      select p.price, p.on_date from price p
       where p.instrument_id = a.instrument_id
       order by p.on_date desc limit 1
    ) pr on true
   where a.valuation in ('market', 'accrual')
     and a.archived_at is null;

alter view valor_inversion set (security_invoker = on);
grant select on valor_inversion to authenticated;

comment on view valor_inversion is
  'Valor actual de cada inversion en su moneda nativa y en las dos varas de '
  'medicion. NULL cuando falta el precio o la cotizacion: la pantalla dice que '
  'no sabe, no muestra cero.';

-- ===========================================================================
-- 20260916160000_cerradas.sql
-- ===========================================================================

-- Las inversiones cerradas siguen contando.
--
-- Una posicion vendida entera se archiva, y la vista de valuacion la excluia. El
-- efecto era que DESAPARECIA del calculo con todos sus flujos: si comprabas,
-- duplicabas y vendias, tu mejor operacion se borraba de tu rendimiento. Y una
-- venta con perdida tambien.
--
-- Lo correcto es que valga CERO, no que no exista: los flujos -lo que pusiste y
-- lo que sacaste- son parte de tu historial de inversion y XIRR los necesita.
--
-- Eso mide "como me fue invirtiendo", que es la pregunta. La plata que despues
-- quedo quieta en una cuenta no forma parte de la cartera, y con razon: no esta
-- invertida.

drop view if exists valor_inversion;

create view valor_inversion as
  select a.id            as account_id,
         a.name,
         a.valuation,
         a.institution,
         a.matures_on,
         (a.archived_at is not null) as cerrada,
         i.symbol,
         i.kind,
         i.quote_currency,
         coalesce(sal.saldo, 0) as saldo,
         v.valor_nativo,
         case when a.valuation = 'market' then i.quote_currency else a.unit end as moneda,
         pr.on_date as precio_al,
         convertir(v.valor_nativo,
                   case when a.valuation = 'market' then i.quote_currency else a.unit end,
                   current_date, 'USD') as usd,
         convertir(v.valor_nativo,
                   case when a.valuation = 'market' then i.quote_currency else a.unit end,
                   current_date, 'UVA') as uva
    from account a
    left join instrument i on i.id = a.instrument_id
    left join lateral (
      select sum(e.amount) as saldo from entry e where e.account_id = a.id
    ) sal on true
    left join lateral (
      select p.price, p.on_date from price p
       where p.instrument_id = a.instrument_id
       order by p.on_date desc limit 1
    ) pr on true
    left join lateral (
      select case
               -- Sin unidades no hace falta precio para saber que vale cero.
               -- Antes esto daba NULL -0 por un precio ausente- y dejaba la
               -- posicion cerrada afuera del calculo.
               when coalesce(sal.saldo, 0) = 0 then 0
               when a.valuation = 'market'     then sal.saldo * pr.price
               else sal.saldo
             end as valor_nativo
    ) v on true
   where a.valuation in ('market', 'accrual');

alter view valor_inversion set (security_invoker = on);
grant select on valor_inversion to authenticated;

comment on view valor_inversion is
  'Valor actual de cada inversion, viva o cerrada, en su moneda nativa y en las '
  'dos varas. Las cerradas valen cero pero siguen en la lista: sus flujos son '
  'parte del historial y el rendimiento los necesita.';

-- ===========================================================================
-- 20260916170000_cedears.sql
-- ===========================================================================

-- CEDEARs: separar el rendimiento del activo del movimiento del dolar.  OD-17.
--
-- EL PROBLEMA. Un CEDEAR cotiza en pesos y su precio ya lleva el CCL adentro:
--
--     precio_cedear_ARS = (precio_accion_USD / ratio) x CCL
--
-- Asi que sube por dos motivos que el precio mezcla: porque subio la accion en
-- dolares, o porque subio el CCL. Valuarlo en pesos y convertir al MEP -o a
-- cualquier otro dolar- arrastra esa mezcla.
--
-- LA SOLUCION. Convertir al CCL. El CCL se cancela y queda:
--
--     valor_USD = precio_cedear_ARS x unidades / CCL
--               = (precio_accion_USD / ratio) x unidades
--
-- o sea el valor en dolares de la accion subyacente. Sin necesitar el ratio ni
-- traer el precio del exterior: alcanza con usar la vara correcta.
--
-- Convertir al MEP responde otra pregunta, tambien legitima: "cuantos dolares
-- saco si vendo y extraigo por MEP". Por eso la fuente es una propiedad de la
-- CUENTA (ADR-011) y no una constante del sistema.
--
-- Lo que faltaba era que las vistas de medicion la respetaran: la declaraban y
-- no la usaban.

-- ---------------------------------------------------------------------------
-- Los flujos, con la vara de su cuenta
-- ---------------------------------------------------------------------------

drop view if exists flujo_inversion;

create view flujo_inversion as
  select a.id                                   as account_id,
         a.valuation,
         t.occurred_on                          as fecha,
         c.amount                               as monto,
         c.unit                                 as unidad,
         -- a.fx_source, no el del libro: un CEDEAR se mide al CCL aunque el
         -- resto de la aplicacion use MEP
         convertir(c.amount, c.unit, t.occurred_on, 'USD', a.fx_source) as usd,
         convertir(c.amount, c.unit, t.occurred_on, 'UVA', a.fx_source) as uva
    from entry pe
    join account a on a.id = pe.account_id
                  and a.valuation in ('market', 'accrual')
    join transaction t on t.id = pe.transaction_id
    join entry c on c.transaction_id = pe.transaction_id
                and c.account_id is not null
                and c.account_id <> a.id;

alter view flujo_inversion set (security_invoker = on);
grant select on flujo_inversion to authenticated;

-- ---------------------------------------------------------------------------
-- La valuacion, con la misma vara.
-- Tiene que ser LA MISMA que la de los flujos: medir lo que pusiste con un dolar
-- y lo que vale con otro daria un rendimiento inventado.
-- ---------------------------------------------------------------------------

drop view if exists valor_inversion;

create view valor_inversion as
  select a.id            as account_id,
         a.name,
         a.valuation,
         a.institution,
         a.matures_on,
         (a.archived_at is not null) as cerrada,
         a.fx_source,
         i.symbol,
         i.kind,
         i.quote_currency,
         i.ratio,
         i.underlying_symbol,
         coalesce(sal.saldo, 0) as saldo,
         v.valor_nativo,
         case when a.valuation = 'market' then i.quote_currency else a.unit end as moneda,
         pr.on_date as precio_al,
         convertir(v.valor_nativo,
                   case when a.valuation = 'market' then i.quote_currency else a.unit end,
                   current_date, 'USD', a.fx_source) as usd,
         convertir(v.valor_nativo,
                   case when a.valuation = 'market' then i.quote_currency else a.unit end,
                   current_date, 'UVA', a.fx_source) as uva
    from account a
    left join instrument i on i.id = a.instrument_id
    left join lateral (
      select sum(e.amount) as saldo from entry e where e.account_id = a.id
    ) sal on true
    left join lateral (
      select p.price, p.on_date from price p
       where p.instrument_id = a.instrument_id
       order by p.on_date desc limit 1
    ) pr on true
    left join lateral (
      select case
               when coalesce(sal.saldo, 0) = 0 then 0
               when a.valuation = 'market'     then sal.saldo * pr.price
               else sal.saldo
             end as valor_nativo
    ) v on true
   where a.valuation in ('market', 'accrual');

alter view valor_inversion set (security_invoker = on);
grant select on valor_inversion to authenticated;

-- ---------------------------------------------------------------------------
-- Al comprar un CEDEAR, la cuenta nace midiendose al CCL.
-- Es lo correcto por defecto y se puede cambiar despues: es una propiedad de la
-- cuenta, no una regla del sistema.
-- ---------------------------------------------------------------------------

-- OJO: agregar un parametro -aunque tenga valor por defecto- NO reemplaza la
-- funcion, crea una SOBRECARGA. Las dos quedan vivas y toda llamada con la
-- cantidad vieja de argumentos se vuelve ambigua. Hay que borrar la anterior.
drop function if exists comprar_activo(text, text, text, text, int, uuid, numeric, numeric, text, date);

create or replace function comprar_activo(
  p_symbol   text,
  p_nombre   text,
  p_kind     text,
  p_moneda   text,
  p_decimals int,
  p_desde    uuid,
  p_monto    numeric,
  p_unidades numeric,
  p_broker   text default null,
  p_on       date default null,
  p_ratio    numeric default null,   -- cuantos CEDEARs equivalen a una accion
  p_subyacente text default null     -- el simbolo de esa accion
) returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_ledger uuid := my_ledger();
  v_origen account%rowtype;
  v_inst   uuid;
  v_pos    uuid;
  v_tx     uuid;
  v_fecha  date := coalesce(p_on, current_date);
  v_fuente text;
begin
  if p_monto is null or p_monto <= 0 then raise exception 'El monto tiene que ser mayor que cero'; end if;
  if p_unidades is null or p_unidades <= 0 then raise exception 'Las unidades tienen que ser mayores que cero'; end if;

  select * into v_origen from account where id = p_desde;
  if not found then raise exception 'No existe la cuenta de origen'; end if;

  select id into v_inst from instrument
   where ledger_id = v_ledger and symbol = upper(trim(p_symbol));
  if v_inst is null then
    insert into instrument (ledger_id, symbol, name, kind, quote_currency, decimals,
                            ratio, underlying_symbol)
         values (v_ledger, upper(trim(p_symbol)), p_nombre, p_kind, p_moneda, p_decimals,
                 p_ratio, nullif(upper(trim(coalesce(p_subyacente,''))), ''))
      returning id into v_inst;
  end if;

  -- Un CEDEAR lleva el CCL adentro de su precio: medirlo con ese mismo dolar es
  -- lo que aisla el rendimiento de la accion del movimiento del tipo de cambio.
  v_fuente := case when p_kind = 'cedear' then 'ccl' else null end;

  select id into v_pos from account
   where ledger_id = v_ledger and instrument_id = v_inst and archived_at is null;
  if v_pos is null then
    insert into account (ledger_id, name, kind, valuation, unit, instrument_id,
                         is_spendable, institution, fx_source)
         values (v_ledger,
                 coalesce(p_broker || ' · ', '') || upper(trim(p_symbol)),
                 'asset', 'market', upper(trim(p_symbol)), v_inst,
                 false, coalesce(p_broker, v_origen.institution), v_fuente)
      returning id into v_pos;
  end if;

  insert into transaction (ledger_id, occurred_on, description, kind, created_by)
       values (v_ledger, v_fecha, 'Compra de ' || upper(trim(p_symbol)), 'trade', auth.uid())
    returning id into v_tx;

  insert into entry (transaction_id, ledger_id, account_id, amount, unit) values
    (v_tx, v_ledger, p_desde, -p_monto,    v_origen.unit),
    (v_tx, v_ledger, v_pos,    p_unidades, upper(trim(p_symbol)));

  return v_pos;
end $$;

grant execute on function comprar_activo(text, text, text, text, int, uuid, numeric, numeric, text, date, numeric, text) to authenticated;


-- La lista de posiciones tambien dice con que dolar se mide cada una: sin eso la
-- pantalla no puede cumplir ADR-011, que exige decir con que vara se midio.
drop view if exists posicion;

create view posicion as
  select a.id           as account_id,
         a.ledger_id,
         a.name,
         a.institution,
         a.fx_source,
         i.id           as instrument_id,
         i.symbol,
         i.name         as instrument_name,
         i.kind,
         i.quote_currency,
         i.decimals,
         i.ratio,
         i.underlying_symbol,
         coalesce(u.unidades, 0)                as unidades,
         p.price                                as precio,
         p.on_date                              as precio_al,
         p.source                               as precio_fuente,
         coalesce(u.unidades, 0) * p.price      as valor,
         coalesce(f.invertido, 0)               as invertido,
         coalesce(u.unidades, 0) * p.price - coalesce(f.invertido, 0) as ganancia
    from account a
    join instrument i on i.id = a.instrument_id
    left join lateral (
      select sum(e.amount) as unidades from entry e where e.account_id = a.id
    ) u on true
    left join lateral (
      select -sum(c.amount) as invertido
        from entry pe
        join entry c on c.transaction_id = pe.transaction_id
                    and c.account_id is not null
                    and c.account_id <> a.id
       where pe.account_id = a.id
    ) f on true
    left join lateral (
      select pr.price, pr.on_date, pr.source
        from price pr where pr.instrument_id = i.id
       order by pr.on_date desc limit 1
    ) p on true
   where a.valuation = 'market'
     and a.archived_at is null;

alter view posicion set (security_invoker = on);
grant select on posicion to authenticated;

-- ===========================================================================
-- 20260916180000_limpieza.sql
-- ===========================================================================

-- Saca de la base lo que ADR-023 dejo sin uso.
--
-- `20260916140000_cotizaciones.sql` fue la primera version de la medicion: creaba
-- `en_usd()` y `cotizacion_faltante`. El mismo dia, ADR-023 generalizo la idea -la
-- unidad de medida es apenas un divisor- y esos dos objetos quedaron reemplazados
-- por `convertir()` y `medicion_faltante`. Nadie en el repositorio los nombra.
--
-- Ademas ese archivo compartia timestamp con `..._medicion.sql`, y dos migraciones
-- con la misma version es una bomba de tiempo: el orden pasa a depender del orden
-- alfabetico del nombre, que hoy da bien de pura casualidad. Se borro el archivo.
--
-- Estos DROP son por si en alguna base llego a aplicarse antes de borrarse. Si
-- nunca existieron, no hacen nada: para eso esta el `if exists`.

drop view if exists cotizacion_faltante;
drop function if exists en_usd(numeric, text, date, text);

