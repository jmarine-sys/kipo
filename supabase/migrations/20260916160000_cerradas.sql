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
