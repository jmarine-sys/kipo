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
