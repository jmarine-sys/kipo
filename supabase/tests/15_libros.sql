-- Libros compartidos: invitar, cambiar, y sobre todo NO MEZCLAR.  OD-36 / ADR-028.
--
-- La asercion que justifica el cambio entero es la de "no mezcla": antes de esto,
-- pertenecer a dos libros hacia que TODA lectura devolviera la union de ambos, y
-- toda escritura fuera a uno arbitrario.
--
-- OJO: el trigger de alta le da un libro propio a cada usuario nuevo, asi que el
-- invitado ya tiene el suyo antes de aceptar nada. Eso es justo lo que hace util
-- la prueba: termina con dos libros de verdad.
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  ('22222222-2222-2222-2222-222222222222', 'invitado@kipo.local');

set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

select case when count(*) = 1 then 'ok  el duenio ve solo su libro'
            else format('FALLO  ve %s', count(*)) end
  from mi_libro;

-- Cuenta y categoria propias de este test. Depender de las de la fixture era
-- fragil: el test 07 RENOMBRA 'Banco ARS' a 'Banco Nacion', asi que en la suite
-- completa el nombre ya no existia y el subselect devolvia null.
insert into account (name, kind, valuation, unit, is_spendable)
  values ('Caja compartida', 'asset', 'balance', 'ARS', true);
insert into category (name, kind) values ('Gasto compartido', 'expense');

select crear_invitacion('member') as codigo \gset
select set_config('test.codigo', :'codigo', false);

select case when length(:'codigo') = 8
            then 'ok  la invitacion es un codigo corto, dictable por telefono'
            else format('FALLO  el codigo es %s', :'codigo') end;

-- ---------------------------------------------------------------------------
-- El invitado acepta. Ya tenia el suyo: ahora tiene dos.
-- ---------------------------------------------------------------------------
select set_config('test.uid','22222222-2222-2222-2222-222222222222', false);

select case when count(*) = 1 then 'ok  el invitado arranca con su propio libro'
            else format('FALLO  arranca con %s', count(*)) end
  from mi_libro;

select case when count(*) = 0
            then 'ok  y no ve NADA del libro ajeno antes de que lo inviten'
            else format('FALLO GRAVE  ya veia %s movimientos ajenos', count(*)) end
  from transaction;

select aceptar_invitacion(:'codigo');

select case when count(*) = 2 then 'ok  al aceptar pasa a tener dos libros'
            else format('FALLO  tiene %s', count(*)) end
  from mi_libro;

select case when count(*) = 1 then 'ok  y exactamente UNO esta activo'
            else format('FALLO  hay %s activos', count(*)) end
  from mi_libro where activo;

select case when role = 'member'
            then 'ok  entra como invitado al ajeno, no como duenio'
            else format('FALLO  entro como %s', role) end
  from mi_libro where activo;

select case when count(*) > 0 then 'ok  ahora si ve los movimientos del libro que lo invito'
            else 'FALLO  no ve nada' end
  from transaction;

-- Puede cargar: para eso lo invitaron.
select case when create_transaction(
                 current_date, 'expense',
                 jsonb_build_array(
                   jsonb_build_object('account_id',(select id from account where name='Caja compartida'),
                                      'amount','-1000','unit','ARS'),
                   jsonb_build_object('category_id',(select id from category where name='Gasto compartido'),
                                      'amount','1000','unit','ARS')),
                 'Gasto del invitado') is not null
            then 'ok  un invitado puede registrar movimientos'
            else 'FALLO  no pudo registrar' end;

