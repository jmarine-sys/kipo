-- Una sola definicion de "como nace un libro".
--
-- Estaba escrita DOS veces: en el trigger de alta y en reset_ledger.sql. Y ya
-- habian discrepado: el reseteo seguia sembrando las veinte categorias viejas y
-- la cuenta "Efectivo ARS" que ADR-027 saco. Quien usara el reseteo para probar
-- "desde cero" habria probado un cero distinto del real.
--
-- Es la cuarta vez que este proyecto tropieza con lo mismo: cuando algo se
-- define en dos lugares, los dos dejan de coincidir.

create or replace function sembrar_libro(p_ledger uuid) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into category (ledger_id, name, kind, is_system, sort_order) values
    (p_ledger, 'Sueldo',           'income',  false, 10),
    (p_ledger, 'Intereses',        'income',  true,  20),   -- ADR-013, ADR-014
    (p_ledger, 'Otros ingresos',   'income',  false, 30),
    (p_ledger, 'Gastos fijos',     'expense', false, 10),
    (p_ledger, 'Gastos variables', 'expense', false, 20),
    (p_ledger, 'Ajuste de saldo',  'expense', true,  90);   -- ADR-005

  -- NO se siembra ninguna cuenta ni ninguna hoja de categoria: lo pregunta la
  -- puesta en marcha (ADR-027). Los padres son estructura; los hijos, opinion.
end $$;

comment on function sembrar_libro(uuid) is
  'Lo minimo con lo que nace un libro. La usan el trigger de alta Y el reseteo, '
  'para que no puedan discrepar.';

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
  perform sembrar_libro(v_ledger);
  return new;
end $$;
