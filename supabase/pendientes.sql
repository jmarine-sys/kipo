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
--   20260916190000_llave_de_precio.sql
--   20260916200000_portafolios.sql
--   20260918100000_alta_minima.sql
--   20260918110000_uso_arbol.sql
--   20260918120000_institucion.sql
--   20260918130000_fin_de_mes.sql
--   20260918140000_cuotas.sql
--   20260918150000_libros_compartidos.sql

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

-- ===========================================================================
-- 20260916190000_llave_de_precio.sql
-- ===========================================================================

-- `underlying_symbol` dejo de ser un dato informativo.
--
-- Nacio como "previsto, sin usar" (OD-17). ADR-024 lo dejo fuera de la cuenta
-- del rendimiento -medir al CCL no lo necesita- y eso sigue siendo cierto. Pero
-- ADR-025 le dio un segundo papel: es el simbolo con el que se le pide el precio
-- a la fuente. Un CEDEAR se llama "AAPL-CEDEAR" en tu libro y "AAPL" en BYMA.
--
-- La consecuencia incomoda: un CEDEAR sin este campo NO recibe precio automatico
-- y nada se rompe -simplemente se queda quieto, que es la peor forma de fallar-.
-- Por eso queda dicho en la base y no solo en un formulario.

comment on column instrument.underlying_symbol is
  'El simbolo del activo en la fuente de precios. Para un CEDEAR es la accion '
  'que representa (AAPL), que es como lo publica BYMA. Sin esto no hay precio '
  'automatico: ADR-025.';

comment on column instrument.ratio is
  'Cuantos CEDEARs equivalen a una accion. Informativo: ADR-024 mide al CCL, y '
  'esa division no necesita el ratio.';

-- ===========================================================================
-- 20260916200000_portafolios.sql
-- ===========================================================================

-- El portafolio es el BORDE — ADR-026.
--
-- Hasta acá el rendimiento se medía por posición: `flujo_inversion` solo miraba
-- cuentas `market` y `accrual`. Eso tiene tres agujeros, y los tres son el mismo:
--
--   1. El efectivo quieto en el broker no existía. Vendías ETH, dejabas los
--      dólares ahí, y el portafolio marcaba cero.
--   2. La plata depositada que espera no penalizaba. El aporte se fechaba en la
--      COMPRA, no en el depósito, así que los meses ociosos no aparecían y el
--      rendimiento salía mejor de lo que fue.
--   3. Comprar adentro contaba como aporte nuevo, cuando es la misma plata
--      cambiando de forma.
--
-- Con el portafolio como borde, una sola condición los cierra a los tres: es
-- flujo solo lo que tiene la contraparte AFUERA.

create table portfolio (
  id          uuid primary key default gen_random_uuid(),
  ledger_id   uuid not null default my_ledger() references ledger(id) on delete cascade,
  name        text not null,
  -- Con qué dólar se mide TODO lo de adentro, salvo que una cuenta diga otra
  -- cosa. Balanz al CCL, Binance al cripto. Null = el del libro.
  fx_source   text,
  archived_at timestamptz,
  created_at  timestamptz not null default now(),
  unique (ledger_id, name),
  unique (id, ledger_id)           -- habilita la clave foranea compuesta de abajo
);

-- Pertenecer a un portafolio es OPCIONAL y esa es la diferencia con agrupar por
-- institución: tu cuenta remunerada de Mercado Pago no tiene por qué entrar,
-- aunque Mercado Pago también sea una institución. ADR-013 ya había decidido que
-- una cuenta remunerada es un banco, no una inversión.
alter table account add column portfolio_id uuid;

-- Compuesta contra (id, ledger_id): garantiza en el esquema que una cuenta no
-- pueda apuntar a un portafolio de OTRO libro. Sin triggers.
alter table account add constraint account_portfolio_fk
  foreign key (portfolio_id, ledger_id) references portfolio(id, ledger_id)
  on delete set null;

create index account_portfolio_idx on account (portfolio_id) where portfolio_id is not null;

alter table portfolio enable row level security;
alter table portfolio force row level security;
create policy portfolio_member_rw on portfolio for all to authenticated
  using      (ledger_id in (select my_ledgers()))
  with check (ledger_id in (select my_ledgers()));

grant select, insert, update, delete on portfolio to authenticated;

