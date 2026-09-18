// El portafolio como borde, del lado del cliente — ADR-026.
//
// La trampa que estos tests cuidan: una posición que vive dentro de un broker
// aparece DOS veces en los datos —dentro del portafolio y en la lista de
// inversiones— y sumar las dos la contaría dos veces.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  calcularTodo, calcularPortafolio,
  type ValorInversion, type ValorPortafolio, type FlujoInversion, type FlujoPortafolio
} from './cartera.ts';

const hoy = new Date().toISOString().slice(0, 10);
const haceUnAnio = () => {
  const d = new Date();
  d.setUTCFullYear(d.getUTCFullYear() - 1);
  return d.toISOString().slice(0, 10);
};

const pf = (o: Partial<ValorPortafolio> = {}): ValorPortafolio => ({
  portfolio_id: 'p1', name: 'Binance', fx_source: 'cripto', cerrado: false,
  cuentas: 2, sin_valuar: 0, usd: '1100', uva: '500', ...o
});

const inv = (o: Partial<ValorInversion> = {}): ValorInversion => ({
  account_id: 'a1', carteras: 1, name: 'BTC', valuation: 'market',
  institution: 'Binance', matures_on: null, cerrada: false, symbol: 'BTC',
  kind: 'crypto', quote_currency: 'USD', saldo: '0.01', valor_nativo: '600',
  moneda: 'USD', precio_al: hoy, usd: '600', uva: '270', ...o
});

const fi = (o: Partial<FlujoInversion> = {}): FlujoInversion => ({
  account_id: 'a1', valuation: 'market', fecha: haceUnAnio(), monto: '-500',
  unidad: 'USD', usd: '-500', uva: '-220', ...o
});

const fp = (o: Partial<FlujoPortafolio> = {}): FlujoPortafolio => ({
  portfolio_id: 'p1', fecha: haceUnAnio(), unidad: 'USD', monto: '-1000',
  usd: '-1000', uva: '-450', ...o
});

test('una posición dentro de un portafolio no se cuenta dos veces', () => {
  // El broker vale 1100 y adentro tiene una posición de 600. Si el total
  // sumara las dos cosas daría 1700, que es plata que no existe.
  const r = calcularTodo([pf()], [inv()], [fp()], [fi()], 'USD');
  assert.equal(r.valor, 1100);
});

test('una inversión suelta sí se suma al total', () => {
  const suelta = inv({ account_id: 'a2', carteras: 0, usd: '300' });
  const r = calcularTodo([pf()], [inv(), suelta], [fp()], [fi()], 'USD');
  assert.equal(r.valor, 1400);
});

test('el aporte del portafolio reemplaza al de la posición de adentro', () => {
  // Entraron 1000 al broker y adentro se compraron 500 de BTC. El aporte es
  // 1000: los 500 son la misma plata cambiando de forma.
  const r = calcularTodo([pf()], [inv()], [fp()], [fi()], 'USD');
  assert.equal(r.invertido, 1000);
  assert.equal(r.ganancia, 100);
});

test('sin portafolios el total es el de siempre', () => {
  const suelta = inv({ carteras: 0 });
  const r = calcularTodo([], [suelta], [], [fi()], 'USD');
  assert.equal(r.valor, 600);
  assert.equal(r.invertido, 500);
});

test('un portafolio sin valuar no inventa un número: lo declara incompleto', () => {
  const r = calcularTodo([pf({ usd: null, cuentas: 3 })], [], [fp()], [], 'USD');
  assert.equal(r.valor, null);
  assert.equal(r.incompletas, 3);
});

test('las cuentas sin valuar de un portafolio se informan aunque el total exista', () => {
  const r = calcularPortafolio(pf({ sin_valuar: 2 }), [fp()], 'USD');
  assert.equal(r.valor, 1100);
  assert.equal(r.incompletas, 2);
});

test('1000 que se vuelven 1100 en un año son 10% anual, también por portafolio', () => {
  const r = calcularPortafolio(pf(), [fp()], 'USD');
  assert.ok(r.anual !== null && Math.abs(r.anual - 0.10) < 0.01, `dio ${r.anual}`);
});

test('la vara cambia el número, no la cuenta', () => {
  const r = calcularPortafolio(pf(), [fp()], 'UVA');
  assert.equal(r.valor, 500);
  assert.equal(r.invertido, 450);
});
