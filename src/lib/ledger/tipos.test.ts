// Cómo se nombra una cuenta: la parte que se puede probar sin pantalla.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { nombresRepetidos, esAmbigua, tipoDeCuenta } from './tipos.ts';

test('un nombre único no necesita que se aclare el banco', () => {
  const cuentas = [{ name: 'Efectivo' }, { name: 'Caja de ahorro' }];
  const rep = nombresRepetidos(cuentas);
  assert.equal(esAmbigua(cuentas[0], rep), false);
});

test('dos cuentas con el mismo nombre sí lo necesitan', () => {
  const cuentas = [{ name: 'Caja de ahorro' }, { name: 'Caja de ahorro' }];
  const rep = nombresRepetidos(cuentas);
  assert.equal(esAmbigua(cuentas[0], rep), true);
});

test('se comparan sin mayúsculas ni espacios de más: quien lee ve lo mismo', () => {
  const cuentas = [{ name: 'Caja de Ahorro' }, { name: 'caja de ahorro ' }];
  assert.equal(nombresRepetidos(cuentas).size, 1);
});

test('el tipo sale de lo que la cuenta ES, no de su nombre', () => {
  assert.equal(tipoDeCuenta({ kind: 'asset', valuation: 'balance', is_spendable: true }),
               'Caja de ahorro o efectivo');
  assert.equal(tipoDeCuenta({ kind: 'asset', valuation: 'balance', is_spendable: false }),
               'Cuenta de inversión');
  assert.equal(tipoDeCuenta({ kind: 'liability', valuation: 'balance', is_spendable: false }),
               'Tarjeta de crédito');
  assert.equal(tipoDeCuenta({ kind: 'asset', valuation: 'market', is_spendable: false }),
               'Posición');
});