-- ---------------------------------------------------------------------------
-- Cuánto vale UNA cuenta, la que sea.
--
-- `valor_inversion` sabía valuar posiciones y plazos fijos, pero no el efectivo.
-- Ahora hay UNA sola definición de "cuánto vale una cuenta" y valor_inversion
-- pasa a ser un recorte de ella. La lección ya apareció tres veces en este
-- proyecto: cuando algo se define en seis lugares, los seis dejan de coincidir.
-- ---------------------------------------------------------------------------

drop view if exists valor_inversion;

create view valor_cuenta as
  select a.id            as account_id,
         a.ledger_id,
         a.portfolio_id,
         a.name,
         a.kind          as account_kind,
         a.valuation,
         a.unit,
         a.institution,
         a.matures_on,
         (a.archived_at is not null) as cerrada,
         -- La cuenta manda sobre el portafolio, y el portafolio sobre el libro.
         coalesce(a.fx_source, pf.fx_source) as fx_source,
         i.symbol,
         i.kind          as kind,
         i.quote_currency,
         i.ratio,
         i.underlying_symbol,
         coalesce(sal.saldo, 0) as saldo,
         v.valor_nativo,
         case when a.valuation = 'market' then i.quote_currency else a.unit end as moneda,
         pr.on_date as precio_al,
         convertir(v.valor_nativo,
                   case when a.valuation = 'market' then i.quote_currency else a.unit end,
                   current_date, 'USD', coalesce(a.fx_source, pf.fx_source)) as usd,
         convertir(v.valor_nativo,
                   case when a.valuation = 'market' then i.quote_currency else a.unit end,
                   current_date, 'UVA', coalesce(a.fx_source, pf.fx_source)) as uva
    from account a
    left join portfolio pf on pf.id = a.portfolio_id
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
               -- Saldo cero vale cero sin necesitar precio: una posición cerrada
               -- no deja de existir por no tener cotización.
               when coalesce(sal.saldo, 0) = 0 then 0
               when a.valuation = 'market'     then sal.saldo * pr.price
               else sal.saldo
             end as valor_nativo
    ) v on true;

alter view valor_cuenta set (security_invoker = on);
grant select on valor_cuenta to authenticated;

create view valor_inversion as
  select * from valor_cuenta where valuation in ('market', 'accrual');

alter view valor_inversion set (security_invoker = on);
grant select on valor_inversion to authenticated;

-- ---------------------------------------------------------------------------
-- Cuánto vale un portafolio entero: posiciones MÁS efectivo quieto.
--
-- `sin_valuar` no es decorativo: sum() ignora los nulos, así que una posición
-- sin precio desaparecería del total sin dejar rastro y el número se vería
-- completo. La pantalla tiene que poder decir "no incluye 2 posiciones".
-- ---------------------------------------------------------------------------

create view valor_portafolio as
  select p.id          as portfolio_id,
         p.ledger_id,
         p.name,
         p.fx_source,
         (p.archived_at is not null) as cerrado,
         count(v.account_id)                                  as cuentas,
         count(*) filter (where v.usd is null
                            and v.account_id is not null)     as sin_valuar,
         sum(v.usd)                                           as usd,
         sum(v.uva)                                           as uva
    from portfolio p
    left join valor_cuenta v on v.portfolio_id = p.id
   group by p.id, p.ledger_id, p.name, p.fx_source, p.archived_at;

alter view valor_portafolio set (security_invoker = on);
grant select on valor_portafolio to authenticated;

-- ---------------------------------------------------------------------------
-- Qué cruzó el borde. LA vista de este ADR.
--
-- Se mide sobre la pata de AFUERA -igual que flujo_inversion- y no sobre la de
-- adentro: cuando comprás un CEDEAR con pesos, lo que cruzó son los pesos, y los
-- pesos se convierten a dólares con la cotización del día. Convertir la pata de
-- adentro exigiría el precio del activo en esa fecha, que puede no existir.
--
-- Una contraparte con account_id NULL es una categoría, o sea un ingreso o un
-- gasto: el interés que paga el broker NO es plata que aportaste, es rendimiento
-- generado adentro. Por eso el join exige account_id not null.
-- ---------------------------------------------------------------------------

