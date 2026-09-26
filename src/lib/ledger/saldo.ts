/**
 * ¿Este movimiento deja la cuenta en rojo? — OD-55.
 *
 * El usuario preguntó si no habría que **impedirlo**. La respuesta es que no, y
 * el modelo ya muestra por qué: vender más unidades de las que tenés SÍ se
 * bloquea (`No tenes tantas unidades`), porque **las unidades se cuentan**. La
 * plata se ESTIMA — es la razón de ser de ADR-005 y de la categoría *Ajuste de
 * saldo*—, así que bloquear haría que la aplicación se niegue a registrar algo
 * que ya pasó. Y rompe cargar en desorden, que es lo normal cuando ponés al día
 * tres días de gastos y el sueldo lo cargás último.
 *
 * Un movimiento faltante es peor que un saldo negativo, porque el negativo al
 * menos se ve. Esto es lo que lo hace verse.
 *
 * Mismo criterio que `plausibilidad.ts`: avisa, no impide. Y PURO por la misma
 * razón, para que `node --test` pueda correrlo.
 */

export interface AvisoSaldo {
  /** Cuánto quedaría en la cuenta después del movimiento. Siempre negativo. */
  queda: number;
  /** Si ya estaba en rojo antes: el movimiento no es el que la hundió. */
  yaEstaba: boolean;
}

/**
 * Devuelve el aviso, o null cuando no hay nada que avisar.
 *
 * No se avisa de una TARJETA: su saldo es deuda, y que crezca es lo que hace una
 * tarjeta (ADR-004). El límite no está en el modelo, así que no hay ningún cero
 * que cruzar. Tampoco de un plazo fijo ni de una posición: no se gasta de ahí.
 */
export function avisoDeSaldo(
  cuenta: { kind: string; valuation: string } | null | undefined,
  saldo: number | null | undefined,
  monto: number
): AvisoSaldo | null {
  if (!cuenta || cuenta.kind !== 'asset' || cuenta.valuation !== 'balance') return null;
  // Sin saldo conocido no se inventa: se calla. Brief §20.
  if (saldo === null || saldo === undefined) return null;
  if (!(monto > 0)) return null;

  const queda = saldo - monto;
  if (queda >= 0) return null;
  return { queda, yaEstaba: saldo < 0 };
}
