-- "Fin de mes" es una REGLA, no una fecha — OD-38.
--
-- Verificado contra PostgreSQL 16 el 2026-09-18:
--
--   31-ene + 1 mes = 2026-02-28
--   28-feb + 1 mes = 2026-03-28
--   28-mar + 1 mes = 2026-04-28
--
-- Un vencimiento a fin de mes se degrada al 28 en febrero y NO VUELVE NUNCA. Un
-- atajo de interfaz que solo escribiera la fecha seria mentira desde el segundo
-- mes, y de la peor manera: sin fallar.
--
-- POR QUE UNA BANDERA Y NO ADIVINARLO: si la fecha es 28-feb no hay forma de
-- saber si alguien quiso "el 28" o "el ultimo dia" — febrero es justo donde las
-- dos lecturas coinciden. Solo lo sabe quien lo cargo.
--
-- POR QUE UN TRIGGER Y NO TOCAR LAS FUNCIONES: `next_on` lo adelantan hoy dos
-- funciones distintas (registrar una ocurrencia y saltear un periodo) y maniana
-- podria hacerlo una tercera. Con el trigger la regla vale para todas, incluido
-- un UPDATE a mano desde el panel. Reescribir las dos funciones habria dejado el
-- invariante dependiendo de que nadie se olvide.

alter table scheduled_event
  add column if not exists month_end boolean not null default false;

comment on column scheduled_event.month_end is
  'true = vence el ULTIMO dia del mes, sea 28, 30 o 31. Sin esto la fecha se '
  'degrada al 28 tras el primer febrero y no vuelve. OD-38.';

create or replace function ajustar_fin_de_mes() returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.month_end then
    new.next_on := (date_trunc('month', new.next_on) + interval '1 month - 1 day')::date;
  end if;
  return new;
end $$;

create trigger scheduled_event_fin_de_mes
  before insert or update of next_on, month_end on scheduled_event
  for each row execute function ajustar_fin_de_mes();

comment on function ajustar_fin_de_mes() is
  'Lleva next_on al ultimo dia de su mes cuando la regla es de fin de mes. '
  'Corre en INSERT y en cada UPDATE de next_on, asi ninguna funcion que adelante '
  'la agenda necesita acordarse. OD-38.';
