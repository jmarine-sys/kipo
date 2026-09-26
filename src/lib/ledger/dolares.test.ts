import { test } from 'node:test';
import assert from 'node:assert/strict';
import { FUENTES_DOLAR, etiquetaDolar, dolarSugerido } from './dolares.ts';

// La lista exacta, y no "contiene X": `fx_rate` admite ademas 'uva',
// 'mayorista' y 'manual', y ninguno de los tres es un dolar que se elija. La UVA
// es la OTRA vara de medicion, al mayorista no accede una persona fisica y
// 'manual' es de donde vino un dato, no una opcion. Esta prueba falla si alguno
// se cuela, que es como se colarian: ampliando el tipo para "que acepte todo".
test('la lista es exactamente los dolares que una persona puede conseguir', () => {
  assert.deepEqual(
    FUENTES_DOLAR.map((f) => f.id).sort(),
    ['blue', 'ccl', 'cripto', 'mep', 'oficial']
  );
});

test('cada fuente dice como se llega a ese dolar, no solo su nombre', () => {
  for (const f of FUENTES_DOLAR) assert.ok(f.pista.length > 10, f.id);
});

test('una cuenta que no esta en pesos no necesita sugerencia', () => {
  assert.equal(dolarSugerido('vista', 'USD'), null);
  assert.equal(dolarSugerido('comitente', 'USDT'), null);
});

test('los pesos parados en un broker se realizan al MEP', () => {
  assert.equal(dolarSugerido('comitente', 'ARS'), 'mep');
});

test('una caja de ahorro en pesos se queda con el del libro', () => {
  assert.equal(dolarSugerido('vista', 'ARS'), null);
});

test('etiquetaDolar no se rompe con algo que no conoce', () => {
  assert.equal(etiquetaDolar('mep'), 'MEP');
  assert.equal(etiquetaDolar(null), '');
  assert.equal(etiquetaDolar('loquesea'), 'LOQUESEA');
});
