import { supabase } from '$lib/supabase';

/** Las frecuencias que admite el modelo, con su nombre en castellano. */
export const FRECUENCIAS = [
  { id: 'weekly',    label: 'Semanal' },
  { id: 'monthly',   label: 'Mensual' },
  { id: 'bimonthly', label: 'Bimestral' },
  { id: 'quarterly', label: 'Trimestral' },
  { id: 'biannual',  label: 'Semestral' },
  { id: 'yearly',    label: 'Anual' }
] as const;

export type Frecuencia = (typeof FRECUENCIAS)[number]['id'];

export function nombreFrecuencia(f: string | null): string {
  return FRECUENCIAS.find((x) => x.id === f)?.label ?? '—';
}

export interface Upcoming {
  id: string;
  kind: 'recurring' | 'maturity';
  description: string;
  /** null = el importe cambia cada período y se pide al registrar */
  amount: string | null;
  currency: string;
  frequency: Frecuencia | null;
  next_on: string;
  ends_on: string | null;
  category_id: string | null;
  category_name: string | null;
  category_parent: string | null;
  account_id: string | null;
  account_name: string | null;
  /** solo en vencimientos: a qué cuenta vuelve la plata */
  counter_account_id: string | null;
  counter_account_name: string | null;
  /** solo en vencimientos: cuánto capital hay puesto */
  capital: string | null;
  dias: number;
  vencido: boolean;
}

export interface NuevoRecurrente {
  /** true = vence el último día del mes, sea 28, 30 o 31 (OD-38). */
  month_end?: boolean;
  description: string;
  category_id: string;
  account_id: string | null;
  amount: number | null;
  currency: string;
  frequency: Frecuencia;
  next_on: string;
  ends_on?: string | null;
}

function fallar(contexto: string, error: { message: string } | null): never {
  throw new Error(error?.message ? `${contexto}: ${error.message}` : contexto);
}

export async function listUpcoming(): Promise<Upcoming[]> {
  const { data, error } = await supabase.from('upcoming').select('*').order('next_on');
  if (error) fallar('No se pudo leer lo que viene', error);
  return data ?? [];
}

export async function createScheduled(r: NuevoRecurrente): Promise<void> {
  const { error } = await supabase
    .from('scheduled_event')
    .insert({ ...r, kind: 'recurring', amount: r.amount ?? null });
  if (error) fallar('No se pudo crear', error);
}

export async function updateScheduled(id: string, patch: Partial<NuevoRecurrente>): Promise<void> {
  const { error } = await supabase.from('scheduled_event').update(patch).eq('id', id);
  if (error) fallar('No se pudo guardar', error);
}

export async function archiveScheduled(id: string): Promise<void> {
  const { error } = await supabase
    .from('scheduled_event')
    .update({ archived_at: new Date().toISOString() })
    .eq('id', id);
  if (error) fallar('No se pudo archivar', error);
}

/**
 * Registra la ocurrencia: crea el movimiento Y adelanta la fecha, en una sola
 * transacción de base. El sistema nunca lo hace solo — el brief pide recordar y
 * proyectar, no ejecutar pagos.
 */
export async function registerScheduled(
  id: string,
  opciones: { amount?: number | null; on?: string | null; accountId?: string | null } = {}
): Promise<string> {
  const { data, error } = await supabase.rpc('register_scheduled', {
    p_event: id,
    p_amount: opciones.amount ?? null,
    p_on: opciones.on ?? null,
    p_account: opciones.accountId ?? null
  });
  if (error) fallar('No se pudo registrar', error);
  return data as string;
}

/** Saltea el período sin registrar nada: el impuesto que no vino, la suscripción pausada. */
export async function skipScheduled(id: string): Promise<string> {
  const { data, error } = await supabase.rpc('skip_scheduled', { p_event: id });
  if (error) fallar('No se pudo saltear', error);
  return data as string;
}

/** Cómo se dice cuánto falta. Más legible que una fecha suelta. */
export function cuandoFalta(dias: number): string {
  if (dias < 0) return `vencido hace ${-dias} día${dias === -1 ? '' : 's'}`;
  if (dias === 0) return 'hoy';
  if (dias === 1) return 'mañana';
  if (dias < 30) return `en ${dias} días`;
  const meses = Math.round(dias / 30);
  return `en ${meses} mes${meses === 1 ? '' : 'es'}`;
}
