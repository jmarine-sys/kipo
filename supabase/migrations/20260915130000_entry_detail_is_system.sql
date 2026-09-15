-- Expone si la categoria es de sistema, para poder mostrar los AJUSTES separados
-- de los gastos reales en el resumen del mes.
--
-- Un ajuste (ADR-005) resta del resultado igual que un gasto —esa plata se fue de
-- verdad, aunque no sepamos en que— pero mezclarlo con "Gastos" miente sobre en que
-- gastaste. Se muestra en su propia linea.

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
         t.created_at
    from entry e
    join transaction t on t.id = e.transaction_id
    left join account  a on a.id = e.account_id
    left join category c on c.id = e.category_id
    left join category p on p.id = c.parent_id;

alter view entry_detail set (security_invoker = on);
grant select on entry_detail to authenticated;

comment on view entry_detail is
  'Lineas con el nombre de su cuenta o categoria y los datos de su movimiento. '
  'Evita depender del embebido de PostgREST sobre claves foraneas compuestas.';
