-- kipo · invariantes del modelo
-- ADR-010 hecha codigo. Lo que esta aca es lo que hace IMPOSIBLE registrar algo inconsistente.

-- ---------------------------------------------------------------------------
-- La invariante central — ADR-010
--   suma cero por unidad, salvo en transacciones de intercambio, donde las dos
--   unidades quedan relacionadas por el cociente de sus montos.
-- ---------------------------------------------------------------------------

create or replace function check_transaction_balances() returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_tx    uuid := coalesce(new.transaction_id, old.transaction_id);
  v_units int;
  v_bad   text;
begin
  select count(*) into v_units
    from (select unit from entry where transaction_id = v_tx group by unit) t;

  -- la transaccion fue borrada entera: nada que validar
  if v_units = 0 then
    return null;
  end if;

  if v_units = 1 then
    select unit into v_bad
      from entry where transaction_id = v_tx
     group by unit having sum(amount) <> 0;
    if v_bad is not null then
      raise exception 'La transaccion % no balancea en %', v_tx, v_bad
        using errcode = 'check_violation';
    end if;

  elsif v_units = 2 then
    -- intercambio (compra de dolares, compra/venta de un activo).
    -- el tipo de cambio o el precio unitario es el COCIENTE y NO SE GUARDA.
    -- lo unico verificable sin una cotizacion externa es que ninguna pata sea neutra.
    if exists (
      select 1 from entry where transaction_id = v_tx
       group by unit having sum(amount) = 0
    ) then
      raise exception
        'En un intercambio ninguna unidad puede tener saldo neto cero (transaccion %)', v_tx
        using errcode = 'check_violation';
    end if;

  else
    -- ADR-010 dice explicitamente RECHAZAR, no suponer que no pasa.
    raise exception
      'Una transaccion no puede mezclar mas de dos unidades (transaccion %, % unidades)',
      v_tx, v_units
      using errcode = 'check_violation';
  end if;

  return null;
end $$;

-- DEFERRABLE INITIALLY DEFERRED es lo que permite insertar las lineas de a una:
-- la validacion corre recien al confirmar, cuando ya estan todas.
create constraint trigger transaction_balances
  after insert or update or delete on entry
  deferrable initially deferred
  for each row execute function check_transaction_balances();

-- ---------------------------------------------------------------------------
-- La unidad de la linea debe coincidir con la de su cuenta.
-- entry.unit esta desnormalizado a proposito (hace barata la validacion de arriba);
-- este trigger es lo que evita que mienta.
-- ---------------------------------------------------------------------------

create or replace function check_entry_unit() returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare v_unit text;
begin
  if new.account_id is not null then
    select unit into v_unit from account where id = new.account_id;
    if v_unit is distinct from new.unit then
      raise exception 'La linea usa la unidad % pero la cuenta tiene %', new.unit, v_unit
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end $$;

create trigger entry_unit_matches_account
  before insert or update on entry
  for each row execute function check_entry_unit();

-- ---------------------------------------------------------------------------
-- Dos niveles de categoria, no tres.
-- ---------------------------------------------------------------------------

create or replace function check_category_depth() returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.parent_id is not null and exists (
    select 1 from category where id = new.parent_id and parent_id is not null
  ) then
    raise exception 'Solo se admiten dos niveles de categoria'
      using errcode = 'check_violation';
  end if;
  if new.parent_id = new.id then
    raise exception 'Una categoria no puede ser su propio padre'
      using errcode = 'check_violation';
  end if;
  return new;
end $$;

create trigger category_two_levels
  before insert or update on category
  for each row execute function check_category_depth();

-- ---------------------------------------------------------------------------
-- updated_at
-- ---------------------------------------------------------------------------

create or replace function touch_updated_at() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin new.updated_at := now(); return new; end $$;

create trigger transaction_touch
  before update on transaction
  for each row execute function touch_updated_at();

-- ---------------------------------------------------------------------------
-- Saldos — modelo-de-datos.md §6
-- ---------------------------------------------------------------------------

create view account_balance as
  select a.id            as account_id,
         a.ledger_id,
         a.name,
         a.kind,
         a.valuation,
         a.unit,
         a.is_spendable,
         coalesce(sum(e.amount), 0) as balance
    from account a
    left join entry e on e.account_id = a.id
   where a.archived_at is null
   group by a.id, a.ledger_id, a.name, a.kind, a.valuation, a.unit, a.is_spendable;

comment on view account_balance is
  'Saldo en la UNIDAD de la cuenta. Para valuation=market son unidades, no plata: '
  'convertirlas a valor requiere price, y a moneda de medicion requiere fx_rate '
  'con la fx_source de la cuenta (ADR-011).';
