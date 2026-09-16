-- Cuantos movimientos usan cada cuenta y cada categoria.
--
-- La base ya IMPIDE borrar algo con movimientos: la clave foranea de entry no
-- tiene `on delete`, asi que salta foreign_key_violation. Pero la interfaz no
-- puede enterarse recien al fallar: necesita saberlo ANTES para ofrecer "borrar"
-- o "archivar" segun corresponda.

drop view if exists account_balance;

create view account_balance as
  select a.id           as account_id,
         a.ledger_id,
         a.name,
         a.kind,
         a.valuation,
         a.unit,
         a.is_spendable,
         a.institution,
         coalesce(sum(e.amount), 0) as balance,
         count(e.id)                as movimientos
    from account a
    left join entry e on e.account_id = a.id
   where a.archived_at is null
   group by a.id;

alter view account_balance set (security_invoker = on);
grant select on account_balance to authenticated;

comment on view account_balance is
  'Saldo en la UNIDAD de la cuenta, mas cuantos movimientos la usan. '
  'Para valuation=market el saldo son unidades, no plata.';

create view category_usage as
  select c.id  as category_id,
         c.ledger_id,
         c.name,
         c.kind,
         c.parent_id,
         c.is_system,
         c.sort_order,
         count(e.id) as movimientos
    from category c
    left join entry e on e.category_id = c.id
   where c.archived_at is null
   group by c.id;

alter view category_usage set (security_invoker = on);
grant select on category_usage to authenticated;