-- Pero NO toca la estructura: ahi esta la linea que decidio el usuario.
do $$
begin
  begin
    insert into account (name, kind, valuation, unit, is_spendable)
    values ('Cuenta del invitado', 'asset', 'balance', 'ARS', true);
    raise notice 'FALLO  un invitado creo una cuenta';
  exception when others then
    raise notice 'ok  un invitado NO puede crear cuentas';
  end;

  begin
    delete from category where name = 'Gasto compartido';
    if found then raise notice 'FALLO  un invitado borro una categoria';
    else raise notice 'ok  un invitado NO puede borrar categorias'; end if;
  end;

  begin
    perform crear_invitacion('member');
    raise notice 'FALLO  un invitado pudo invitar a otro';
  exception when others then
    raise notice 'ok  un invitado NO puede invitar a nadie mas';
  end;
end $$;

-- Un codigo se usa UNA sola vez.
do $$
begin
  perform aceptar_invitacion(current_setting('test.codigo', true));
  raise notice 'FALLO  el codigo sirvio dos veces';
exception when others then
  raise notice 'ok  un codigo ya usado no sirve de nuevo';
end $$;

-- ---------------------------------------------------------------------------
-- LO QUE JUSTIFICA TODO EL CAMBIO.
-- ---------------------------------------------------------------------------
select ledger_id as propio from mi_libro where role = 'owner' \gset
select cambiar_libro(:'propio');

select case when count(*) = 0
            then 'ok  al volver a su libro NO ve los movimientos del otro'
            else format('FALLO GRAVE  ve %s movimientos ajenos: los libros se mezclan', count(*)) end
  from transaction;

select case when count(*) = 0
            then 'ok  ni una sola cuenta ajena'
            else format('FALLO GRAVE  ve %s cuentas ajenas', count(*)) end
  from account;

select case when count(*) = 1 and bool_or(role = 'owner')
            then 'ok  el selector marca como activo el libro correcto'
            else 'FALLO  el activo quedo mal' end
  from mi_libro where activo;

-- Y en el suyo vuelve a mandar.
select case when mi_rol() = 'owner'
            then 'ok  en su propio libro vuelve a ser duenio'
            else format('FALLO  es %s', mi_rol()) end;

reset role;

-- ---------------------------------------------------------------------------
-- Tres libros y plata que pasa de uno a otro.  OD-41 / ADR-032.
-- ---------------------------------------------------------------------------
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

select ledger_id as mio from mi_libro where role = 'owner' \gset
select cambiar_libro(:'mio');

insert into account (ledger_id, name, kind, valuation, unit, is_spendable)
values (my_ledger(), 'Mi caja', 'asset', 'balance', 'ARS', true);
select id as micaja from account where name = 'Mi caja' \gset

-- Crear un libro: hasta ahora el unico que existia era el del alta.
select crear_libro('Casa') as casa \gset

select case when count(*) >= 2 then 'ok  ahora se puede ser duenio de mas de un libro'
            else format('FALLO  tiene %s', count(*)) end
  from mi_libro where role = 'owner';

select case when count(*) = 6
            then 'ok  el libro nuevo nace con la misma siembra que uno de alta'
            else format('FALLO  nacio con %s categorias', count(*)) end
  from category where ledger_id = :'casa';

-- La cuenta del libro comun se crea ESTANDO en el libro comun.
insert into account (ledger_id, name, kind, valuation, unit, is_spendable)
values (:'casa', 'Caja de Casa', 'asset', 'balance', 'ARS', true);
select id as cajacasa from account where ledger_id = :'casa' and name = 'Caja de Casa' \gset

select cambiar_libro(:'mio');
-- Sin detalle a proposito: se comprueba el texto POR DEFECTO, que es el que
-- tiene que decir a que libro fue.
select aportar_a_libro(:'casa', :'micaja', :'cajacasa', 50000, current_date) as ref \gset

select case when description = 'Aporte a Casa'
            then 'ok  el aporte dice A QUE libro fue, no "a otro libro"'
            else format('FALLO  dice "%s"', description) end
  from transaction where cross_ref = :'ref' and ledger_id = my_ledger();

