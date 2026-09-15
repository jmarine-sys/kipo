-- Dos candados: anon no llega ni a la tabla; authenticated llega y ahi decide RLS.
create role anon_probe login;
grant anon to anon_probe;

do $$
declare v_n int;
begin
  -- 1. un pedido SIN autenticar no debe poder ni tocar la tabla
  begin
    set local role anon_probe;
    execute 'select count(*) from transaction' into v_n;
    reset role;
    raise exception 'FALLO GRAVE: anon leyo la tabla transaction (% filas)', v_n;
  exception when insufficient_privilege then
    reset role;
    raise notice 'ok  anon no tiene permiso ni para tocar la tabla';
  end;

  -- 2. tampoco a traves de la vista
  begin
    set local role anon_probe;
    execute 'select count(*) from entry_detail' into v_n;
    reset role;
    raise exception 'FALLO GRAVE: anon leyo la vista entry_detail';
  exception when insufficient_privilege then
    reset role;
    raise notice 'ok  anon tampoco llega por la vista';
  end;

  -- 3. un usuario autenticado SI llega a la tabla (y ahi manda RLS)
  set local role rls_probe;
  perform set_config('test.uid','11111111-1111-1111-1111-111111111111',true);
  select count(*) into v_n from transaction;
  reset role;
  if v_n = 0 then raise exception 'FALLO: authenticated perdio el acceso'; end if;
  raise notice 'ok  authenticated sigue viendo sus % transacciones', v_n;

  -- 4. y ledger/ledger_member quedan fuera del alcance del cliente
  begin
    set local role rls_probe;
    execute 'select count(*) from ledger' into v_n;
    reset role;
    raise exception 'FALLO: el cliente alcanza la tabla ledger (ADR-003)';
  exception when insufficient_privilege then
    reset role;
    raise notice 'ok  el cliente no alcanza ledger: el libro no existe para el';
  end;
end $$;
