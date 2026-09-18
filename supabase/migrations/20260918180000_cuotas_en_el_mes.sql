-- El mes tiene que poder decir que parte suya se paga en cuotas — OD-24.
--
-- El resultado del mes se lleva el TOTAL de una compra en cuotas el dia que la
-- hiciste. Eso es honesto —ese dia tu patrimonio bajo 120.000, te comprometiste
-- a pagarlos— pero distorsiona la comparacion mes contra mes, que es el corazon
-- de la aplicacion: octubre se ve pesimo y noviembre artificialmente bueno.
--
-- LA DECISION: un solo numero, y que sea el honesto. Mostrar un segundo
-- resultado "como se paga" seria dar dos verdades sin decir cual mirar, y el
-- usuario terminaria creyendole a la mas amable. Lo que faltaba no era otro
-- numero: era que la pantalla pudiera EXPLICAR el que hay.
--
-- Para eso alcanza con que entry_detail traiga las cuotas de su movimiento.

drop view if exists entry_detail;

create view entry_detail as
  select e.id,
         e.transaction_id,
         e.ledger_id,
         e.amount,
         e.unit,
         e.account_id,
         a.name       as account_name,
         a.kind       as account_kind,
         a.valuation  as account_valuation,
         e.category_id,
         c.name       as category_name,
         c.kind       as category_kind,
         c.is_system  as category_is_system,
         p.name       as category_parent,
         t.occurred_on,
         t.description,
         t.kind       as tx_kind,
         t.installments,
         t.created_at
    from entry e
    join transaction t on t.id = e.transaction_id
    left join account  a on a.id = e.account_id
    left join category c on c.id = e.category_id
    left join category p on p.id = c.parent_id;

alter view entry_detail set (security_invoker = on);
grant select on entry_detail to authenticated;