create view flujo_portafolio as
  with participa as (
    select distinct a.portfolio_id, e.transaction_id
      from entry e
      join account a on a.id = e.account_id
     where a.portfolio_id is not null
  )
  select pa.portfolio_id,
         t.occurred_on           as fecha,
         c.unit                  as unidad,
         sum(c.amount)           as monto,
         convertir(sum(c.amount), c.unit, t.occurred_on, 'USD', pf.fx_source) as usd,
         convertir(sum(c.amount), c.unit, t.occurred_on, 'UVA', pf.fx_source) as uva
    from participa pa
    join portfolio pf on pf.id = pa.portfolio_id
    join transaction t on t.id = pa.transaction_id
    join entry c on c.transaction_id = t.id
                and c.account_id is not null
    join account ca on ca.id = c.account_id
   where ca.portfolio_id is distinct from pa.portfolio_id
   group by pa.portfolio_id, t.id, t.occurred_on, c.unit, pf.fx_source;

alter view flujo_portafolio set (security_invoker = on);
grant select on flujo_portafolio to authenticated;

comment on view flujo_portafolio is
  'Solo lo que cruza el borde del portafolio. Comprar adentro no es flujo: es la '
  'misma plata cambiando de forma. ADR-026.';

-- ===========================================================================
-- 20260918100000_alta_minima.sql
-- ===========================================================================

-- El alta deja de decidir por el usuario — ADR-027.
--
-- Sembraba 20 categorias y una cuenta "Efectivo ARS". La cuenta estaba ahi por
-- una razon escrita y buena: el MVP se mide en que registrar un gasto lleve
-- menos de diez segundos, y sin cuenta no se puede registrar nada.
--
-- Lo que se aprendio probandola con alguien que no la construyo: esas 20
-- categorias no son un atajo, son una taxonomia ajena. Para cargar un cafe habia
-- que leer doce opciones que nadie eligio.
--
-- LA DISTINCION: los padres son ESTRUCTURA, los hijos son OPINION.
--
--   'Gastos fijos' y 'Gastos variables' no son una preferencia: son la
--   correccion del error 2 del analisis -la planilla mezclaba el TIPO de
--   operacion con el CONCEPTO- y sin ellos el modelo no se entiende.
--
--   'Restaurantes' o 'Donaciones' son gustos de quien escribio esto metidos en
--   el libro de otra persona.
--
-- 'Intereses' y 'Ajustes' se quedan y no son negociables: ADR-013, ADR-014 y
-- ADR-005 dependen de que existan. Sin ellas el interes de una cuenta remunerada
-- y el ajuste de saldo no tienen adonde ir.
--
-- Y la cuenta se va: no se puede registrar un gasto sin decir de donde salio,
-- asi que preguntarlo UNA vez es mas honesto que inventar una respuesta. La
-- puesta en marcha se encarga, y es la primera pantalla.

create or replace function handle_new_user() returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_ledger uuid;
begin
  insert into ledger (name) values ('Personal') returning id into v_ledger;
  insert into ledger_member (ledger_id, user_id, role) values (v_ledger, new.id, 'owner');

  insert into category (ledger_id, name, kind, is_system, sort_order) values
    (v_ledger, 'Sueldo',         'income',  false, 10),
    (v_ledger, 'Intereses',      'income',  true,  20),   -- ADR-013, ADR-014
    (v_ledger, 'Otros ingresos', 'income',  false, 30),
    (v_ledger, 'Gastos fijos',   'expense', false, 10),
    (v_ledger, 'Gastos variables','expense', false, 20),
    (v_ledger, 'Ajustes',        'expense', true,  90);   -- ADR-005

  -- NO se siembran "Ahorros" ni "Inversiones": son CUENTAS (ADR-012). Sembrarlas
  -- reintroduciria el error 1, que restaba el ahorro del resultado del mes.
  --
  -- NO se siembra ninguna cuenta: lo hace la puesta en marcha.

  return new;
end $$;

-- ===========================================================================
-- 20260918110000_uso_arbol.sql
-- ===========================================================================

