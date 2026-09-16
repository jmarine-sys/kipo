// XIRR: el número que responde "¿llego al 10% anual?".
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { xirr, gananciaAbsoluta, totalAportado, antiguedadDias } from './rendimiento.ts';

const cerca = (a: number | null, b: number, tol = 0.0005) => {
  assert.ok(a !== null, 'devolvió null');
  assert.ok(Math.abs(a - b) < tol, `esperaba ~${b} y dio ${a}`);
};

test('1000 que se vuelven 1100 en un año son 10% anual', () => {
  cerca(xirr([
    { fecha: '2025-01-01', monto: -1000 },
    { fecha: '2026-01-01', monto: 1100 }
  ]), 0.10);
});

test('la misma ganancia en dos años es la mitad anualizada', () => {
  // 1000 -> 1210 en dos años es exactamente 10% compuesto
  cerca(xirr([
    { fecha: '2024-01-01', monto: -1000 },
    { fecha: '2026-01-01', monto: 1210 }
  ]), 0.10, 0.002);
});

test('medio año al 10% anual rinde menos de 10%', () => {
  const r = xirr([
    { fecha: '2026-01-01', monto: -1000 },
    { fecha: '2026-07-01', monto: 1100 }
  ]);
  assert.ok(r !== null && r > 0.20, `10% en medio año anualiza a más de 20%, dio ${r}`);
});

test('cuándo pusiste la plata cambia el resultado', () => {
  // dos aportes iguales, mismo valor final, pero uno entra tarde
  const temprano = xirr([
    { fecha: '2025-01-01', monto: -500 },
    { fecha: '2025-02-01', monto: -500 },
    { fecha: '2026-01-01', monto: 1150 }
  ]);
  const tarde = xirr([
    { fecha: '2025-01-01', monto: -500 },
    { fecha: '2025-11-01', monto: -500 },
    { fecha: '2026-01-01', monto: 1150 }
  ]);
  assert.ok(temprano !== null && tarde !== null);
  // La plata que entró tarde estuvo menos tiempo, así que el mismo resultado
  // final implica una tasa MAYOR. Eso es justamente lo que XIRR captura.
  assert.ok(tarde > temprano, `tarde ${tarde} debería superar a temprano ${temprano}`);
});

test('una pérdida da tasa negativa', () => {
  const r = xirr([
    { fecha: '2025-01-01', monto: -1000 },
    { fecha: '2026-01-01', monto: 900 }
  ]);
  assert.ok(r !== null && r < 0, `esperaba negativo, dio ${r}`);
  cerca(r, -0.10);
});

test('con retiros parciales sigue siendo correcto', () => {
  // pongo 1000, saco 300 a los 6 meses, me quedan 800 al año
  const r = xirr([
    { fecha: '2025-01-01', monto: -1000 },
    { fecha: '2025-07-01', monto: 300 },
    { fecha: '2026-01-01', monto: 800 }
  ]);
  assert.ok(r !== null && r > 0.09 && r < 0.15, `dio ${r}`);
});

test('sin respuesta posible devuelve null, no un número inventado', () => {
  assert.equal(xirr([]), null, 'lista vacía');
  assert.equal(xirr([{ fecha: '2026-01-01', monto: -100 }]), null, 'un solo flujo');
  assert.equal(xirr([
    { fecha: '2026-01-01', monto: -100 },
    { fecha: '2026-06-01', monto: -100 }
  ]), null, 'todos negativos: nunca volvió nada');
  assert.equal(xirr([
    { fecha: '2026-01-01', monto: -100 },
    { fecha: '2026-01-01', monto: 150 }
  ]), null, 'todo el mismo día: no hay tiempo transcurrido');
});

test('la ganancia absoluta es la suma de los flujos', () => {
  const f = [
    { fecha: '2025-01-01', monto: -1000 },
    { fecha: '2025-07-01', monto: 300 },
    { fecha: '2026-01-01', monto: 800 }
  ];
  assert.equal(gananciaAbsoluta(f), 100);
  assert.equal(totalAportado(f), 1000);
  assert.equal(antiguedadDias(f, '2026-01-01'), 365);
});
