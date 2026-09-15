-- kipo · aislamiento entre usuarios — ADR-002, ADR-003, ADR-007
-- El aislamiento vive EN LA BASE, no en el codigo de la aplicacion.
-- Un bug del frontend no puede mostrarle a alguien las finanzas de otro.

-- SECURITY DEFINER a proposito: la funcion corre como su duena (postgres), que no esta
-- sujeta a RLS, y por eso leer ledger_member aca NO dispara la politica de ledger_member.
-- Sin esto habria recursion infinita.
create or replace function my_ledgers() returns setof uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select ledger_id from ledger_member where user_id = auth.uid()
$$;

revoke all on function my_ledgers() from public;
grant execute on function my_ledgers() to authenticated;

-- Todas las tablas del dominio llevan ledger_id, asi que la politica es LA MISMA en
-- todas y no necesita joins. La lista es explicita para que sea auditable de un vistazo.
do $$
declare t text;
begin
  foreach t in array array[
    'account','category','instrument','price','fx_rate',
    'transaction','entry','budget','scheduled_event'
  ] loop
    execute format('alter table %I enable row level security', t);
    execute format('alter table %I force row level security', t);
    execute format($p$
      create policy %1$I_member_rw on %1$I for all to authenticated
        using      (ledger_id in (select my_ledgers()))
        with check (ledger_id in (select my_ledgers()))
    $p$, t);
  end loop;
end $$;

-- ledger y ledger_member no tienen columna ledger_id: van aparte.
alter table ledger enable row level security;
alter table ledger force row level security;
create policy ledger_member_rw on ledger for all to authenticated
  using      (id in (select my_ledgers()))
  with check (id in (select my_ledgers()));

alter table ledger_member enable row level security;
alter table ledger_member force row level security;
create policy ledger_member_self on ledger_member for all to authenticated
  using      (ledger_id in (select my_ledgers()))
  with check (ledger_id in (select my_ledgers()));

-- La vista hereda el RLS de sus tablas base (security_invoker).
alter view account_balance set (security_invoker = on);