-- Una categoria madre tambien "usa" los movimientos de sus hijas.
--
-- `category_usage.movimientos` contaba solo las lineas imputadas a ESA categoria.
-- Como a una madre casi nunca se le imputa nada directo, "Gastos fijos" marcaba
-- CERO aunque abajo tuviera cientos de movimientos. La pantalla entonces ofrecia
-- "Borrar", y la base lo rechazaba por la clave foranea de las hijas: el boton
-- fallaba exitosamente.
--
-- Hay DOS motivos distintos por los que una madre no se puede borrar, y la
-- pantalla necesita poder distinguirlos para decir cual:
--   - tiene movimientos abajo  -> se archiva, no se borra
--   - tiene hijas              -> primero hay que vaciarla
--
-- El arbol es de dos niveles como maximo (lo impone el invariante que rechaza el
-- tercer nivel), asi que alcanza con mirar una generacion: no hace falta un CTE
-- recursivo ni el costo de mantenerlo.

drop view if exists category_usage;

create view category_usage as
  select c.id  as category_id,
         c.ledger_id,
         c.name,
         c.kind,
         c.parent_id,
         c.is_system,
         c.sort_order,
         coalesce(propio.n, 0)                        as movimientos,
         coalesce(propio.n, 0) + coalesce(abajo.n, 0) as movimientos_arbol,
         coalesce(abajo.hijas, 0)                     as hijas
    from category c
    left join lateral (
      select count(*) as n from entry e where e.category_id = c.id
    ) propio on true
    left join lateral (
      select count(*) filter (where e.id is not null) as n,
             count(distinct h.id)                     as hijas
        from category h
        left join entry e on e.category_id = h.id
       where h.parent_id = c.id and h.archived_at is null
    ) abajo on true
   where c.archived_at is null;

alter view category_usage set (security_invoker = on);
grant select on category_usage to authenticated;

comment on view category_usage is
  'movimientos = lo imputado a ella. movimientos_arbol = con sus hijas incluidas, '
  'que es lo que decide si se puede borrar. hijas = por que a veces no se puede '
  'aunque no haya un solo movimiento.';

-- ===========================================================================
-- 20260918120000_institucion.sql
-- ===========================================================================

-- "Ajustes" se llamaba igual que el menu de configuracion de cualquier app — OD-35.
--
-- La primera persona ajena al proyecto que uso kipo vio, en la pantalla principal,
-- una palabra que conocia con OTRO significado. El codigo busca esta categoria por
-- lo que ES (is_system + kind) y nunca por su nombre, asi que renombrarla es
-- seguro: eso ya estaba previsto desde que se permitio renombrarlas.
--
-- Solo aplica a las altas nuevas. Los libros que ya existen conservan el nombre
-- que tengan, y se puede cambiar desde la pantalla de categorias.
--
-- NOTA para el proximo que agregue una columna a una vista: `account_balance` YA
-- expone `institution` desde 20260916100000_uso.sql. La primera version de esta
-- migracion la "agregaba" recreando la vista desde su definicion ORIGINAL, y en
-- el camino borraba `movimientos`, que esa misma migracion habia agregado. Las
-- migraciones son acumulativas: la definicion vigente es la ULTIMA, no la primera.
-- Lo atrapo el test 07, que consulta esa columna.

create or replace function handle_new_user() returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_ledger uuid;
begin
  insert into ledger (name) values ('Personal') returning id into v_ledger;
  insert into ledger_member (ledger_id, user_id, role) values (v_ledger, new.id, 'owner');

  insert into category (ledger_id, name, kind, is_system, sort_order) values
    (v_ledger, 'Sueldo',           'income',  false, 10),
    (v_ledger, 'Intereses',        'income',  true,  20),   -- ADR-013, ADR-014
    (v_ledger, 'Otros ingresos',   'income',  false, 30),
    (v_ledger, 'Gastos fijos',     'expense', false, 10),
    (v_ledger, 'Gastos variables', 'expense', false, 20),
    (v_ledger, 'Ajuste de saldo',  'expense', true,  90);   -- ADR-005

  return new;
end $$;

-- ===========================================================================
-- 20260918130000_fin_de_mes.sql
-- ===========================================================================

