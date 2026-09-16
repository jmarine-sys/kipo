// Prueba del convenio de signos en pantalla.   node --test src/lib/ledger/
//
// Existe por un error que llegó a producción: un ingreso se mostraba como
// "+-$2.000.000" y sumaba del lado de los gastos. El error era invisible al
// compilador —los tipos estaban bien— y solo se veía mirando la pantalla.
//
// docs/modelo-de-datos.md §1: en una categoría de INGRESO el monto es NEGATIVO.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { filasDeMovimientos, totales } from './presentacion.ts';
import type { EntryDetail } from './api.ts';

let n = 0;
function linea(p: Partial<EntryDetail>): EntryDetail {
  return {
    id: `e${n++}`, transaction_id: 't', amount: '0', unit: 'ARS',
    account_id: null, account_name: null, account_kind: null,
    category_id: null, category_name: null, category_kind: null,
    category_is_system: false, category_parent: null,
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
