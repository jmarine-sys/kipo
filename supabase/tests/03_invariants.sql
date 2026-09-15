\set ON_ERROR_STOP on
-- Tests NEGATIVOS: el modelo tiene que RECHAZAR estas cosas.
-- set constraints immediate hace que el trigger diferido dispare dentro del bloque.
do $$
declare v_l uuid; v_tx uuid; v_ok int := 0;
begin
  select id into v_l from ledger limit 1;

  -- 1. una sola unidad que no suma cero
  begin
    set constraints transaction_balances immediate;
    insert into transaction (ledger_id,occurred_on,kind,created_by)
      values (v_l,date '2026-09-20','expense','11111111-1111-1111-1111-111111111111')
      returning id into v_tx;
    insert into entry (transaction_id,ledger_id,account_id,amount,unit)
      values (v_tx,v_l,(select id from account where name='Banco ARS'),-100,'ARS');
    raise exception 'NO RECHAZO una transaccion desbalanceada';
  exception when check_violation then
    v_ok := v_ok+1; raise notice 'ok  rechaza transaccion desbalanceada';
  end;

  -- 2. tres unidades (ADR-010 dice rechazar, no suponer)
  begin
    set constraints transaction_balances immediate;
    insert into transaction (ledger_id,occurred_on,kind,created_by)
      values (v_l,date '2026-09-20','exchange','11111111-1111-1111-1111-111111111111')
      returning id into v_tx;
    insert into entry (transaction_id,ledger_id,account_id,amount,unit) values
      (v_tx,v_l,(select id from account where name='Banco ARS'),-100,'ARS'),
      (v_tx,v_l,(select id from account where name='Efectivo USD'),1,'USD'),
      (v_tx,v_l,(select id from account where name='Binance USDT'),1,'USDT');
    raise exception 'NO RECHAZO una transaccion con tres unidades';
  exception when check_violation then
    v_ok := v_ok+1; raise notice 'ok  rechaza tres unidades';
  end;

  -- 3. la unidad de la linea no coincide con la de su cuenta
  begin
    insert into transaction (ledger_id,occurred_on,kind,created_by)
      values (v_l,date '2026-09-20','expense','11111111-1111-1111-1111-111111111111')
      returning id into v_tx;
    insert into entry (transaction_id,ledger_id,account_id,amount,unit)
      values (v_tx,v_l,(select id from account where name='Banco ARS'),-100,'USD');
    raise exception 'NO RECHAZO una unidad que no coincide con la cuenta';
  exception when check_violation then
    v_ok := v_ok+1; raise notice 'ok  rechaza unidad distinta a la de la cuenta';
  end;

  -- 4. categoria de tercer nivel
  begin
    insert into category (ledger_id,parent_id,name,kind)
      values (v_l,(select id from category where name='Supermercado'),'Verduleria','expense');
    raise exception 'NO RECHAZO una categoria de tercer nivel';
  exception when check_violation then
    v_ok := v_ok+1; raise notice 'ok  rechaza categoria de tercer nivel';
  end;

  -- 5. linea que apunta a una cuenta Y a una categoria
  begin
    insert into transaction (ledger_id,occurred_on,kind,created_by)
      values (v_l,date '2026-09-20','expense','11111111-1111-1111-1111-111111111111')
      returning id into v_tx;
    insert into entry (transaction_id,ledger_id,account_id,category_id,amount,unit)
      values (v_tx,v_l,(select id from account where name='Banco ARS'),
                       (select id from category where name='Supermercado'),-100,'ARS');
    raise exception 'NO RECHAZO una linea con cuenta Y categoria';
  exception when check_violation then
    v_ok := v_ok+1; raise notice 'ok  rechaza linea con cuenta y categoria a la vez';
  end;

  -- 6. linea que no apunta a ninguna de las dos
  begin
    insert into transaction (ledger_id,occurred_on,kind,created_by)
      values (v_l,date '2026-09-20','expense','11111111-1111-1111-1111-111111111111')
      returning id into v_tx;
    insert into entry (transaction_id,ledger_id,amount,unit) values (v_tx,v_l,-100,'ARS');
    raise exception 'NO RECHAZO una linea sin cuenta ni categoria';
  exception when check_violation then
    v_ok := v_ok+1; raise notice 'ok  rechaza linea sin cuenta ni categoria';
  end;

  if v_ok <> 6 then
    raise exception 'Solo % de 6 invariantes rechazaron', v_ok;
  end if;
  raise notice '--- 6/6 invariantes rechazan correctamente ---';
end $$;
