-- Plazos fijos — brief §12, sobre ADR-014.
--
-- Un plazo fijo es la familia 'accrual' de ADR-012: no cotiza, devenga. Su valor
-- final se conoce el dia que se constituye, asi que no hace falta ninguna fuente
-- de precios: hace falta una FECHA.
--
-- Por eso reusa el motor de eventos futuros de ADR-016: un vencimiento y un gasto
-- recurrente son el mismo objeto, un hecho futuro con fecha y monto conocidos.

-- A donde vuelve la plata al vencer. Para un recurrente no aplica; para un
-- vencimiento es la otra punta del movimiento.
alter table scheduled_event add column if not exists counter_account_id uuid;
alter table scheduled_event add constraint sched_counter_same_ledger
  foreign key (counter_account_id, ledger_id) references account(id, ledger_id);

-- ---------------------------------------------------------------------------
-- Constituirlo: crea la cuenta, mueve la plata y agenda el vencimiento.
-- Las tres cosas en una transaccion: una cuenta sin su transferencia seria una
-- cuenta fantasma, y una transferencia sin su vencimiento agendado es plata que
-- se olvida.
-- ---------------------------------------------------------------------------

create or replace function create_plazo_fijo(
  p_nombre      text,
  p_desde       uuid,      -- cuenta de origen
  p_capital     numeric,
  p_vence       date,
  p_esperado    numeric,   -- cuanto vuelve al vencimiento, capital incluido
  p_institucion text default null,
  p_on          date default null   -- fecha de constitucion
) returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_ledger  uuid := my_ledger();
  v_origen  account%rowtype;
  v_cuenta  uuid;
  v_tx      uuid;
  v_fecha   date := coalesce(p_on, current_date);
begin
  select * into v_origen from account where id = p_desde;
  if not found then raise exception 'No existe la cuenta de origen'; end if;
  if p_capital is null or p_capital <= 0 then
    raise exception 'El capital tiene que ser mayor que cero';
  end if;
  if p_esperado is null or p_esperado < p_capital then
    raise exception 'Lo que vuelve al vencimiento no puede ser menor que el capital';
  end if;
  if p_vence <= v_fecha then
    raise exception 'El vencimiento tiene que ser posterior a la constitucion';
  end if;

  insert into account (ledger_id, name, kind, valuation, unit, is_spendable,
                       matures_on, expected_amount, institution)
       values (v_ledger, p_nombre, 'asset', 'accrual', v_origen.unit, false,
               p_vence, p_esperado, coalesce(p_institucion, v_origen.institution))
    returning id into v_cuenta;

  -- Constituirlo no es un gasto: la plata cambia de lugar, el patrimonio no se
  -- mueve. Por eso ninguna categoria participa.
  insert into transaction (ledger_id, occurred_on, description, kind, created_by)
       values (v_ledger, v_fecha, 'Constitución de ' || p_nombre, 'transfer', auth.uid())
    returning id into v_tx;

  insert into entry (transaction_id, ledger_id, account_id, amount, unit) values
    (v_tx, v_ledger, p_desde,  -p_capital, v_origen.unit),
    (v_tx, v_ledger, v_cuenta,  p_capital, v_origen.unit);

  insert into scheduled_event (ledger_id, kind, description, account_id,
                               counter_account_id, amount, currency, next_on)
       values (v_ledger, 'maturity', 'Vence ' || p_nombre, v_cuenta,
               p_desde, p_esperado, v_origen.unit, p_vence);

  return v_cuenta;
end $$;

grant execute on function create_plazo_fijo(text, uuid, numeric, date, numeric, text, date) to authenticated;

-- ---------------------------------------------------------------------------
-- Vencerlo: el capital vuelve y el interes se reconoce como ingreso.
-- Es el caso 5.12 de modelo-de-datos: tres lineas, una sola unidad, suma cero.
--
-- El interes se calcula, NO se pide: es lo que volvio menos lo que habia. Pedirlo
-- por separado abriria la puerta a que los dos numeros no coincidan.
-- ---------------------------------------------------------------------------

