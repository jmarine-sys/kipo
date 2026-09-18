// Prueba del convenio de signos en pantalla.   node --test src/lib/ledger/
//
// Existe por un error que llegó a producción: un ingreso se mostraba como
// "+-$2.000.000" y sumaba del lado de los gastos. El error era invisible al
// compilador —los tipos estaban bien— y solo se veía mirando la pantalla.
//
// docs/modelo-de-datos.md §1: en una categoría de INGRESO el monto es NEGATIVO.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { filasDeMovimientos, totales, summarize } from './presentacion.ts';
import type { EntryDetail } from './api.ts';

let n = 0;
function linea(p: Partial<EntryDetail>): EntryDetail {
  return {
    id: `e${n++}`, transaction_id: 't', amount: '0', unit: 'ARS',
    account_id: null, account_name: null, account_kind: null,
    category_id: null, category_name: null, category_kind: null,
    category_is_system: false, category_role: null, category_parent: null,
    occurred_on: '2026-09-05', description: null, tx_kind: 'expense',
    ...p
  } as EntryDetail;
}

const sueldo = [
  linea({ transaction_id: 'ing', account_id: 'a1', account_name: 'Banco', amount: '2000000' }),
  linea({ transaction_id: 'ing', category_id: 'c1', category_name: 'Sueldo',
          category_kind: 'income', category_parent: null, amount: '-2000000' })
];
const compra = [
  linea({ transaction_id: 'gas', account_id: 'a1', account_name: 'Banco', amount: '-25000' }),
  linea({ transaction_id: 'gas', category_id: 'c2', category_name: 'Supermercado',
          category_kind: 'expense', category_parent: 'Gastos variables', amount: '25000' })
];
const traspaso = [
  linea({ transaction_id: 'mov', account_id: 'a1', account_name: 'Banco', amount: '-300000' }),
  linea({ transaction_id: 'mov', account_id: 'a2', account_name: 'Ahorro', amount: '300000' })
];

test('un ingreso se muestra positivo, con un solo signo', () => {
  const [f] = filasDeMovimientos(sueldo);
  assert.equal(f.monto, 2000000, 'el monto tiene que ser POSITIVO');
  assert.equal(f.signo, '+');
  assert.equal(f.clase, 'pos');
  assert.ok(f.esIngreso);
  // la regresión exacta que se vio en pantalla
  assert.ok(!`${f.signo}${f.monto}`.includes('+-'), 'salía "+-" con los dos signos');
});

test('un gasto se muestra positivo, con el signo menos', () => {
  const [f] = filasDeMovimientos(compra);
  assert.equal(f.monto, 25000);
  assert.equal(f.signo, '−');
  assert.equal(f.clase, 'neg');
  assert.equal(f.madre, 'Gastos variables');
});

test('una transferencia no lleva signo ni toca el resultado', () => {
  const [f] = filasDeMovimientos(traspaso);
  assert.equal(f.signo, '');
  assert.equal(f.clase, 'neutro');
  assert.equal(f.afectaResultado, false);
  assert.equal(f.titulo, 'Banco → Ahorro');
});

test('los totales NO mezclan ingresos con gastos', () => {
  const filas = filasDeMovimientos([...sueldo, ...compra, ...traspaso]);
  const { ingresos, gastos } = totales(filas);
  assert.equal(ingresos, 2000000, 'el sueldo va a ingresos');
  assert.equal(gastos, 25000, 'y NO se suma a los gastos');
});

test('la transferencia no entra en ningún total', () => {
  const { ingresos, gastos } = totales(filasDeMovimientos(traspaso));
  assert.equal(ingresos, 0);
  assert.equal(gastos, 0);
});

// ---------------------------------------------------------------------------
// El resumen del mes, y sobre todo las cuotas — OD-24.
// ---------------------------------------------------------------------------
const fila = (o: Partial<EntryDetail> & { transaction_id: string }): EntryDetail => ({
  id: crypto.randomUUID(),
  ledger_id: 'l', amount: '0', unit: 'ARS',
  account_id: null, account_name: null, account_kind: null, account_valuation: null,
  account_institution: null,
  category_id: null, category_name: null, category_kind: null,
  category_is_system: false, category_role: null, category_parent: null,
  occurred_on: '2026-10-15', description: null, tx_kind: 'expense',
  installments: null, created_at: '2026-10-15T00:00:00Z',
  ...o
} as EntryDetail);

/** Una compra: dos líneas, una contra la cuenta y otra contra la categoría. */
const gasto = (tx: string, monto: number, cuotas: number | null = null) => [
  fila({ transaction_id: tx, amount: String(-monto), account_id: 'a', account_name: 'Visa',
          account_kind: 'liability', installments: cuotas }),
  fila({ transaction_id: tx, amount: String(monto), category_id: 'c', category_name: 'Compras',
          category_kind: 'expense', installments: cuotas })
];

