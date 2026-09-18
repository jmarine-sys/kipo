// ¿Es razonable este tipo de cambio? — OD-21.
//
// La base NO puede validarlo: ADR-010 dice que el tipo de cambio de una
// operación es el cociente de sus montos, y cualquier cociente es aritméticamente
// válido. Escribir 15.500 donde iban 1.550 produce un movimiento perfectamente
// legal y arruina todas las mediciones en dólares sin que nada se queje.
//
// Este módulo es PURO a propósito: no importa Supabase ni nada de $lib, para que
// `node --test` pueda correrlo. La misma razón que en cartera.ts.
//
// LO QUE NO HACE, y es deliberado: no bloquea. Un tipo de cambio raro puede ser
// real -un arreglo entre conocidos, una operación vieja- y el usuario es quien
// sabe. Pide confirmación, que es otra cosa.

export interface Cotizacion {
  base: string;
  quote: string;
  rate: number;
  source: string;
}

export type Veredicto =
  | { estado: 'ok' }
  | { estado: 'sin-referencia' }
  | { estado: 'sospechoso'; veces: number; min: number; max: number };

/**
 * Las cotizaciones conocidas, expresadas como "unidades de DESDE por una de HACIA".
 *
 * Una fila dice base/quote en un sentido y la operación puede ir en el otro:
 * comprar dólares con pesos y vender dólares por pesos usan la misma cotización
 * dada vuelta. Sin invertir, la mitad de las operaciones no tendría referencia.
 */
function referencias(desde: string, hacia: string, cotizaciones: Cotizacion[]): number[] {
  const out: number[] = [];
  for (const c of cotizaciones) {
    if (!c.rate) continue;
    if (c.base === hacia && c.quote === desde) out.push(c.rate);
    else if (c.base === desde && c.quote === hacia) out.push(1 / c.rate);
  }
  return out;
}

/**
 * @param implicito  cuántas unidades de `desde` cuesta una de `hacia`
 * @param margen     cuánto puede apartarse de la banda conocida sin llamar la
 *                   atención. 0.35 no es un número mágico: la banda real de un
 *                   día va del oficial al CCL —unos siete puntos— y ensancharla
 *                   un tercio deja pasar cualquier operación plausible, incluido
 *                   un arreglo por fuera del mercado, y sigue atrapando un error
 *                   de orden de magnitud, que es lo que se busca. Un aviso que
 *                   salta seguido es un aviso que se aprende a ignorar.
 */
export function plausibilidad(
  implicito: number,
  desde: string,
  hacia: string,
  cotizaciones: Cotizacion[],
  margen = 0.35
): Veredicto {
  if (!Number.isFinite(implicito) || implicito <= 0) return { estado: 'ok' };
  if (desde === hacia) return { estado: 'ok' };

  const refs = referencias(desde, hacia, cotizaciones);
  if (!refs.length) return { estado: 'sin-referencia' };

  const min = Math.min(...refs) * (1 - margen);
  const max = Math.max(...refs) * (1 + margen);
  if (implicito >= min && implicito <= max) return { estado: 'ok' };

  // Cuánto se aparta, en veces. Es lo que hace legible el aviso: "está 10 veces
  // por encima" se entiende de un vistazo; "fuera del rango esperado" no dice
  // si te comiste un cero o si el mercado se movió.
  const centro = (Math.min(...refs) + Math.max(...refs)) / 2;
  return {
    estado: 'sospechoso',
    veces: implicito / centro,
    min: Math.min(...refs),
    max: Math.max(...refs)
  };
}