-- "Fin de mes" es una REGLA, no una fecha — OD-38.
--
-- Verificado contra PostgreSQL 16 el 2026-09-18:
--
--   31-ene + 1 mes = 2026-02-28
--   28-feb + 1 mes = 2026-03-28
--   28-mar + 1 mes = 2026-04-28
--
-- Un vencimiento a fin de mes se degrada al 28 en febrero y NO VUELVE NUNCA. Un
-- atajo de interfaz que solo escribiera la fecha seria mentira desde el segundo
-- mes, y de la peor manera: sin fallar.
--
-- POR QUE UNA BANDERA Y NO ADIVINARLO: si la fecha es 28-feb no hay forma de
-- saber si alguien quiso "el 28" o "el ultimo dia" — febrero es justo donde las
-- dos lecturas coinciden. Solo lo sabe quien lo cargo.
--
-- POR QUE UN TRIGGER Y NO TOCAR LAS FUNCIONES: `next_on` lo adelantan hoy dos
-- funciones distintas (registrar una ocurrencia y saltear un periodo) y maniana
-- podria hacerlo una tercera. Con el trigger la regla vale para todas, incluido
-- un UPDATE a mano desde el panel. Reescribir las dos funciones habria dejado el
-- invariante dependiendo de que nadie se olvide.

alter table scheduled_event
  add column month_end boolean not null default false;

comment on column scheduled_event.month_end is
  'true = vence el ULTIMO dia del mes, sea 28, 30 o 31. Sin esto la fecha se '
  'degrada al 28 tras el primer febrero y no vuelve. OD-38.';

create or replace function ajustar_fin_de_mes() returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.month_end then
    new.next_on := (date_trunc('month', new.next_on) + interval '1 month - 1 day')::date;
  end if;
  return new;
end $$;

create trigger scheduled_event_fin_de_mes
  before insert or update of next_on, month_end on scheduled_event
  for each row execute function ajustar_fin_de_mes();

comment on function ajustar_fin_de_mes() is
  'Lleva next_on al ultimo dia de su mes cuando la regla es de fin de mes. '
  'Corre en INSERT y en cada UPDATE de next_on, asi ninguna funcion que adelante '
  'la agenda necesita acordarse. OD-38.';

-- ===========================================================================
-- 20260918140000_cuotas.sql
-- ===========================================================================

-- Cuantas cuotas y cuando caen — OD-23.
--
-- LO QUE NO SE HACE, Y POR QUE. El registro decia que una cuota futura "entra
-- gratis en scheduled_event". No entra: un `scheduled_event` es algo que va a
-- pasar y que vas a REGISTRAR, y registrarlo crea un movimiento. Una cuota no es
-- eso. La compra en cuotas YA se registro entera el dia 1 contra la tarjeta
-- (ADR-004): la deuda esta completa desde el primer momento. Agendar las cuotas
-- como eventos contaria el gasto una vez por cuota.
--
-- Lo que falta no es agendar: es PROYECTAR. El saldo de la tarjeta dice cuanto
-- debes; lo que no dice es CUANDO, y con dos o tres compras en cuotas se vuelve
-- imposible anticipar el resumen del mes que viene.
--
-- Por eso alcanza con UN dato -en cuantas cuotas fue- y todo lo demas se deriva.
-- El mes de la primera cuota no se pregunta: una compra con tarjeta cae en el
-- resumen del mes siguiente. Preguntarlo seria friccion para precisar un dia que
-- el modelo igual no usa, porque la proyeccion es por MES.

alter table transaction
  add column installments int
  check (installments is null or installments between 2 and 60);

comment on column transaction.installments is
  'En cuantas cuotas se pago. null = de una. No cambia la contabilidad -la deuda '
  'ya esta entera desde el dia 1- solo permite proyectar cuando cae. OD-23.';

-- ---------------------------------------------------------------------------
-- Una fila por cuota: que tarjeta, que mes, cuanto.
--
-- Se expande con generate_series en vez de guardar N filas: son datos derivados
-- de dos columnas y guardarlos abriria la puerta a que discrepen del movimiento
-- que los origino.
-- ---------------------------------------------------------------------------

create view cuota as
  select t.id                     as transaction_id,
         t.ledger_id,
         t.description,
         t.occurred_on            as comprado_el,
         a.id                     as account_id,
         a.name                   as tarjeta,
         n                        as numero,
         t.installments           as total,
         -- La primera cuota cae en el resumen del mes SIGUIENTE a la compra.
         (date_trunc('month', t.occurred_on) + (n || ' month')::interval)::date as mes,
         round(abs(e.amount) / t.installments, 2) as monto,
         e.unit
    from transaction t
    join entry e on e.transaction_id = t.id
                and e.account_id is not null
    join account a on a.id = e.account_id
                  and a.kind = 'liability'
    cross join generate_series(1, t.installments) as n
   where t.installments is not null;