test('una compra en cuotas se cuenta UNA vez, no una por línea', () => {
  const s = summarize(gasto('t1', 120000, 12));
  assert.equal(s.cuotas.compras, 1);
  assert.equal(s.cuotas.total, 120000);
  assert.equal(s.cuotas.porMes, 10000);
});

test('el resultado del mes se lleva el total, no la cuota', () => {
  // Es lo honesto: ese día el patrimonio bajó 120.000 enteros.
  const s = summarize(gasto('t1', 120000, 12));
  assert.equal(s.expense, 120000);
  assert.equal(s.result, -120000);
});

test('un gasto común no aparece como cuota', () => {
  const s = summarize(gasto('t1', 5000));
  assert.equal(s.cuotas.compras, 0);
  assert.equal(s.cuotas.total, 0);
});

test('dos compras en cuotas suman, cada una con su plazo', () => {
  const s = summarize([...gasto('t1', 120000, 12), ...gasto('t2', 60000, 6)]);
  assert.equal(s.cuotas.compras, 2);
  assert.equal(s.cuotas.total, 180000);
  assert.equal(s.cuotas.porMes, 20000);   // 10.000 + 10.000
});

test('una compra en una sola cuota no cuenta como cuotas', () => {
  const s = summarize(gasto('t1', 5000, 1));
  assert.equal(s.cuotas.compras, 0);
});

test('un aporte a otro libro es un GASTO, no un ajuste de saldo', () => {
  // ADR-032 agregó categorías de sistema nuevas. Con la regla vieja -«is_system
  // es un ajuste»- este gasto habría desaparecido de «En qué se fue» y aparecido
  // como deriva de saldo, que es una acusación distinta.
  const s = summarize([
    fila({ transaction_id: 't1', amount: '-50000', account_id: 'a', account_name: 'Caja' }),
    fila({ transaction_id: 't1', amount: '50000', category_id: 'c',
           category_name: 'Aporte a otro libro', category_kind: 'expense',
           category_is_system: true, category_role: 'aporte_enviado' })
  ]);
  assert.equal(s.expense, 50000);
  assert.equal(s.adjustments, 0);
  assert.equal(s.byCategory[0].name, 'Aporte a otro libro');
});

test('el ajuste de saldo sigue siendo un ajuste', () => {
  const s = summarize([
    fila({ transaction_id: 't2', amount: '-3000', account_id: 'a', account_name: 'Caja' }),
    fila({ transaction_id: 't2', amount: '3000', category_id: 'c',
           category_name: 'Ajuste de saldo', category_kind: 'expense',
           category_is_system: true, category_role: 'ajuste' })
  ]);
  assert.equal(s.adjustments, 3000);
  assert.equal(s.expense, 0);
});

// ---------------------------------------------------------------------------
// Ajustes de saldo: la dirección sale del SIGNO, no del tipo de categoría.
//
// Un ajuste se imputa a una categoría de GASTO en los dos sentidos. Si el saldo
// real era mayor, el monto de esa categoría es NEGATIVO: encontraste plata. Con
// la regla vieja -«categoría de gasto ⇒ salió»- eso se mostraba en rojo y con un
// menos adelante, diciendo lo contrario de lo que pasó.
// ---------------------------------------------------------------------------

const ajuste = (tx: string, delta: number) => [
  fila({ transaction_id: tx, amount: String(delta), account_id: 'a', account_name: 'Caja',
         tx_kind: 'adjustment' }),
  fila({ transaction_id: tx, amount: String(-delta), category_id: 'aj',
         category_name: 'Ajuste de saldo', category_kind: 'expense',
         category_is_system: true, category_role: 'ajuste', tx_kind: 'adjustment' })
];

test('un ajuste hacia ARRIBA se muestra como que entró plata', () => {
  const [f] = filasDeMovimientos(ajuste('t1', 5000));
  assert.equal(f.signo, '+');
  assert.equal(f.clase, 'pos');
  assert.equal(f.monto, 5000);
});

test('un ajuste hacia ABAJO se muestra como que salió', () => {
  const [f] = filasDeMovimientos(ajuste('t2', -3000));
  assert.equal(f.signo, '−');
  assert.equal(f.clase, 'neg');
  assert.equal(f.monto, 3000);
});

test('y los totales lo cuentan del lado correcto', () => {
  const t = totales([...filasDeMovimientos(ajuste('t1', 5000))]);
  assert.equal(t.ingresos, 5000);
  assert.equal(t.gastos, 0);
});
