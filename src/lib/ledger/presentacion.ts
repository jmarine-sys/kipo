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
/** Lo mínimo para nombrar una cuenta igual en toda la app. Ver Cuenta.svelte. */
export interface CuentaRef {
  name: string;
  unit: string;
  kind: string | null;
  institution: string | null;
}

const refDe = (e: EntryDetail | undefined): CuentaRef | null =>
  e?.account_name
    ? { name: e.account_name, unit: e.unit, kind: e.account_kind ?? null,
        institution: e.account_institution ?? null }
    : null;

export interface Fila {
  id: string;
  /** Texto plano, para buscar y como respaldo. Lo que se dibuja son las refs. */
  titulo: string;
  fecha: string;
  /**
   * El grupo al que pertenece, para agrupar y filtrar.
   *
   * Es la categoría madre si la tiene, y ELLA MISMA si es de primer nivel. Antes
   * era solo `category_parent`, que es null para una categoría sin madre: un
   * gasto imputado directo a «Gastos fijos» no aparecía en el filtro y, peor,
   * DESAPARECÍA de la lista en cuanto se filtraba por cualquier cosa.
   */
  grupo: string | null;
  /**
   * Las cuentas involucradas, como objetos y no como nombres sueltos.
   *
   * Antes era un string con el nombre pelado, y en la lista de movimientos no se
   * podía saber si «Caja de ahorro» era la de pesos o la de dólares, ni si el
   * gasto había ido a una tarjeta. OD-42.
   */
  cuenta: CuentaRef | null;
  desde: CuentaRef | null;
  hacia: CuentaRef | null;
  nota: string | null;
  /** SIEMPRE positivo. El sentido lo llevan `signo` y `clase`. */
  monto: number;
  unit: string;
  signo: '+' | '−' | '';
  clase: 'pos' | 'neg' | 'neutro';
  /** true = toca el resultado del mes. Una transferencia no. */
  afectaResultado: boolean;
  /** true = la plata ENTRÓ. Sale del signo, no del tipo de categoría. */
  entra: boolean;
  /** true = la categoría es de ingreso. No es lo mismo que `entra`: un ajuste
      hacia arriba entra y su categoría es de gasto. */
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

    /**
     * Si esta plata ENTRÓ, y sale del SIGNO — no del tipo de categoría.
     *
     * Por el tipo funcionaba mientras un gasto fuera siempre salida, y deja de
     * funcionar con los ajustes de saldo: se imputan a una categoría de gasto en
     * los DOS sentidos, y cuando el saldo real era mayor el monto es negativo.
     * Con la regla vieja, encontrar plata se mostraba en rojo y con un menos
     * adelante, diciendo lo contrario de lo que pasó.
     *
     * El convenio de signos (modelo-de-datos.md §1) ya lo decía: la línea de la
     * categoría es el espejo de la de la cuenta. Negativa acá es positiva allá.
     */
    const entra = cat ? Number(cat.amount) < 0 : false;

    return {
      id,
      fecha: cab.occurred_on,
      titulo: cat
        ? (cat.category_name ?? '—')
        : `${neg?.account_name ?? '—'} → ${pos?.account_name ?? '—'}`,
      grupo: cat ? (cat.category_parent ?? cat.category_name ?? null) : null,
      cuenta: cat ? (refDe(neg) ?? refDe(pos)) : null,
      desde: cat ? null : refDe(neg),
      hacia: cat ? null : refDe(pos),
      nota: cab.description,
      // El valor absoluto es la clave del arreglo: en pantalla el signo se
      // dibuja aparte, así que el número no puede traerlo adentro.
      monto: Math.abs(Number(cat ? cat.amount : (neg?.amount ?? 0))),
      unit: cat?.unit ?? neg?.unit ?? 'ARS',
      signo: !cat ? '' : entra ? '+' : '−',
      // el color ES el mensaje: rojo sale, verde entra, neutro no toca el resultado
      clase: !cat ? 'neutro' : entra ? 'pos' : 'neg',
      afectaResultado: !!cat,
      entra,
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
    if (f.entra) ingresos += f.monto;
    else gastos += f.monto;
  }
  return { ingresos, gastos };
}

// ---------------------------------------------------------------------------
// El resumen del mes.
//
// Vivía en `api.ts`, que importa Supabase, así que no se podía probar: `node
// --test` no resuelve los alias de Vite. Se mudó acá —puro— el día que hubo que
// contar las compras en cuotas, porque ese cálculo cuenta POR MOVIMIENTO y no
// por línea, y equivocarse ahí duplica en silencio.
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
  /**
   * Como se llama la categoria de ajuste EN ESTE libro.
   *
   * Inicio tenia la palabra "Ajustes" escrita a mano, y eso era dos mentiras en
   * una: se puede renombrar la categoria y el rotulo no se enteraba, y ademas
   * "Ajustes" en cualquier app en español significa Configuracion.
   */
  adjustmentsName: string | null;
  /**
   * Cuánto de los gastos del mes vino de compras en cuotas, y cuánto de eso cae
   * por mes — OD-24.
   *
   * El resultado se lleva el TOTAL el día de la compra. Es honesto: ese día tu
   * patrimonio bajó todo. Pero rompe la comparación mes contra mes, que es el
   * corazón de la app. La salida NO es mostrar un segundo resultado "como se
   * paga": serían dos verdades sin decir cuál mirar, y se le cree a la más
   * amable. Es explicar el único que hay.
   */
  cuotas: { total: number; porMes: number; compras: number };
  result: number;
  savingRate: number | null;
  byCategory: { name: string; parent: string | null; total: number }[];
}

export function summarize(entries: EntryDetail[], unit = 'ARS'): MonthSummary {
  let income = 0;
  let expense = 0;
  let adjustments = 0;
  let adjustmentsName: string | null = null;
  let cuotasTotal = 0;
  let cuotasPorMes = 0;
  const cuotasVistas = new Set<string>();
  const byCategory = new Map<string, { name: string; parent: string | null; total: number }>();

  for (const e of entries) {
    if (!e.category_id || e.unit !== unit) continue;
    const amount = Number(e.amount);

    // convenio de signos: ingreso negativo, gasto positivo
    if (e.category_kind === 'income') {
      income += -amount;
      continue;
    }

    // Por ROL y no por is_system: desde ADR-032 hay cuatro categorías de sistema,
    // y un «Aporte a otro libro» es un gasto de verdad. Con la regla vieja se
    // habría contado como ajuste de saldo y desaparecido de «En qué se fue».
    if (e.category_role === 'ajuste') {
      adjustments += amount;   // resta del resultado, pero no es un gasto
      adjustmentsName ??= e.category_name ?? null;
      continue;
    }

    expense += amount;

    // Se cuenta por MOVIMIENTO, no por línea: una compra puede tener varias.
    if (e.installments && e.installments >= 2 && !cuotasVistas.has(e.transaction_id)) {
      cuotasVistas.add(e.transaction_id);
      cuotasTotal += amount;
      cuotasPorMes += amount / e.installments;
    }

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
    adjustmentsName,
    cuotas: { total: cuotasTotal, porMes: cuotasPorMes, compras: cuotasVistas.size },
    result,
    savingRate: income > 0 ? result / income : null,
    byCategory: [...byCategory.values()].sort((a, b) => b.total - a.total)
  };
}