alter view cuota set (security_invoker = on);
grant select on cuota to authenticated;

-- ---------------------------------------------------------------------------
-- Lo que de verdad se queria: cuanto va a venir en cada resumen.
-- ---------------------------------------------------------------------------

create view resumen_tarjeta as
  select account_id,
         tarjeta,
         ledger_id,
         mes,
         unit,
         sum(monto)  as total,
         count(*)    as cuotas
    from cuota
   where mes >= date_trunc('month', current_date)
   group by account_id, tarjeta, ledger_id, mes, unit;

alter view resumen_tarjeta set (security_invoker = on);
grant select on resumen_tarjeta to authenticated;

comment on view resumen_tarjeta is
  'Lo que cae en cada resumen futuro por compras en cuotas. NO incluye los '
  'consumos de una sola cuota: esos ya estan en el saldo y se pagan enseguida.';



-- ---------------------------------------------------------------------------
-- El cliente necesita poder decirlo al registrar.
--
-- Es la MISMA funcion de 20260915110000_rpc.sql con un parametro mas: se copio
-- entera a proposito, porque reescribirla de memoria habria perdido la
-- validacion de las dos lineas y el comentario sobre la atomicidad diferida.
--
-- Y el `drop` explicito porque agregar un parametro con valor por defecto NO
-- reemplaza la funcion: crea una sobrecarga y las llamadas de cuatro argumentos
-- quedan ambiguas. Ya paso con comprar_activo.
-- ---------------------------------------------------------------------------

drop function if exists create_transaction(date, text, jsonb, text);

create or replace function create_transaction(
  p_occurred_on  date,
  p_kind         text,
  p_entries      jsonb,      -- [{account_id|category_id, amount, unit}, ...]
  p_description  text default null,
  p_installments int default null
) returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_ledger uuid := my_ledger();
  v_tx     uuid;
  v_n      int;
begin
  if v_ledger is null then
    raise exception 'El usuario no pertenece a ningun libro';
  end if;

  v_n := jsonb_array_length(p_entries);
  if v_n is null or v_n < 2 then
    raise exception 'Un movimiento necesita al menos dos lineas (recibio %)', coalesce(v_n, 0);
  end if;

  insert into transaction (ledger_id, occurred_on, description, kind, created_by, installments)
       values (v_ledger, p_occurred_on, nullif(trim(p_description), ''), p_kind, auth.uid(),
               p_installments)
    returning id into v_tx;

  insert into entry (transaction_id, ledger_id, account_id, category_id, amount, unit)
  select v_tx,
         v_ledger,
         nullif(e->>'account_id', '')::uuid,
         nullif(e->>'category_id', '')::uuid,
         (e->>'amount')::numeric,
         e->>'unit'
    from jsonb_array_elements(p_entries) e;

  -- Al salir de la funcion se confirma la transaccion de base y recien ahi dispara
  -- el trigger diferido de ADR-010. Si no balancea, no queda NADA: ni el movimiento
  -- ni las lineas. Esa es la atomicidad que se buscaba.
  return v_tx;
end $$;

grant execute on function create_transaction(date, text, jsonb, text, int) to authenticated;

-- ===========================================================================
-- 20260918150000_libros_compartidos.sql
-- ===========================================================================

-- Compartir un libro, y el concepto que faltaba para que eso no rompa nada.
-- ADR-028 / OD-36.
--
-- EL PROBLEMA REAL, verificado antes de escribir una linea:
--
--   create function my_ledger() as $$ select * from my_ledgers() limit 1 $$;
--   create policy ... using (ledger_id in (select my_ledgers()))
--
-- El dia que alguien perteneciera a dos libros, SIN CAMBIAR NADA:
--   1. toda lectura mostraria los dos libros MEZCLADOS -la politica filtra por
--      "alguno de los tuyos", no por "el que estas mirando"-, y
--   2. toda escritura iria a uno arbitrario: `limit 1` sin `order by`.
--
-- Asi que lo que faltaba no era una pantalla de invitaciones: era el concepto de
-- LIBRO ACTIVO. Y vive en la base, no en el cliente, por la misma razon de
-- ADR-003: si cada consulta tuviera que acordarse de filtrar, alcanza con
-- olvidarse en una para volver a mezclar, y consultas nuevas se escriben siempre.

