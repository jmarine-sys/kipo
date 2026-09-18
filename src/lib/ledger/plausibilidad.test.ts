// ¿Es razonable este tipo de cambio? — OD-21.
//
// Las cotizaciones reales del 2026-09-16, sacadas del respaldo de producción.
// Usar números inventados haría que los tests pasen y el aviso salte en la vida
// real, que es la forma más cara de tener tests verdes.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { plausibilidad, type Cotizacion } from './plausibilidad.ts';

const DIA: Cotizacion[] = [
  { base: 'USD', quote: 'ARS', rate: 1505, source: 'oficial' },
  { base: 'USD', quote: 'ARS', rate: 1550, source: 'blue' },
  { base: 'USD', quote: 'ARS', rate: 1531.95, source: 'mep' },
  { base: 'USD', quote: 'ARS', rate: 1593.95, source: 'ccl' },
  { base: 'USD', quote: 'ARS', rate: 1591.645, source: 'cripto' },
  { base: 'USD', quote: 'ARS', rate: 1502, source: 'mayorista' },
  { base: 'UVA', quote: 'ARS', rate: 2121.72, source: 'uva' }
];

test('comprar dólares al precio del día no molesta a nadie', () => {
  assert.equal(plausibilidad(1550, 'ARS', 'USD', DIA).estado, 'ok');
});

test('un cero de más se detecta', () => {
  const v = plausibilidad(15500, 'ARS', 'USD', DIA);
  assert.equal(v.estado, 'sospechoso');
  assert.ok(v.estado === 'sospechoso' && v.veces > 9, `dio ${v.estado === 'sospechoso' ? v.veces : '-'}`);
});

test('un cero de menos también', () => {
  assert.equal(plausibilidad(155, 'ARS', 'USD', DIA).estado, 'sospechoso');
});

test('vender dólares se compara con la misma cotización dada vuelta', () => {
  // 1 / 1550 dólares por peso. Sin invertir, esta operación no tendría referencia
  // y el aviso nunca saltaría en la mitad de los casos.
  assert.equal(plausibilidad(1 / 1550, 'USD', 'ARS', DIA).estado, 'ok');
  assert.equal(plausibilidad(1 / 155, 'USD', 'ARS', DIA).estado, 'sospechoso');
});

test('un arreglo por fuera del mercado pasa: el usuario sabe, el aviso no', () => {
  // Un 20% por encima del CCL es raro pero puede ser real. Que salte acá sería
  // enseñarle al usuario a ignorar el cartel.
  assert.equal(plausibilidad(1900, 'ARS', 'USD', DIA).estado, 'ok');
});

test('el doble del mercado sí llama la atención', () => {
  assert.equal(plausibilidad(3100, 'ARS', 'USD', DIA).estado, 'sospechoso');
});

test('sin cotización de ese par no se inventa un veredicto', () => {
  assert.equal(plausibilidad(0.92, 'EUR', 'USD', DIA).estado, 'sin-referencia');
});

test('el aviso dice cuántas veces se aparta, no solo que se aparta', () => {
  const v = plausibilidad(15500, 'ARS', 'USD', DIA);
  assert.ok(v.estado === 'sospechoso');
  if (v.estado === 'sospechoso') {
    assert.ok(v.min === 1502 && v.max === 1593.95, 'informa la banda real del día');
  }
});

test('un monto vacío o cero no dispara nada mientras tipeás', () => {
  assert.equal(plausibilidad(0, 'ARS', 'USD', DIA).estado, 'ok');
  assert.equal(plausibilidad(NaN, 'ARS', 'USD', DIA).estado, 'ok');
});

test('mover entre cuentas de la misma moneda no es un cambio', () => {
  assert.equal(plausibilidad(1, 'ARS', 'ARS', DIA).estado, 'ok');
});
