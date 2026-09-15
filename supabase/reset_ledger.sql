-- kipo · BORRA TODOS LOS DATOS del libro y vuelve a sembrar las categorias.
--
-- SOLO para la etapa de prueba, ANTES de la puesta en marcha (ADR-018).
-- Despues de esa linea los datos son historia y esta ruta deja de estar permitida:
-- ahi se remapea y se archiva. Ver docs/modelo-de-datos.md §9.
--
--   psql ... -v reset_confirm=BORRAR_TODO -f supabase/reset_ledger.sql
--
\if :{?reset_confirm}
\else
\warn 'ABORTADO: falta -v reset_confirm=BORRAR_TODO'
\quit
\endif

\set ON_ERROR_STOP on
begin;

-- entry cae por cascada desde transaction, pero se borra explicito para no depender de eso
delete from entry;
delete from transaction;
delete from scheduled_event;
delete from budget;
delete from price;
delete from fx_rate;
delete from account;
delete from instrument;
delete from category;

-- se vuelven a sembrar las categorias y la cuenta minima, igual que en el alta
do $$
declare v_ledger uuid; v_parent uuid;
begin
  select id into v_ledger from ledger limit 1;

  insert into category (ledger_id, name, kind, is_system, sort_order) values
    (v_ledger,'Sueldo','income',false,10),
    (v_ledger,'Intereses','income',true,20),
    (v_ledger,'Dividendos','income',false,30),
    (v_ledger,'Otros ingresos','income',false,40);

  insert into category (ledger_id,name,kind,sort_order)
    values (v_ledger,'Gastos fijos','expense',10) returning id into v_parent;
  insert into category (ledger_id,parent_id,name,kind,sort_order) values
    (v_ledger,v_parent,'Alquiler / Expensas','expense',11),
    (v_ledger,v_parent,'Servicios','expense',12),
    (v_ledger,v_parent,'Seguros','expense',13),
    (v_ledger,v_parent,'Impuestos','expense',14),
    (v_ledger,v_parent,'Suscripciones','expense',15);

  insert into category (ledger_id,name,kind,sort_order)
    values (v_ledger,'Gastos variables','expense',20) returning id into v_parent;
  insert into category (ledger_id,parent_id,name,kind,sort_order) values
    (v_ledger,v_parent,'Supermercado','expense',21),
    (v_ledger,v_parent,'Restaurantes','expense',22),
    (v_ledger,v_parent,'Transporte','expense',23),
    (v_ledger,v_parent,'Entretenimiento','expense',24),
    (v_ledger,v_parent,'Compras','expense',25),
    (v_ledger,v_parent,'Salud','expense',26);

  insert into category (ledger_id,name,kind,sort_order)
    values (v_ledger,'Caridad','expense',30) returning id into v_parent;
  insert into category (ledger_id,parent_id,name,kind,sort_order)
    values (v_ledger,v_parent,'Donaciones','expense',31);

  insert into category (ledger_id,name,kind,is_system,sort_order)
    values (v_ledger,'Ajustes','expense',true,90);

  insert into account (ledger_id,name,kind,valuation,unit,is_spendable)
    values (v_ledger,'Efectivo ARS','asset','balance','ARS',true);

  raise notice 'Libro vaciado y resembrado: % categorias, % cuenta',
    (select count(*) from category), (select count(*) from account);
end $$;

commit;
