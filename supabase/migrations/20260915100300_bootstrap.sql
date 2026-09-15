-- kipo · alta de usuario
-- ADR-003: al registrarse, cada usuario obtiene su libro automaticamente.
-- Si el usuario llega a ver la palabra "libro" en la interfaz, esta decision fallo.

create or replace function handle_new_user() returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_ledger uuid;
  v_parent uuid;
begin
  insert into ledger (name) values ('Personal') returning id into v_ledger;
  insert into ledger_member (ledger_id, user_id, role) values (v_ledger, new.id, 'owner');

  -- ------------------------------------------------------------------
  -- Categorias de ingreso
  -- ------------------------------------------------------------------
  insert into category (ledger_id, name, kind, is_system, sort_order) values
    (v_ledger, 'Sueldo',         'income', false, 10),
    -- ADR-013 (interes de cuenta remunerada) y ADR-014 (vencimiento de plazo fijo)
    -- dependen de que esta categoria exista: por eso is_system.
    (v_ledger, 'Intereses',      'income', true,  20),
    (v_ledger, 'Dividendos',     'income', false, 30),
    (v_ledger, 'Otros ingresos', 'income', false, 40);

  -- ------------------------------------------------------------------
  -- Categorias de gasto
  -- ------------------------------------------------------------------
  insert into category (ledger_id, name, kind, sort_order)
    values (v_ledger, 'Gastos fijos', 'expense', 10) returning id into v_parent;
  insert into category (ledger_id, parent_id, name, kind, sort_order) values
    (v_ledger, v_parent, 'Alquiler / Expensas', 'expense', 11),
    (v_ledger, v_parent, 'Servicios',           'expense', 12),
    (v_ledger, v_parent, 'Seguros',             'expense', 13),
    (v_ledger, v_parent, 'Impuestos',           'expense', 14),
    (v_ledger, v_parent, 'Suscripciones',       'expense', 15);

  insert into category (ledger_id, name, kind, sort_order)
    values (v_ledger, 'Gastos variables', 'expense', 20) returning id into v_parent;
  insert into category (ledger_id, parent_id, name, kind, sort_order) values
    (v_ledger, v_parent, 'Supermercado',    'expense', 21),
    (v_ledger, v_parent, 'Restaurantes',    'expense', 22),
    (v_ledger, v_parent, 'Transporte',      'expense', 23),
    (v_ledger, v_parent, 'Entretenimiento', 'expense', 24),
    (v_ledger, v_parent, 'Compras',         'expense', 25),
    (v_ledger, v_parent, 'Salud',           'expense', 26);

  insert into category (ledger_id, name, kind, sort_order)
    values (v_ledger, 'Caridad', 'expense', 30) returning id into v_parent;
  insert into category (ledger_id, parent_id, name, kind, sort_order) values
    (v_ledger, v_parent, 'Donaciones', 'expense', 31);

  -- ADR-005: la valvula de escape de los saldos aproximados. Si esta categoria crece
  -- mes a mes, es senal de que algo se esta cargando mal — la deriva queda MEDIDA.
  insert into category (ledger_id, name, kind, is_system, sort_order)
    values (v_ledger, 'Ajustes', 'expense', true, 90);

  -- ------------------------------------------------------------------
  -- NO se siembran "Ahorros" ni "Inversiones" como categorias.
  -- ADR-012: son CUENTAS. Sembrarlas aca reintroduciria el error 1 del analisis,
  -- que restaba el ahorro del resultado del mes y castigaba ahorrar.
  -- ------------------------------------------------------------------

  -- Una cuenta minima para que el primer gasto se pueda cargar sin configurar nada:
  -- el MVP se mide en que registrar un gasto lleve menos de diez segundos.
  insert into account (ledger_id, name, kind, valuation, unit, is_spendable)
    values (v_ledger, 'Efectivo ARS', 'asset', 'balance', 'ARS', true);

  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