-- En MI libro es un gasto: esa plata ya no la puedo usar sola.
select case when round(sum(amount)) = -50000
            then 'ok  en mi libro el aporte SALE de la cuenta'
            else format('FALLO  la cuenta cambio %s', round(sum(amount))) end
  from entry where account_id = :'micaja';

select case when c.kind = 'expense' and c.system_role = 'aporte_enviado'
            then 'ok  y se registra como GASTO, no como transferencia'
            else format('FALLO  quedo como %s / %s', c.kind, c.system_role) end
  from category c
  join entry e on e.category_id = c.id
  join transaction t on t.id = e.transaction_id
 where t.cross_ref = :'ref' and t.ledger_id = my_ledger();

-- Y en el libro comun entra.
select cambiar_libro(:'casa');

select case when round(sum(amount)) = 50000
            then 'ok  en el libro comun la plata ENTRA'
            else format('FALLO  entraron %s', round(sum(amount))) end
  from entry where account_id = :'cajacasa';

select case when count(*) = 1
            then 'ok  las dos mitades quedan unidas por la misma referencia'
            else format('FALLO  hay %s movimientos con esa referencia acá', count(*)) end
  from transaction where cross_ref = :'ref';

select case when description like 'Aporte de %'
            then format('ok  y del otro lado dice de donde vino: "%s"', description)
            else format('FALLO  dice "%s"', description) end
  from transaction where cross_ref = :'ref';

-- Y lo que no se rompe: cada libro sigue cerrando en cero por si solo.
select case when count(*) = 0
            then 'ok  ningun movimiento quedo con lineas de dos libros'
            else format('FALLO GRAVE  %s movimientos cruzan libros', count(*)) end
  from transaction t
  join entry e on e.transaction_id = t.id
 where e.ledger_id <> t.ledger_id;

reset role;

-- ---------------------------------------------------------------------------
-- Sacar un libro: la misma regla que para cuentas y categorias.
--   se BORRA lo que no tiene historia; se ARCHIVA lo que si la tiene.
-- ---------------------------------------------------------------------------
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

select crear_libro('Para borrar') as vacio \gset

select case when count(*) = 3 then 'ok  tres libros antes de sacar ninguno'
            else format('FALLO  hay %s', count(*)) end
  from mi_libro;

-- Uno vacio se borra entero: no se pierde nada.
select eliminar_libro(:'vacio');
select case when count(*) = 2 then 'ok  un libro sin movimientos se borra'
            else format('FALLO  quedaron %s', count(*)) end
  from mi_libro;

-- Uno con historia NO se borra ni pidiendo por favor.
do $$
begin
  perform eliminar_libro((select ledger_id from mi_libro where name = 'Casa'));
  raise notice 'FALLO  borro un libro con movimientos';
exception when others then
  raise notice 'ok  un libro con movimientos NO se borra: se archiva';
end $$;

select archivar_libro((select ledger_id from mi_libro where name = 'Casa'));

select case when count(*) = 1 then 'ok  archivado, desaparece de la lista'
            else format('FALLO  se ven %s', count(*)) end
  from mi_libro;

-- Desde afuera del rol de cliente: ADR-020 le niega la tabla `ledger`, asi que
-- ni para comprobar esto puede verla. Que el propio test se choque con eso es
-- una confirmacion, no un estorbo.
reset role;
select case when count(*) > 0
            then 'ok  pero su historia queda entera en la base'
            else 'FALLO GRAVE  se perdieron los movimientos del libro archivado' end
  from transaction t join ledger l on l.id = t.ledger_id where l.archived_at is not null;
set role rls_probe;
select set_config('test.uid','11111111-1111-1111-1111-111111111111', false);

-- Y no te podes quedar sin ninguno.
do $$
begin
  perform archivar_libro((select ledger_id from mi_libro limit 1));
  raise notice 'FALLO  te dejo sin ningun libro';
exception when others then
  raise notice 'ok  no se puede archivar el unico libro que te queda';
end $$;

reset role;
