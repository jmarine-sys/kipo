-- Renombrar y borrar cuentas y categorias.
-- Lo que protege el historial no es la interfaz: es la clave foranea. Estos tests
-- corren como 'authenticated', igual que la aplicacion.
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

\set ON_ERROR_STOP off

-- 1. borrar una cuenta CON movimientos: debe fallar
delete from account where name = 'Banco ARS';

-- 2. borrar una categoria CON movimientos: debe fallar
delete from category where name = 'Supermercado';

\set ON_ERROR_STOP on

select case when count(*) = 1 then 'ok  la cuenta con movimientos sigue viva'
            else 'FALLO  se borro una cuenta con movimientos' end
  from account where name = 'Banco ARS';

select case when count(*) = 1 then 'ok  la categoria con movimientos sigue viva'
            else 'FALLO  se borro una categoria con movimientos' end
  from category where name = 'Supermercado';

-- 3. renombrar SIEMPRE es seguro: los movimientos apuntan al id, no al nombre.
-- Se mide ANTES y DESPUES en vez de fijar un numero: cuantos movimientos haya
-- depende de que otros tests corrieron antes, y eso no es lo que se prueba aca.
select count(*) as antes_mov from entry e join account a on a.id = e.account_id
 where a.name = 'Banco ARS' \gset

update account set name = 'Banco Nacion' where name = 'Banco ARS';

select case when count(*) = :antes_mov
            then format('ok  renombrar no toco sus %s movimientos', count(*))
            else format('FALLO  tenia %s y quedaron %s', :antes_mov, count(*)) end
  from entry e join account a on a.id = e.account_id where a.name = 'Banco Nacion';

-- 4. borrar algo SIN movimientos: debe poder
select count(*) as antes from category where kind = 'expense' \gset
delete from category where name = 'Donaciones';
select case when count(*) = :antes - 1 then 'ok  se borra lo que no tiene movimientos'
            else 'FALLO  no dejo borrar una categoria vacia' end
  from category where kind = 'expense';

-- 5. las vistas informan bien cuantos movimientos hay
select case when movimientos = :antes_mov
            then format('ok  account_balance cuenta los %s movimientos', movimientos)
            else format('FALLO  hay %s pero conto %s', :antes_mov, movimientos) end
  from account_balance where name = 'Banco Nacion';

select case when movimientos = 0 then 'ok  category_usage marca en 0 las no usadas'
            else 'FALLO  conto de mas' end
  from category_usage where name = 'Transporte';

reset role;
