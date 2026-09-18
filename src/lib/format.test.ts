// Los ayudantes que estaban copiados en varias pantallas.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { num, finDeMes, esDeEsteMes } from './format.ts';

test('el punto es separador de miles y la coma el decimal', () => {
  assert.equal(num('1.250,50'), 1250.5);
  assert.equal(num('1250'), 1250);
  assert.equal(num(''), 0);
  assert.equal(num('no es un número'), 0);
});

test('fin de mes da el último día, sin importar cuántos tenga', () => {
  assert.equal(finDeMes(new Date(2026, 1, 10)), '2026-02-28');   // febrero
  assert.equal(finDeMes(new Date(2028, 1, 10)), '2028-02-29');   // bisiesto
  assert.equal(finDeMes(new Date(2026, 3, 10)), '2026-04-30');
  assert.equal(finDeMes(new Date(2026, 0, 10)), '2026-01-31');
});

test('«este mes» incluye el último día y excluye el primero del siguiente', () => {
  const hoy = new Date(2026, 8, 18);   // septiembre
  assert.equal(esDeEsteMes('2026-09-30', hoy), true);
  assert.equal(esDeEsteMes('2026-10-01', hoy), false);
  // Lo de antes también entra: algo atrasado sigue siendo cosa de ahora.
  assert.equal(esDeEsteMes('2026-08-01', hoy), true);
});
