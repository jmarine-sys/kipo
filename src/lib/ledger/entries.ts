import type { EntryInput, TransactionInput, TxKind } from '$lib/types';

// ---------------------------------------------------------------------------
// El convenio de signos vive ACA y en ningun otro lado.
//
// Ninguna pantalla debe razonar sobre signos: expresa la INTENCION ("es un gasto")
// y esto produce las lineas correctas. docs/modelo-de-datos.md §1.
//
//   El signo es siempre desde la perspectiva del PATRIMONIO:
//     activo   positivo -> tenes mas
//     pasivo   positivo -> debes MENOS
//     gasto    positivo -> salio valor hacia ahi
//     ingreso  negativo
// ---------------------------------------------------------------------------

const acc = (id: string, amount: number, unit: string): EntryInput =>
  ({ account_id: id, amount: String(amount), unit });

const cat = (id: string, amount: number, unit: string): EntryInput =>
  ({ category_id: id, amount: String(amount), unit });

function tx(kind: TxKind, entries: EntryInput[], occurred_on: string, description: string | null)
  : TransactionInput {
  return { kind, entries, occurred_on, description };
}

/** Gasto: sale plata de una cuenta hacia una categoria. En una tarjeta, aumenta la deuda. */
export function expense(o: {
  accountId: string; categoryId: string; amount: number; unit: string;
  date: string; description?: string | null;
}): TransactionInput {
  const a = Math.abs(o.amount);
  return tx('expense', [acc(o.accountId, -a, o.unit), cat(o.categoryId, a, o.unit)],
            o.date, o.description ?? null);
}

/** Ingreso: entra plata desde una categoria hacia una cuenta. */
export function income(o: {
  accountId: string; categoryId: string; amount: number; unit: string;
  date: string; description?: string | null;
}): TransactionInput {
  const a = Math.abs(o.amount);
  return tx('income', [acc(o.accountId, a, o.unit), cat(o.categoryId, -a, o.unit)],
            o.date, o.description ?? null);
}

/**
 * Transferencia entre cuentas de la MISMA unidad. Ninguna categoria participa,
 * asi que el patrimonio no cambia y el resultado del mes ni la ve.
 * Cubre tambien pagar el resumen de la tarjeta (ADR-004) y constituir un plazo fijo (ADR-014).
 */
export function transfer(o: {
  fromId: string; toId: string; amount: number; unit: string;
  date: string; description?: string | null;
}): TransactionInput {
  const a = Math.abs(o.amount);
  return tx('transfer', [acc(o.fromId, -a, o.unit), acc(o.toId, a, o.unit)],
            o.date, o.description ?? null);
}

/**
 * Cambio de moneda o compra/venta de un activo: dos unidades distintas.
 * El tipo de cambio (o el precio unitario) NO se guarda: es el cociente. ADR-010.
 */
export function exchange(o: {
  fromId: string; fromAmount: number; fromUnit: string;
  toId: string;   toAmount: number;   toUnit: string;
  date: string; description?: string | null; asTrade?: boolean;
}): TransactionInput {
  return tx(o.asTrade ? 'trade' : 'exchange',
    [acc(o.fromId, -Math.abs(o.fromAmount), o.fromUnit),
     acc(o.toId,    Math.abs(o.toAmount),   o.toUnit)],
    o.date, o.description ?? null);
}

/** Ajuste de saldo: la valvula de escape de los saldos aproximados. ADR-005. */
export function adjustment(o: {
  accountId: string; adjustCategoryId: string; delta: number; unit: string;
  date: string; description?: string | null;
}): TransactionInput {
  return tx('adjustment',
    [acc(o.accountId, o.delta, o.unit), cat(o.adjustCategoryId, -o.delta, o.unit)],
    o.date, o.description ?? null);
}

/** El tipo de cambio implicito de un intercambio, para mostrarlo. ADR-010. */
export function impliedRate(fromAmount: number, toAmount: number): number | null {
  if (!toAmount) return null;
  return Math.abs(fromAmount) / Math.abs(toAmount);
}
