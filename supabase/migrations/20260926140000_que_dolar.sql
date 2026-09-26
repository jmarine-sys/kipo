-- Con que dolar se mide cada cosa, elegible.  OD-59, OD-60
--
-- ADR-011 decidio que la fuente de cotizacion es una propiedad de la cuenta y
-- que hay una por defecto para el resto. Las dos mitades estaban a medio hacer:
--
--   - El alta de cuenta preguntaba la fuente SOLO si la moneda era USD. Ahi
--     decide poco -convertir() devuelve el monto tal cual cuando se mide en
--     dolares, y la fuente solo pesa al medir en UVAs- y en una cuenta en PESOS,
--     que es donde decide todo, no se preguntaba nada.
--   - La fuente por defecto del libro nace en 'mep' y no habia ninguna pantalla
--     para verla ni cambiarla. El dolar con el que se mide casi todo era
--     invisible.
--
-- El usuario lo explico asi el 2026-09-26: sus pesos digitales se realizan al
-- MEP y los pesos en efectivo al blue, porque son los dolares que efectivamente
-- conseguiria con cada uno. Eso NO vuelve a ser un tipo de cuenta -efectivo y
-- caja de ahorro se valuan y se gastan igual, que son los dos ejes del tipo
-- (ADR-012, ADR-030)-: es exactamente este campo, y ahora se puede decir.

-- ---------------------------------------------------------------------------
-- El dolar cripto pasa a ser elegible.
--
-- `scripts/cotizaciones.mjs` lo trae todos los dias desde que existe y la
-- restriccion de `account` no lo admitia, asi que se guardaba para nadie. Es el
-- dolar que realmente conseguis con los pesos que mandas a un exchange.
--
-- 'mayorista' y 'uva' NO entran: al mayorista no accede una persona fisica, y la
-- UVA no es un dolar -es la otra vara de medicion, y se elige sola.
-- ---------------------------------------------------------------------------
alter table account drop constraint if exists account_fx_source_check;
alter table account add constraint account_fx_source_check
  check (fx_source in ('oficial','mep','blue','ccl','cripto','manual'));

alter table ledger drop constraint if exists ledger_default_fx_source_check;
alter table ledger add constraint ledger_default_fx_source_check
  check (default_fx_source in ('oficial','mep','blue','ccl','cripto'));

-- ---------------------------------------------------------------------------
-- Cambiar el dolar del libro.
--
-- SECURITY DEFINER por lo mismo que my_fx_source(): ADR-020 le deja al cliente
-- solo SELECT sobre `ledger`, asi que un update directo falla. Se expone la
-- operacion, no la tabla.
--
-- Solo el duenio. Cambiar el dolar del libro reescribe todos los totales que ve
-- cualquiera que lo comparta, y eso no es algo que pueda hacer un invitado, que
-- segun ADR-031 ni siquiera puede crear una cuenta.
-- ---------------------------------------------------------------------------
create or replace function cambiar_dolar(p_fuente text) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_ledger uuid := my_ledger();
begin
  if not exists (select 1 from ledger_member
                  where ledger_id = v_ledger and user_id = auth.uid() and role = 'owner') then
    raise exception 'Solo quien creo el libro puede cambiar con que dolar se mide';
  end if;

  update ledger set default_fx_source = p_fuente where id = v_ledger;
end $$;

grant execute on function cambiar_dolar(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Que dolar esta usando cada cosa, para poder decirlo en pantalla.
--
-- ADR-011 se lo exige a si misma: "toda pantalla que muestre un total en dolares
-- debe poder decir que cotizacion uso". Las posiciones y los portafolios lo
-- decian; Cartera, que es LA pantalla del total, no tenia de donde sacarlo.
--
-- Devuelve una fila por fuente EN USO, con cuantas cuentas la usan. Si hay una
-- sola, la pantalla dice "al MEP"; si hay varias, tiene que decir que el total
-- mezcla -que es correcto y ADR-011 ya avisaba que es mas dificil de explicar-.
-- ---------------------------------------------------------------------------
create or replace view dolar_en_uso as
  select coalesce(a.fx_source, my_fx_source()) as fuente,
         count(*)                              as cuentas,
         bool_or(a.fx_source is null)          as alguna_por_defecto
    from account a
    left join instrument i on i.id = a.instrument_id
   where a.ledger_id = my_ledger()
     and a.archived_at is null
     -- Solo lo que se MIDE EN PESOS, que es lo unico que necesita una
     -- cotizacion para llegar a dolares. Una posicion en USDT o una caja de
     -- ahorro en dolares no convierten nada, asi que nombrar su fuente seria
     -- ruido. Se usa la misma expresion que `valor_cuenta` para saber en que
     -- moneda queda cada cuenta.
     and (case when a.valuation = 'market' then i.quote_currency else a.unit end) = 'ARS'
   group by 1;

alter view dolar_en_uso set (security_invoker = on);
grant select on dolar_en_uso to authenticated;

-- ---------------------------------------------------------------------------
-- `mi_libro` pasa a decir con que dolar mide.
--
-- Es lo unico que la interfaz sabe del libro (ADR-003, ADR-020), asi que si el
-- dato no sale por aca no hay forma de mostrarlo sin abrir la tabla `ledger`.
-- ---------------------------------------------------------------------------
drop view if exists mi_libro;

create view mi_libro
with (security_invoker = off) as
  select l.id                                   as ledger_id,
         l.name,
         m.role,
         (l.id = my_ledger())                   as activo,
         (select count(*) from ledger_member x where x.ledger_id = l.id) as miembros,
         (select count(*) from transaction t where t.ledger_id = l.id)   as movimientos,
         m.joined_at,
         l.default_fx_source                    as dolar
    from ledger l
    join ledger_member m on m.ledger_id = l.id
   where m.user_id = auth.uid()
     and l.archived_at is null;

grant select on mi_libro to authenticated;

comment on view mi_libro is
  'Los libros a los que pertenece quien pregunta, cual esta mirando y con que '
  'dolar mide. Es lo unico que la interfaz sabe del libro: ADR-003 sigue valiendo.';
