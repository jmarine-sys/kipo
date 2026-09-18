-- El alta deja de decidir por el usuario — ADR-027.
--
-- Sembraba 20 categorias y una cuenta "Efectivo ARS". La cuenta estaba ahi por
-- una razon escrita y buena: el MVP se mide en que registrar un gasto lleve
-- menos de diez segundos, y sin cuenta no se puede registrar nada.
--
-- Lo que se aprendio probandola con alguien que no la construyo: esas 20
-- categorias no son un atajo, son una taxonomia ajena. Para cargar un cafe habia
-- que leer doce opciones que nadie eligio.
--
-- LA DISTINCION: los padres son ESTRUCTURA, los hijos son OPINION.
--
--   'Gastos fijos' y 'Gastos variables' no son una preferencia: son la
--   correccion del error 2 del analisis -la planilla mezclaba el TIPO de
--   operacion con el CONCEPTO- y sin ellos el modelo no se entiende.
--
--   'Restaurantes' o 'Donaciones' son gustos de quien escribio esto metidos en
--   el libro de otra persona.
--
-- 'Intereses' y 'Ajustes' se quedan y no son negociables: ADR-013, ADR-014 y
-- ADR-005 dependen de que existan. Sin ellas el interes de una cuenta remunerada
-- y el ajuste de saldo no tienen adonde ir.
--
-- Y la cuenta se va: no se puede registrar un gasto sin decir de donde salio,
-- asi que preguntarlo UNA vez es mas honesto que inventar una respuesta. La
-- puesta en marcha se encarga, y es la primera pantalla.

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
    (v_ledger, 'Sueldo',         'income',  false, 10),
    (v_ledger, 'Intereses',      'income',  true,  20),   -- ADR-013, ADR-014
    (v_ledger, 'Otros ingresos', 'income',  false, 30),
    (v_ledger, 'Gastos fijos',   'expense', false, 10),
    (v_ledger, 'Gastos variables','expense', false, 20),
    (v_ledger, 'Ajustes',        'expense', true,  90);   -- ADR-005

  -- NO se siembran "Ahorros" ni "Inversiones": son CUENTAS (ADR-012). Sembrarlas
  -- reintroduciria el error 1, que restaba el ahorro del resultado del mes.
  --
  -- NO se siembra ninguna cuenta: lo hace la puesta en marcha.

  return new;
end $$;