create or replace function register_maturity(
  p_event uuid,
  p_total numeric default null,   -- lo que efectivamente volvio
  p_to    uuid    default null,   -- a que cuenta
  p_on    date    default null
) returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  ev        scheduled_event%rowtype;
  v_capital numeric;
  v_total   numeric;
  v_interes numeric;
  v_destino uuid;
  v_fecha   date;
  v_cat     uuid;
  v_tx      uuid;
begin
  select * into ev from scheduled_event where id = p_event and kind = 'maturity';
  if not found then raise exception 'No existe ese vencimiento'; end if;
  if ev.archived_at is not null then raise exception 'Ese vencimiento ya se registro'; end if;

  v_destino := coalesce(p_to, ev.counter_account_id);
  if v_destino is null then raise exception 'Hace falta indicar a que cuenta vuelve'; end if;

  v_fecha := coalesce(p_on, ev.next_on);
  v_total := coalesce(p_total, ev.amount);
  if v_total is null or v_total <= 0 then
    raise exception 'Hace falta indicar cuanto volvio';
  end if;

  select coalesce(sum(amount), 0) into v_capital from entry where account_id = ev.account_id;
  if v_capital <= 0 then raise exception 'El plazo fijo no tiene capital'; end if;

  v_interes := v_total - v_capital;

  -- La categoria de intereses se busca por lo que ES, no por su nombre: quien la
  -- renombre no deberia romper esto.
  select id into v_cat from category
   where ledger_id = ev.ledger_id and is_system and kind = 'income'
   limit 1;
  if v_cat is null then raise exception 'Falta la categoria de sistema de ingresos'; end if;

  insert into transaction (ledger_id, occurred_on, description, kind, created_by,
                           scheduled_event_id)
       values (ev.ledger_id, v_fecha, ev.description, 'income', auth.uid(), ev.id)
    returning id into v_tx;

  insert into entry (transaction_id, ledger_id, account_id, amount, unit) values
    (v_tx, ev.ledger_id, ev.account_id, -v_capital, ev.currency),
    (v_tx, ev.ledger_id, v_destino,      v_total,   ev.currency);

  -- Solo si hubo interes. Una linea en cero seria ruido en el historial.
  if v_interes <> 0 then
    insert into entry (transaction_id, ledger_id, category_id, amount, unit)
    values (v_tx, ev.ledger_id, v_cat, -v_interes, ev.currency);
  end if;

  -- El plazo fijo cumplio su ciclo: se archiva, no se borra. Sus movimientos
  -- siguen explicando de donde salio y a donde fue.
  update account set archived_at = now() where id = ev.account_id;
  update scheduled_event set archived_at = now() where id = ev.id;

  return v_tx;
end $$;

grant execute on function register_maturity(uuid, numeric, uuid, date) to authenticated;

-- ---------------------------------------------------------------------------
-- La vista de lo que viene ahora tambien dice a donde vuelve y cuanto hay puesto
-- ---------------------------------------------------------------------------

drop view if exists upcoming;

create view upcoming as
  select s.id,
         s.ledger_id,
         s.kind,
         s.description,
         s.amount,
         s.currency,
         s.frequency,
         s.next_on,
         s.ends_on,
         s.category_id,
         c.name  as category_name,
         p.name  as category_parent,
         s.account_id,
         a.name  as account_name,
         s.counter_account_id,
         d.name  as counter_account_name,
         -- cuanto hay puesto: solo tiene sentido para un vencimiento
         case when s.kind = 'maturity'
              then (select coalesce(sum(e.amount), 0) from entry e where e.account_id = s.account_id)
         end as capital,
         (s.next_on - current_date) as dias,
         (s.next_on < current_date) as vencido
    from scheduled_event s
    left join category c on c.id = s.category_id
    left join category p on p.id = c.parent_id
    left join account  a on a.id = s.account_id
    left join account  d on d.id = s.counter_account_id
   where s.archived_at is null
     and (s.ends_on is null or s.ends_on >= current_date);

alter view upcoming set (security_invoker = on);
grant select on upcoming to authenticated;
