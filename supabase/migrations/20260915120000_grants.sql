-- kipo · permisos explicitos del Data API
--
-- Pensada para tener DESACTIVADO "Automatically expose new tables".
-- Con esa opcion activada, Supabase otorga privilegios a anon, authenticated y
-- service_role sobre toda tabla nueva, y lo unico que separa a un desconocido de
-- los datos es RLS. Un solo candado.
--
-- Aca hay DOS candados:
--   1. 'anon' (sin autenticar) no tiene ningun privilegio: no llega ni a la tabla.
--   2. 'authenticated' llega a la tabla, y ahi RLS decide que filas ve.
--
-- Para una app privada de tres personas, que un pedido sin autenticar ni siquiera
-- alcance la tabla es gratis y elimina una clase entera de error.

-- Por si el proyecto se creo con la exposicion automatica activada.
revoke all on all tables    in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke all on all functions in schema public from anon;
revoke usage on schema public from anon;

-- Y que las tablas futuras tampoco lleguen a anon por defecto.
alter default privileges in schema public revoke all on tables from anon;

grant usage on schema public to authenticated;

-- Las nueve tablas del dominio. Sin 'ledger' ni 'ledger_member' a proposito:
-- el cliente nunca las consulta (ADR-003 dice que el libro no existe para la
-- interfaz) y my_ledgers() las lee como SECURITY DEFINER, sin necesitar permisos
-- de quien llama. Menos superficie.
grant select, insert, update, delete on
  account, category, instrument, price, fx_rate,
  transaction, entry, budget, scheduled_event
  to authenticated;

-- Las vistas son de lectura. Heredan RLS por security_invoker.
grant select on account_balance, entry_detail to authenticated;

comment on schema public is
  'anon no tiene privilegios: esta app es privada. Ver 20260915120000_grants.sql';
