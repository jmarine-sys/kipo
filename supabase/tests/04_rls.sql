\set ON_ERROR_STOP on
-- Lo mas critico de todo: que el aislamiento este EN LA BASE y no en el codigo.
-- Se corre como rol NO superusuario, porque un superusuario saltea RLS.
-- El rol de prueba hereda SOLO de 'authenticated': nada de permisos directos.
-- Si se los dieramos a mano, el test no mediria lo que la app realmente tiene
-- y los permisos del Data API quedarian sin verificar.
create role rls_probe login;
grant authenticated to rls_probe;
grant usage on schema auth to rls_probe;
grant select on auth.users to rls_probe;

do $$
declare v_mine int; v_other int;
begin
  set local role rls_probe;

  perform set_config('test.uid','11111111-1111-1111-1111-111111111111',true);
  select count(*) into v_mine from transaction;

  -- otro usuario cualquiera, que no es miembro de ningun libro
  perform set_config('test.uid','99999999-9999-9999-9999-999999999999',true);
  select count(*) into v_other from transaction;

  reset role;

  if v_mine = 0 then
    raise exception 'FALLO RLS: el duenio no ve sus propias transacciones (vio %)', v_mine;
  end if;
  if v_other <> 0 then
    raise exception 'FALLO RLS GRAVE: un extranio vio % transacciones ajenas', v_other;
  end if;
  raise notice 'ok  RLS: el duenio ve % transacciones, un extranio ve %', v_mine, v_other;
end $$;
