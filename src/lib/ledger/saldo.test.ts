import { test } from 'node:test';
import assert from 'node:assert/strict';
import { avisoDeSaldo } from './saldo.ts';

const caja = { kind: 'asset', valuation: 'balance' };

test('un gasto que entra en el saldo no avisa nada', () => {
  assert.equal(avisoDeSaldo(caja, 10000, 3000), null);
});

test('gastar mas de lo que hay avisa cuanto queda', () => {
  assert.deepEqual(avisoDeSaldo(caja, 10000, 12500), { queda: -2500, yaEstaba: false });
});

test('gastar justo lo que hay NO avisa: cero no es rojo', () => {
  assert.equal(avisoDeSaldo(caja, 10000, 10000), null);
});

test('si ya estaba en rojo lo dice: este movimiento no es el que la hundio', () => {
  assert.deepEqual(avisoDeSaldo(caja, -500, 100), { queda: -600, yaEstaba: true });
});

// Una tarjeta no tiene un cero que cruzar: su saldo ES deuda y que crezca es lo
// que hace una tarjeta (ADR-004). El limite no esta en el modelo.
test('una tarjeta nunca avisa', () => {
  assert.equal(avisoDeSaldo({ kind: 'liability', valuation: 'balance' }, 0, 50000), null);
});

test('un plazo fijo y una posicion tampoco: no se gasta de ahi', () => {
  assert.equal(avisoDeSaldo({ kind: 'asset', valuation: 'accrual' }, 0, 1000), null);
  assert.equal(avisoDeSaldo({ kind: 'asset', valuation: 'market' }, 0, 1000), null);
});

test('sin saldo conocido se calla en vez de inventar', () => {
  assert.equal(avisoDeSaldo(caja, null, 1000), null);
  assert.equal(avisoDeSaldo(caja, undefined, 1000), null);
});

test('sin monto todavia no hay nada que avisar', () => {
  assert.equal(avisoDeSaldo(caja, 100, 0), null);
  assert.equal(avisoDeSaldo(caja, 100, NaN), null);
});

test('sin cuenta elegida tampoco', () => {
  assert.equal(avisoDeSaldo(null, 100, 1000), null);
});
