import { supabase } from '$lib/supabase';
import type {
  Account, AccountBalance, Category, CategoryUsage, TransactionInput
} from '$lib/types';

export interface EntryDetail {
  id: string;
  transaction_id: string;
  amount: string;
  unit: string;
  account_id: string | null;
  account_name: string | null;
  account_kind: 'asset' | 'liability' | null;
  category_id: string | null;
  category_name: string | null;
  category_kind: 'income' | 'expense' | null;
  category_is_system: boolean | null;
  category_parent: string | null;
  occurred_on: string;
  description: string | null;
  tx_kind: string;
}

/**
 * Los mensajes de la base vienen en castellano y son especificos
 * ("La transaccion no balancea en ARS"). Se muestran tal cual: explican mejor que
 * cualquier texto generico que pudieramos inventar aca.
 */
function fail(context: string, error: { message: string } | null): never {
  throw new Error(error?.message ? `${context}: ${error.message}` : context);
}

export async function listAccounts(): Promise<Account[]> {
  const { data, error } = await supabase
    .from('account')
    .select('*')
    .is('archived_at', null)
    .order('name');
  if (error) fail('No se pudieron leer las cuentas', error);
  return data ?? [];
}

export async function listBalances(): Promise<AccountBalance[]> {
  const { data, error } = await supabase.from('account_balance').select('*').order('name');
  if (error) fail('No se pudieron leer los saldos', error);
  return data ?? [];
}

export async function listCategories(): Promise<Category[]> {
  const { data, error } = await supabase
    .from('category')
    .select('*')
    .is('archived_at', null)
    .order('sort_order');
  if (error) fail('No se pudieron leer las categorias', error);
  return data ?? [];
}

/** Escritura atomica: movimiento y lineas en un viaje. Ver la RPC create_transaction. */
export async function createTransaction(t: TransactionInput): Promise<string> {
  const { data, error } = await supabase.rpc('create_transaction', {
    p_occurred_on: t.occurred_on,
    p_kind: t.kind,
    p_entries: t.entries,
    p_description: t.description
  });
  if (error) fail('No se pudo guardar el movimiento', error);
  return data as string;
}

export async function listEntries(from: string, to: string): Promise<EntryDetail[]> {
  const { data, error } = await supabase
    .from('entry_detail')
    .select('*')
    .gte('occurred_on', from)
    .lte('occurred_on', to)
    .order('occurred_on', { ascending: false })
    .order('created_at', { ascending: false });
  if (error) fail('No se pudieron leer los movimientos', error);
  return data ?? [];
}

export async function deleteTransaction(id: string): Promise<void> {
  const { error } = await supabase.from('transaction').delete().eq('id', id);
  if (error) fail('No se pudo borrar el movimiento', error);
}

// ---------------------------------------------------------------------------
// Resumen del mes — docs/modelo-de-datos.md §6
// El ahorro y las inversiones NO aparecen: no tocan ninguna categoria.
// ---------------------------------------------------------------------------

export interface MonthSummary {
  income: number;
  /** Gastos de verdad. NO incluye los ajustes de saldo. */
  expense: number;
  /**
   * Ajustes de saldo (ADR-005). Restan del resultado igual que un gasto —esa plata
   * se fue de verdad, aunque no sepamos en qué— pero se muestran aparte: mezclarlos
   * con "Gastos" mentiría sobre en qué gastaste.
   */
  adjustments: number;
  result: number;
  savingRate: number | null;
  byCategory: { name: string; parent: string | null; total: number }[];
}

export function summarize(entries: EntryDetail[], unit = 'ARS'): MonthSummary {
  let income = 0;
  let expense = 0;
  let adjustments = 0;
  const byCategory = new Map<string, { name: string; parent: string | null; total: number }>();

  for (const e of entries) {
    if (!e.category_id || e.unit !== unit) continue;
    const amount = Number(e.amount);

    // convenio de signos: ingreso negativo, gasto positivo
    if (e.category_kind === 'income') {
      income += -amount;
      continue;
    }

    if (e.category_is_system) {
      adjustments += amount;   // resta del resultado, pero no es un gasto
      continue;
    }

    expense += amount;
    const row = byCategory.get(e.category_id) ?? {
      name: e.category_name ?? '—',
      parent: e.category_parent,
      total: 0
    };
    row.total += amount;
    byCategory.set(e.category_id, row);
  }

  // El ajuste TIENE que restar: si no, el resultado del mes dejaría de explicar
  // el cambio de patrimonio, y ese es justamente el punto del modelo.
  const result = income - expense - adjustments;
  return {
    income,
    expense,
    adjustments,
    result,
    savingRate: income > 0 ? result / income : null,
    byCategory: [...byCategory.values()].sort((a, b) => b.total - a.total)
  };
}

