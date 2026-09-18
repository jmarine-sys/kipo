import { supabase } from '$lib/supabase';

/**
 * Un portafolio agrupa cuentas: el efectivo del broker y sus posiciones — ADR-026.
 *
 * Pertenecer es OPCIONAL, y esa es toda la diferencia con agrupar por institución:
 * tu cuenta remunerada de Mercado Pago no tiene por qué entrar aunque Mercado
 * Pago también sea una institución.
 */
export interface Portafolio {
  id: string;
  name: string;
  /** Con qué dólar se mide lo de adentro. null = el del libro. */
  fx_source: string | null;
  archived_at: string | null;
}

export interface CuentaDePortafolio {
  id: string;
  name: string;
  valuation: string;
  institution: string | null;
  unit: string;
  /** En qué carteras está. Desde OD-40 puede estar en varias, o en ninguna. */
  carteras: string[];
}

function fallar(contexto: string, error: { message: string } | null): never {
  throw new Error(error?.message ? `${contexto}: ${error.message}` : contexto);
}

export async function listarPortafolios(): Promise<Portafolio[]> {
  const { data, error } = await supabase
    .from('portfolio')
    .select('id, name, fx_source, archived_at')
    .is('archived_at', null)
    .order('name');
  if (error) fallar('No se pudieron leer los portafolios', error);
  return data ?? [];
}

/**
 * Las cuentas que tiene sentido meter en un portafolio.
 *
 * Se excluyen las de gasto diario (`is_spendable`): tu caja de ahorro del sueldo
 * es el AFUERA del portafolio, y meterla adentro borraría el borde que ADR-026
 * acaba de trazar.
 */
export async function cuentasAsignables(): Promise<CuentaDePortafolio[]> {
  const [c, m] = await Promise.all([
    supabase
      .from('account')
      .select('id, name, valuation, institution, unit, is_spendable, kind')
      .is('archived_at', null)
      .eq('kind', 'asset')
      .eq('is_spendable', false)
      .order('name'),
    supabase.from('portfolio_account').select('portfolio_id, account_id')
  ]);
  if (c.error) fallar('No se pudieron leer las cuentas', c.error);
  if (m.error) fallar('No se pudo leer qué cuenta está en qué cartera', m.error);

  const porCuenta = new Map<string, string[]>();
  for (const r of m.data ?? []) {
    porCuenta.set(r.account_id, [...(porCuenta.get(r.account_id) ?? []), r.portfolio_id]);
  }
  return (c.data ?? []).map((a) => ({ ...a, carteras: porCuenta.get(a.id) ?? [] })) as CuentaDePortafolio[];
}

export async function crearPortafolio(name: string, fx_source: string | null): Promise<void> {
  const { error } = await supabase.from('portfolio').insert({ name, fx_source });
  if (error) fallar('No se pudo crear el portafolio', error);
}

/**
 * Sumar o sacar una cuenta de una cartera.
 *
 * Ya no es "mover": una cuenta puede estar en varias a la vez (OD-40), así que
 * cada cartera se marca o se desmarca por su cuenta.
 */
export async function asignarCuenta(
  accountId: string, portfolioId: string, dentro: boolean
): Promise<void> {
  if (dentro) {
    const { error } = await supabase
      .from('portfolio_account')
      .insert({ account_id: accountId, portfolio_id: portfolioId });
    if (error) fallar('No se pudo sumar la cuenta a la cartera', error);
  } else {
    const { error } = await supabase
      .from('portfolio_account')
      .delete()
      .eq('account_id', accountId)
      .eq('portfolio_id', portfolioId);
    if (error) fallar('No se pudo sacar la cuenta de la cartera', error);
  }
}

export async function renombrarPortafolio(id: string, name: string): Promise<void> {
  const { error } = await supabase.from('portfolio').update({ name }).eq('id', id);
  if (error) fallar('No se pudo renombrar', error);
}

/**
 * Archivar, no borrar: las cuentas que apuntaban quedan sueltas por el
 * `on delete set null` de la clave foránea, pero su historia no se toca.
 */
export async function archivarPortafolio(id: string): Promise<void> {
  const { error } = await supabase
    .from('portfolio')
    .update({ archived_at: new Date().toISOString() })
    .eq('id', id);
  if (error) fallar('No se pudo archivar', error);
}
