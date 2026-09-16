import type { EntryDetail } from './api';

/**
 * De líneas a filas que se muestran.
 *
 * Existe por un error concreto: en `movimientos` se tomaba `cat.amount` tal cual
 * y se le anteponía un signo. Pero el convenio de signos
 * (docs/modelo-de-datos.md §1) dice que **una categoría de ingreso lleva monto
 * NEGATIVO**, así que un sueldo salía en pantalla como `+-$2.000.000` y, peor,
 * sumaba del lado de los gastos en el total.
 *
 * La causa de fondo: la conversión estaba escrita dentro de una pantalla. Acá
 * vive una sola vez, igual que el convenio de signos vive una sola vez en
 * `entries.ts`. Una pantalla pide una fila; nunca interpreta un signo.
 */
export interface Fila {
  id: string;
  fecha: string;
  titulo: string;
  madre: string | null;
  cuenta: string | null;
  nota: string | null;
  /** SIEMPRE positivo. El sentido lo llevan `signo` y `clase`. */
  monto: number;
  unit: string;
  signo: '+' | '−' | '';
  clase: 'pos' | 'neg' | 'neutro';
  /** true = toca el resultado del mes. Una transferencia no. */
  afectaResultado: boolean;
  esIngreso: boolean;
}

export function filasDeMovimientos(lineas: EntryDetail[]): Fila[] {
  const porTx = new Map<string, EntryDetail[]>();
  for (const e of lineas) {
    porTx.set(e.transaction_id, [...(porTx.get(e.transaction_id) ?? []), e]);
  }

  return [...porTx.entries()].map(([id, es]) => {
    const cat = es.find((e) => e.category_id);
    const neg = es.find((e) => Number(e.amount) < 0 && e.account_id);
    const pos = es.find((e) => Number(e.amount) > 0 && e.account_id);
    const cab = es[0];
    const esIngreso = cat?.category_kind === 'income';

    return {
      id,
      fecha: cab.occurred_on,
      titulo: cat
        ? (cat.category_name ?? '—')
        : `${neg?.account_name ?? '—'} → ${pos?.account_name ?? '—'}`,
      madre: cat?.category_parent ?? null,
      cuenta: cat ? (neg?.account_name ?? pos?.account_name ?? null) : null,
      nota: cab.description,
      // El valor absoluto es la clave del arreglo: en pantalla el signo se
      // dibuja aparte, así que el número no puede traerlo adentro.
      monto: Math.abs(Number(cat ? cat.amount : (neg?.amount ?? 0))),
      unit: cat?.unit ?? neg?.unit ?? 'ARS',
      signo: !cat ? '' : esIngreso ? '+' : '−',
      // el color ES el mensaje: rojo sale, verde entra, neutro no toca el resultado
      clase: !cat ? 'neutro' : esIngreso ? 'pos' : 'neg',
      afectaResultado: !!cat,
      esIngreso
    };
  });
}

/** Cuánto entró y cuánto salió de lo que se está viendo, por separado. */
export function totales(filas: Fila[], unit = 'ARS') {
  let ingresos = 0;
  let gastos = 0;
  for (const f of filas) {
    if (!f.afectaResultado || f.unit !== unit) continue;
    if (f.esIngreso) ingresos += f.monto;
    else gastos += f.monto;
  }
  return { ingresos, gastos };
}
