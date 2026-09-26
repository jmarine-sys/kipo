/**
 * Qué dólar, y para qué sirve elegirlo — ADR-011, OD-59.
 *
 * La lista estaba escrita dentro del formulario de cuentas, como un array suelto
 * en el medio del marcado. Ahora hace falta en tres lugares —el alta de cuenta,
 * Ajustes y Cartera, que tiene que poder decir cuál usó— y una lista escrita
 * tres veces se separa, que es lo que pasó con `.chip` y con la regla de qué
 * cotiza solo.
 *
 * NO IMPORTA NADA: se prueba con `node --test` sin los alias de Vite.
 *
 * LO QUE ESTA LISTA NO ES: las unidades. Un dólar billete y un USDT son dos
 * cosas distintas que podés TENER —se transfieren por vías distintas y el USDT
 * se despega unas centésimas—, y por eso son unidades de cuenta separadas. El
 * «dólar MEP» en cambio no es algo que tengas: es el PRECIO al que convertís
 * pesos en dólares pasando por un bono. Terminada la operación, en tu cuenta hay
 * dólares a secas. Por eso esto se elige por cuenta y no aparece como moneda.
 */

export interface FuenteDolar {
  id: 'oficial' | 'mep' | 'blue' | 'ccl' | 'cripto';
  label: string;
  /** Cómo llegás a ese dólar. Es lo que hace elegible la elección. */
  pista: string;
}

export const FUENTES_DOLAR: FuenteDolar[] = [
  { id: 'mep', label: 'MEP', pista: 'comprando y vendiendo un bono en el broker' },
  { id: 'blue', label: 'Blue', pista: 'en la calle, en efectivo' },
  { id: 'ccl', label: 'CCL', pista: 'sacándolo afuera; es el que llevan adentro los CEDEARs' },
  { id: 'cripto', label: 'Cripto', pista: 'comprando stablecoins en un exchange' },
  { id: 'oficial', label: 'Oficial', pista: 'el del banco, con sus límites' }
];

export const etiquetaDolar = (id: string | null | undefined): string =>
  FUENTES_DOLAR.find((f) => f.id === id)?.label ?? (id ?? '').toUpperCase();

/**
 * Qué dólar sugerirle a una cuenta que se está creando.
 *
 * Es una SUGERENCIA, no una regla: se puede cambiar, y por eso no hizo falta
 * recuperar «efectivo» como tipo de cuenta. El tipo habla de cómo se valúa y de
 * si se puede gastar (ADR-012, ADR-030); un fajo de pesos y una caja de ahorro
 * son iguales en los dos ejes. En lo único que se distinguen es en qué dólar
 * conseguís con ellos, y eso es exactamente este campo.
 *
 * Devuelve null cuando no hay nada que sugerir: que quede el del libro.
 */
export function dolarSugerido(tipoId: string, unit: string): string | null {
  if (unit !== 'ARS') return null;
  // La plata parada en un broker se realiza al MEP sin salir de ahí.
  if (tipoId === 'comitente') return 'mep';
  return null;
}
