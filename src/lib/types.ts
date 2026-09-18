// Espejo de docs/modelo-de-datos.md §2. Si esto y el esquema discrepan, manda el esquema.

/** Las tres familias de ADR-012: como se responde "cuanto vale hoy". */
export type Valuation = 'balance' | 'accrual' | 'market';
export type AccountKind = 'asset' | 'liability';
export type CategoryKind = 'income' | 'expense';
export type FxSource = 'oficial' | 'mep' | 'blue' | 'ccl' | 'manual';

/** La INTENCION con la que se cargo. Las entries son la verdad; esto es pista de interfaz. */
export type TxKind = 'expense' | 'income' | 'transfer' | 'exchange' | 'trade' | 'adjustment';

export interface Account {
  id: string;
  name: string;
  kind: AccountKind;
  valuation: Valuation;
  unit: string;
  instrument_id: string | null;
  is_spendable: boolean;
  fx_source: FxSource | null;
  matures_on: string | null;
  expected_amount: string | null;
  institution: string | null;
  archived_at: string | null;
}

export interface Category {
  id: string;
  parent_id: string | null;
  name: string;
  kind: CategoryKind;
  is_system: boolean;
  sort_order: number;
  archived_at: string | null;
}

export interface AccountBalance {
  account_id: string;
  name: string;
  kind: AccountKind;
  valuation: Valuation;
  unit: string;
  is_spendable: boolean;
  institution: string | null;
  balance: string;
  /** Cuántos movimientos la usan. Si es 0, se puede borrar; si no, solo archivar. */
  movimientos: number;
}

export interface CategoryUsage {
  category_id: string;
  name: string;
  kind: CategoryKind;
  parent_id: string | null;
  is_system: boolean;
  sort_order: number;
  /** Lo imputado a ella directamente. */
  movimientos: number;
  /** Con sus hijas incluidas: es lo que decide si se puede borrar. */
  movimientos_arbol: number;
  /** El OTRO motivo por el que a veces no se puede borrar, aun sin movimientos. */
  hijas: number;
}

/** Una pata del movimiento. Exactamente uno de account_id / category_id. */
export interface EntryInput {
  account_id?: string | null;
  category_id?: string | null;
  amount: string;
  unit: string;
}

export interface TransactionInput {
  occurred_on: string;
  description: string | null;
  kind: TxKind;
  entries: EntryInput[];
  /**
   * En cuántas cuotas se pagó. null = de una.
   *
   * NO parte la deuda: la compra entra entera contra la tarjeta el día 1
   * (ADR-004). Solo permite proyectar en qué resumen va a caer cada parte.
   */
  installments?: number | null;
}