// ---------------------------------------------------------------------------
// Exportacion — principio de datos exportables del brief §20
// ---------------------------------------------------------------------------

export function toCSV(entries: EntryDetail[]): string {
  const head = ['fecha', 'movimiento', 'descripcion', 'cuenta', 'categoria', 'monto', 'unidad'];
  const esc = (v: unknown) => {
    const s = v == null ? '' : String(v);
    return /[",\n;]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const rows = entries.map((e) =>
    [e.occurred_on, e.tx_kind, e.description, e.account_name,
     e.category_parent ? `${e.category_parent} / ${e.category_name}` : e.category_name,
     e.amount, e.unit].map(esc).join(',')
  );
  return [head.join(','), ...rows].join('\n');
}

export function download(filename: string, content: string, type: string) {
  const url = URL.createObjectURL(new Blob([content], { type }));
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

// ---------------------------------------------------------------------------
// Alta y archivado. Nada se BORRA: se archiva (principio de historial, brief §20).
// La base ya lo impone: la clave foranea bloquea borrar algo con movimientos.
// ---------------------------------------------------------------------------

export interface NewAccount {
  name: string;
  kind: 'asset' | 'liability';
  unit: string;
  is_spendable: boolean;
  institution?: string | null;
  fx_source?: string | null;
}

export async function createAccount(a: NewAccount): Promise<void> {
  // Las tres familias de ADR-012: el MVP solo crea cuentas de la familia 'balance'.
  // 'accrual' (plazo fijo) y 'market' (posiciones) llegan en la etapa 5.
  const { error } = await supabase.from('account').insert({ ...a, valuation: 'balance' });
  if (error) fail('No se pudo crear la cuenta', error);
}

export async function archiveAccount(id: string): Promise<void> {
  const { error } = await supabase
    .from('account')
    .update({ archived_at: new Date().toISOString() })
    .eq('id', id);
  if (error) fail('No se pudo archivar la cuenta', error);
}

export async function createCategory(c: {
  name: string; kind: 'income' | 'expense'; parent_id?: string | null;
}): Promise<void> {
  const { error } = await supabase.from('category').insert(c);
  if (error) fail('No se pudo crear la categoría', error);
}

export async function archiveCategory(id: string): Promise<void> {
  const { error } = await supabase
    .from('category')
    .update({ archived_at: new Date().toISOString() })
    .eq('id', id);
  if (error) fail('No se pudo archivar la categoría', error);
}


// ---------------------------------------------------------------------------
// Renombrar y borrar — brief §20: no destruir información histórica
//
// Renombrar es SIEMPRE seguro: los movimientos apuntan al id, no al nombre.
// Borrar solo se permite si no hay nada colgando, y quien lo impide de verdad
// no es este código sino la clave foránea: aunque alguien llame a la API a mano,
// la base rechaza el borrado. Acá solo se traduce ese rechazo a castellano.
// ---------------------------------------------------------------------------

function esBorradoBloqueado(e: { code?: string; message?: string } | null): boolean {
  return e?.code === '23503' || /foreign key|llave foránea/i.test(e?.message ?? '');
}

export async function listCategoryUsage(): Promise<CategoryUsage[]> {
  const { data, error } = await supabase
    .from('category_usage')
    .select('*')
    .order('sort_order');
  if (error) fail('No se pudieron leer las categorías', error);
  return data ?? [];
}

export async function renameAccount(id: string, name: string): Promise<void> {
  const { error } = await supabase.from('account').update({ name: name.trim() }).eq('id', id);
  if (error) fail('No se pudo renombrar la cuenta', error);
}

export async function deleteAccount(id: string): Promise<void> {
  const { error } = await supabase.from('account').delete().eq('id', id);
  if (error) {
    if (esBorradoBloqueado(error)) {
      throw new Error(
        'Esta cuenta tiene movimientos, así que no se puede borrar: archivala. ' +
        'Borrarla dejaría movimientos sin explicación.'
      );
    }
    fail('No se pudo borrar la cuenta', error);
  }
}

export async function renameCategory(id: string, name: string): Promise<void> {
  const { error } = await supabase.from('category').update({ name: name.trim() }).eq('id', id);
  if (error) fail('No se pudo renombrar la categoría', error);
}

export async function deleteCategory(id: string): Promise<void> {
  const { error } = await supabase.from('category').delete().eq('id', id);
  if (error) {
    if (esBorradoBloqueado(error)) {
      throw new Error(
        'Esta categoría tiene movimientos, así que no se puede borrar: archivala. ' +
        'Los movimientos viejos siguen mostrándola.'
      );
    }
    fail('No se pudo borrar la categoría', error);
  }
}
