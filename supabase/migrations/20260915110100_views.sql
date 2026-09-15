-- kipo · vistas de lectura
--
-- Las claves foraneas de 'entry' hacia account/category son COMPUESTAS
-- (account_id, ledger_id) -> account(id, ledger_id), porque asi la base garantiza
-- que todo pertenece al mismo libro sin triggers. El costo es que el inferidor de
-- relaciones de PostgREST puede no resolver el embebido automatico.
--
-- En vez de apostar a que lo resuelva, se expone la union ya hecha: un viaje,
-- sin sintaxis de embebido, y el join lo hace la base que es donde es barato.

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

-- security_invoker: la vista se evalua con los permisos de quien consulta,
-- asi que RLS de las tablas base sigue aplicando. Sin esto seria un agujero.
alter view entry_detail set (security_invoker = on);

comment on view entry_detail is
  'Lineas con el nombre de su cuenta o categoria y los datos de su movimiento. '
  'Evita depender del embebido de PostgREST sobre claves foraneas compuestas.';
