// Quien cotiza solo y quien no. La regla estaba escrita dos veces y ya habia
// derivado: el script cotizaba bonos en pesos y la pantalla los daba por
// manuales. Estas pruebas cubren el caso que se habia separado.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cotizaSola, porQueNoCotiza, fuenteDe } from './precios.ts';

test('un bono en pesos SI cotiza solo: es el caso que estaba mal', () => {
  assert.equal(cotizaSola({ kind: 'bond', quote_currency: 'ARS', symbol: 'AL30' }), true);
});

test('un CEDEAR necesita el simbolo de la accion que representa', () => {
  assert.equal(
    cotizaSola({ kind: 'cedear', quote_currency: 'ARS', symbol: 'AAPL', underlying_symbol: 'AAPL' }),
    true
  );
  assert.equal(
    cotizaSola({ kind: 'cedear', quote_currency: 'ARS', symbol: null, underlying_symbol: null }),
    false
  );
});

test('la cripto cotiza contra USDT y contra USD, no contra pesos', () => {
  assert.equal(cotizaSola({ kind: 'crypto', quote_currency: 'USDT', symbol: 'BTC' }), true);
  assert.equal(cotizaSola({ kind: 'crypto', quote_currency: 'USD', symbol: 'BTC' }), true);
  assert.equal(cotizaSola({ kind: 'crypto', quote_currency: 'ARS', symbol: 'BTC' }), false);
});

test('un bono en dolares no tiene fuente: la serie D no se pide en pesos', () => {
  assert.equal(cotizaSola({ kind: 'bond', quote_currency: 'USD', symbol: 'AL30D' }), false);
});

test('un fondo no cotiza solo en ninguna moneda', () => {
  assert.equal(cotizaSola({ kind: 'fund', quote_currency: 'ARS', symbol: 'FCI' }), false);
});

test('el motivo distingue "no hay fuente" de "le falta el simbolo"', () => {
  const sinSimbolo = porQueNoCotiza({ kind: 'cedear', quote_currency: 'ARS', symbol: null });
  const sinFuente = porQueNoCotiza({ kind: 'fund', quote_currency: 'ARS', symbol: 'FCI' });
  assert.match(sinSimbolo ?? '', /símbolo/);
  assert.match(sinFuente ?? '', /No hay fuente/);
  assert.equal(porQueNoCotiza({ kind: 'crypto', quote_currency: 'USDT', symbol: 'BTC' }), null);
});

// El reparto que hace scripts/precios.mjs sale de aca. Si esto cambia, cambia el
// script: es el mismo modulo, que es justo el punto.
test('cada instrumento va a la fuente que lo cotiza, o a ninguna', () => {
  assert.equal(fuenteDe({ kind: 'bond', moneda: 'ARS' }), 'byma');
  assert.equal(fuenteDe({ kind: 'cedear', moneda: 'ARS' }), 'byma');
  assert.equal(fuenteDe({ kind: 'crypto', moneda: 'USDT' }), 'binance');
  assert.equal(fuenteDe({ kind: 'crypto', moneda: 'ARS' }), null);
  assert.equal(fuenteDe({ kind: 'fund', moneda: 'ARS' }), null);
});
