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
