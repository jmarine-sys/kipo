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
