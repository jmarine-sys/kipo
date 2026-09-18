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

// ---------------------------------------------------------------------------
// El agrupamiento: una cuenta comitente NO es plata disponible.
// ---------------------------------------------------------------------------
import { GRUPOS_CUENTA } from './tipos.ts';

const grupoDe = (a: { kind: string; valuation: string; is_spendable: boolean }) =>
  GRUPOS_CUENTA.find((g) => g.test(a))?.titulo ?? 'ninguno';

test('la comitente sale de Disponible: su plata no está a mano', () => {
  assert.equal(grupoDe({ kind: 'asset', valuation: 'balance', is_spendable: false }), 'En el broker');
  assert.equal(grupoDe({ kind: 'asset', valuation: 'balance', is_spendable: true }), 'Disponible');
});

test('la tarjeta SÍ va con las cajas de ahorro: son las dos caras de lo mismo', () => {
  assert.equal(grupoDe({ kind: 'liability', valuation: 'balance', is_spendable: false }), 'Disponible');
});

test('los plazos fijos y las posiciones siguen aparte', () => {
  assert.equal(grupoDe({ kind: 'asset', valuation: 'accrual', is_spendable: false }), 'Inmovilizado');
  assert.equal(grupoDe({ kind: 'asset', valuation: 'market', is_spendable: false }), 'Invertido');
});

test('toda cuenta cae en exactamente un grupo', () => {
  const casos = [
    { kind: 'asset', valuation: 'balance', is_spendable: true },
    { kind: 'asset', valuation: 'balance', is_spendable: false },
    { kind: 'liability', valuation: 'balance', is_spendable: false },
    { kind: 'asset', valuation: 'accrual', is_spendable: false },
    { kind: 'asset', valuation: 'market', is_spendable: false }
  ];
  for (const c of casos) {
    assert.equal(GRUPOS_CUENTA.filter((g) => g.test(c)).length, 1,
                 `${JSON.stringify(c)} cae en más de un grupo o en ninguno`);
  }
});