create table active_ledger (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  ledger_id uuid not null references ledger(id) on delete cascade,
  set_at    timestamptz not null default now()
);

alter table active_ledger enable row level security;
alter table active_ledger force row level security;

-- La politica NO puede llamar a my_ledger(): my_ledger() lee esta tabla.
create policy active_ledger_self on active_ledger for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select on active_ledger to authenticated;

-- ---------------------------------------------------------------------------
-- Cual es el libro que estoy mirando.
--
-- SECURITY DEFINER porque lo llaman las politicas de RLS de todas las tablas: si
-- fuera invoker, leer `active_ledger` disparia su propia politica y entraria en
-- recursion.
--
-- El respaldo tiene ORDER BY a proposito. El original decia `limit 1` a secas y
-- eso no es "el primero": es cualquiera, y podia cambiar entre dos consultas.
-- ---------------------------------------------------------------------------

create or replace function my_ledger() returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    -- el elegido, siempre que siga siendo mio
    (select a.ledger_id
       from active_ledger a
       join ledger_member m on m.ledger_id = a.ledger_id and m.user_id = a.user_id
      where a.user_id = auth.uid()),
    -- si no eligio ninguno, el primero al que entro. Determinista.
    (select m.ledger_id from ledger_member m
      where m.user_id = auth.uid()
      order by m.joined_at, m.ledger_id
      limit 1)
  )
$$;

grant execute on function my_ledger() to authenticated;

/** Que soy en el libro que estoy mirando: 'owner' o 'member'. */
create or replace function mi_rol() returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select m.role from ledger_member m
   where m.user_id = auth.uid() and m.ledger_id = my_ledger()
$$;

grant execute on function mi_rol() to authenticated;

-- ---------------------------------------------------------------------------
-- RLS: de "alguno de los tuyos" a "el que estas mirando".
--
-- Y la linea de los permisos, que decidio el usuario: un invitado carga y borra
-- MOVIMIENTOS, pero no toca la ESTRUCTURA. La linea esta donde duele el error —
-- un movimiento mal cargado se corrige, una cuenta borrada se lleva su historia.
-- ---------------------------------------------------------------------------

do $$
declare t text;
begin
  -- Datos del dia a dia: cualquier miembro.
  foreach t in array array['transaction','entry','budget','scheduled_event','price','fx_rate'] loop
    execute format('drop policy if exists %1$I_member_rw on %1$I', t);
    execute format($p$
      create policy %1$I_activo_rw on %1$I for all to authenticated
        using      (ledger_id = my_ledger())
        with check (ledger_id = my_ledger())
    $p$, t);
  end loop;

  -- Estructura: todos la ven, solo el duenio la cambia.
  foreach t in array array['account','category','instrument'] loop
    execute format('drop policy if exists %1$I_member_rw on %1$I', t);
    execute format($p$
      create policy %1$I_activo_ro on %1$I for select to authenticated
        using (ledger_id = my_ledger())
    $p$, t);
    execute format($p$
      create policy %1$I_activo_rw on %1$I for insert to authenticated
        with check (ledger_id = my_ledger() and mi_rol() = 'owner')
    $p$, t);
    execute format($p$
      create policy %1$I_activo_up on %1$I for update to authenticated
        using      (ledger_id = my_ledger() and mi_rol() = 'owner')
        with check (ledger_id = my_ledger() and mi_rol() = 'owner')
    $p$, t);
    execute format($p$
      create policy %1$I_activo_del on %1$I for delete to authenticated
        using (ledger_id = my_ledger() and mi_rol() = 'owner')
    $p$, t);
  end loop;
end $$;

-- El libro y sus miembros: se ven los propios, pero solo el duenio suma o saca.
drop policy if exists ledger_member_rw on ledger;
create policy ledger_activo on ledger for select to authenticated
  using (id in (select my_ledgers()));

drop policy if exists ledger_member_self on ledger_member;
create policy ledger_member_ver on ledger_member for select to authenticated
  using (ledger_id in (select my_ledgers()));
create policy ledger_member_admin on ledger_member for all to authenticated
  using      (ledger_id = my_ledger() and mi_rol() = 'owner')
  with check (ledger_id = my_ledger() and mi_rol() = 'owner');

