/**
 * Qué se cotiza solo y qué hay que cargar a mano — UNA definición, dos lectores.
 *
 * La regla vivía escrita dos veces: en `scripts/precios.mjs`, que es quien de
 * verdad trae los precios, y en la pantalla de inversiones, que le dice al
 * usuario si esa posición va a cotizar sola. **Ya se habían separado**: el script
 * cotiza bonos en pesos —`arg_bonds` en data912, `public-bonds` en BYMA— y la
 * pantalla los marcaba «a mano». Un bono cargado hoy dice que nadie lo va a
 * cotizar y al día siguiente aparece con precio.
 *
 * El comentario que estaba al lado de la copia decía exactamente esto: «tiene que
 * decir lo MISMO que scripts/precios.mjs; si las dos reglas se separan, la
 * pantalla miente». Se separaron igual, que es lo que pasa siempre con una regla
 * escrita dos veces. Así que ahora hay una sola y la importan los dos.
 *
 * ESTE MÓDULO NO IMPORTA NADA. Es la condición para que `scripts/precios.mjs`
 * —un script de node, sin los alias de Vite— pueda leerlo, y también la que lo
 * hace testeable con `node --test`.
 */

/**
 * Las combinaciones de tipo y moneda que tienen fuente automática.
 *
 * No es una lista de deseos: cada línea corresponde a un endpoint que
 * `scripts/precios.mjs` consulta de verdad.
 */
export const FUENTES_PRECIO = [
  {
    id: 'byma' as const,
    /** data912 (`arg_cedears`, `arg_stocks`, `arg_bonds`, `arg_corp`) y BYMA de respaldo. */
    kinds: ['cedear', 'stock', 'etf', 'bond'] as const,
    monedas: ['ARS'] as const,
    /**
     * Se le pide por el símbolo de la acción del exterior cuando lo hay: un
     * CEDEAR sin ese dato no se puede buscar en ninguna fuente (ADR-025).
     */
    necesitaSubyacente: true
  },
  {
    id: 'binance' as const,
    /** Binance, contra USDT. */
    kinds: ['crypto'] as const,
    monedas: ['USD', 'USDT'] as const,
    necesitaSubyacente: false
  }
];

/** Si un instrumento así va a recibir precio sin que nadie lo cargue. */
export function cotizaSola(p: {
  kind: string;
  quote_currency: string;
  symbol?: string | null;
  underlying_symbol?: string | null;
}): boolean {
  const f = FUENTES_PRECIO.find(
    (x) => (x.kinds as readonly string[]).includes(p.kind) &&
           (x.monedas as readonly string[]).includes(p.quote_currency)
  );
  if (!f) return false;
  return f.necesitaSubyacente ? !!(p.underlying_symbol ?? p.symbol) : true;
}

/** Por qué no cotiza sola, dicho para quien lo lee en pantalla. */
export function porQueNoCotiza(p: {
  kind: string;
  quote_currency: string;
  symbol?: string | null;
  underlying_symbol?: string | null;
}): string | null {
  if (cotizaSola(p)) return null;
  const hayFuente = FUENTES_PRECIO.some(
    (x) => (x.kinds as readonly string[]).includes(p.kind) &&
           (x.monedas as readonly string[]).includes(p.quote_currency)
  );
  return hayFuente
    ? 'Le falta el símbolo con el que se le pide el precio a la fuente.'
    : `No hay fuente automática para ${p.kind} en ${p.quote_currency}.`;
}

/**
 * Qué fuente le corresponde a un instrumento, o null si ninguna.
 *
 * `scripts/precios.mjs` reparte los pedidos con esto, así que la pantalla y el
 * script no pueden discrepar sobre quién cotiza qué: es la misma función.
 */
export function fuenteDe(p: { kind: string; moneda: string }): 'byma' | 'binance' | null {
  const f = FUENTES_PRECIO.find(
    (x) => (x.kinds as readonly string[]).includes(p.kind) &&
           (x.monedas as readonly string[]).includes(p.moneda)
  );
  return f?.id ?? null;
}