-- ---------------------------------------------------------------------------
-- Invitaciones por codigo, no por correo.
--
-- Buscar a alguien por su correo exigiria una funcion que diga si ese correo
-- esta registrado, y eso es un enumerador de usuarios. Con un codigo no hace
-- falta saber nada del otro: se lo pasas por donde quieras.
--
-- La tabla NO tiene grants para `authenticated`: si se pudiera leer, se podrian
-- listar los codigos vigentes. Se toca solo por las dos funciones de abajo.
-- ---------------------------------------------------------------------------

create table ledger_invite (
  code       text primary key,
  ledger_id  uuid not null references ledger(id) on delete cascade,
  role       text not null default 'member' check (role in ('owner','member')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  used_by    uuid references auth.users(id),
  used_at    timestamptz
);

alter table ledger_invite enable row level security;
alter table ledger_invite force row level security;
-- Sin politicas ni grants: nadie llega por el Data API. A proposito (ADR-020).

create or replace function crear_invitacion(p_role text default 'member')
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_libro  uuid := my_ledger();
  v_codigo text;
begin
  if mi_rol() is distinct from 'owner' then
    raise exception 'Solo quien creo el libro puede invitar';
  end if;
  if p_role not in ('owner','member') then
    raise exception 'Rol invalido';
  end if;

  -- Ocho caracteres: suficiente con vencimiento y un solo uso, y corto como para
  -- dictarlo por telefono sin equivocarse.
  v_codigo := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into ledger_invite (code, ledger_id, role, created_by)
  values (v_codigo, v_libro, p_role, auth.uid());

  return v_codigo;
end $$;

grant execute on function crear_invitacion(text) to authenticated;

create or replace function aceptar_invitacion(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_inv ledger_invite%rowtype;
begin
  select * into v_inv from ledger_invite
   where code = upper(trim(p_code)) for update;

  -- El mismo mensaje para "no existe", "ya se uso" y "vencio": distinguirlos
  -- convertiria esto en un oraculo para adivinar codigos.
  if not found or v_inv.used_at is not null or v_inv.expires_at < now() then
    raise exception 'Ese codigo no sirve: puede estar vencido o ya usado';
  end if;

  if exists (select 1 from ledger_member
              where ledger_id = v_inv.ledger_id and user_id = auth.uid()) then
    raise exception 'Ya formas parte de ese libro';
  end if;

  insert into ledger_member (ledger_id, user_id, role)
  values (v_inv.ledger_id, auth.uid(), v_inv.role);

  update ledger_invite set used_by = auth.uid(), used_at = now() where code = v_inv.code;

  -- Entrar a un libro es querer verlo: se pasa a ser el activo.
  insert into active_ledger (user_id, ledger_id) values (auth.uid(), v_inv.ledger_id)
  on conflict (user_id) do update set ledger_id = excluded.ledger_id, set_at = now();

  return v_inv.ledger_id;
end $$;

grant execute on function aceptar_invitacion(text) to authenticated;

create or replace function cambiar_libro(p_ledger uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (select 1 from ledger_member
                  where ledger_id = p_ledger and user_id = auth.uid()) then
    raise exception 'Ese libro no es tuyo';
  end if;

  insert into active_ledger (user_id, ledger_id) values (auth.uid(), p_ledger)
  on conflict (user_id) do update set ledger_id = excluded.ledger_id, set_at = now();
end $$;

grant execute on function cambiar_libro(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Para el selector. Definer a proposito: ADR-020 le niega al cliente la tabla
-- `ledger`, y esta vista le da exactamente lo que necesita y nada mas.
-- ---------------------------------------------------------------------------

create view mi_libro
with (security_invoker = off) as
  select l.id                                   as ledger_id,
         l.name,
         m.role,
         (l.id = my_ledger())                   as activo,
         (select count(*) from ledger_member x where x.ledger_id = l.id) as miembros,
         m.joined_at
    from ledger l
    join ledger_member m on m.ledger_id = l.id
   where m.user_id = auth.uid();

grant select on mi_libro to authenticated;

comment on view mi_libro is
  'Los libros a los que pertenece quien pregunta, y cual esta mirando. Es lo '
  'unico que la interfaz sabe del libro: ADR-003 sigue valiendo.';

