/**
 * Qué tipo de cuenta estás creando — y qué NO es un tipo.
 *
 * El formulario preguntaba «¿Tengo plata acá o debo plata acá?», que es UN eje de
 * los tres que el modelo tiene, y derivaba el resto:
 *
 *     const spendable = $derived(kind === 'asset');
 *
 * Con eso, **toda cuenta de activo creada a mano quedaba como plata disponible**,
 * así que no había forma de cargar una cuenta comitente: el efectivo parado en un
 * broker aparecía en «Disponible» junto a la caja de ahorro, siendo justamente la
 * plata que no podés gastar mañana.
 *
 * Y la puesta en marcha ofrecía «Banco», «Mercado Pago», «Billetera virtual».
 * Eso no son tipos: son el NOMBRE y el DÓNDE. Mercado Pago es una institución; una
 * caja de ahorro sigue siendo una caja de ahorro esté en el banco que esté.
 *
 * Son tres preguntas distintas y ahora se hacen por separado:
 *   qué tipo es  ·  cómo la llamás  ·  dónde está
 *
 * Acá viven solo los tres tipos que se cargan con el formulario general. Los otros
 * dos del modelo tienen pantalla propia porque piden datos que ninguno de estos
 * necesita: el plazo fijo su vencimiento (`/cuentas/plazo-fijo`) y la posición su
 * instrumento y su precio (`/inversiones`).
 */
export interface TipoDeCuenta {
  id: 'vista' | 'comitente' | 'tarjeta';
  label: string;
  pista: string;
  /** Ejemplo de nombre, para que se vea que el nombre es libre. */
  ejemplo: string;
  kind: 'asset' | 'liability';
  /** Si su saldo entra en «Disponible». Es LA diferencia entre vista y comitente. */
  spendable: boolean;
  /** Si tiene sentido preguntarle en qué moneda. Una tarjeta también, pero casi siempre es ARS. */
  monedas: string[];
}

export const TIPOS_CUENTA: TipoDeCuenta[] = [
  {
    id: 'vista',
    label: 'Caja de ahorro o efectivo',
    pista: 'plata que podés usar hoy',
    ejemplo: 'Caja de ahorro Macro',
    kind: 'asset',
    spendable: true,
    monedas: ['ARS', 'USD']
  },
  {
    id: 'comitente',
    label: 'Cuenta de inversión',
    pista: 'el efectivo que tenés en un broker, esperando para invertir',
    ejemplo: 'Balanz pesos',
    kind: 'asset',
    spendable: false,
    monedas: ['ARS', 'USD', 'USDT']
  },
  {
    id: 'tarjeta',
    label: 'Tarjeta de crédito',
    pista: 'gastás ahora y pagás después: su saldo es deuda',
    ejemplo: 'Visa Galicia',
    kind: 'liability',
    spendable: false,
    monedas: ['ARS', 'USD']
  }
];

export const tipoPorId = (id: string): TipoDeCuenta =>
  TIPOS_CUENTA.find((t) => t.id === id) ?? TIPOS_CUENTA[0];

/**
 * De qué tipo es una cuenta que ya existe.
 *
 * Se deduce de lo que ES, nunca del nombre: renombrar una cuenta no puede
 * cambiar cómo se la trata. Mismo criterio que la categoría de ajustes.
 */
export function tipoDeCuenta(a: { kind: string; valuation: string; is_spendable: boolean }): string {
  if (a.valuation === 'accrual') return 'Plazo fijo';
  if (a.valuation === 'market') return 'Posición';
  if (a.kind === 'liability') return 'Tarjeta de crédito';
  return a.is_spendable ? 'Caja de ahorro o efectivo' : 'Cuenta de inversión';
}

/**
 * Los nombres de cuenta que se repiten dentro de una lista.
 *
 * Sirve para decidir cuándo hace falta mostrar el banco: una «Caja de ahorro»
 * sola no necesita aclaración, dos sí. Se compara sin distinguir mayúsculas ni
 * espacios de más, porque «Caja de ahorro» y «caja de ahorro » son la misma para
 * quien las lee.
 */
export function nombresRepetidos(cuentas: { name: string }[]): Set<string> {
  const vistos = new Map<string, number>();
  for (const c of cuentas) {
    const k = c.name.trim().toLowerCase();
    vistos.set(k, (vistos.get(k) ?? 0) + 1);
  }
  return new Set([...vistos].filter(([, n]) => n > 1).map(([k]) => k));
}

/** Si esta cuenta necesita que se aclare dónde está. */
export const esAmbigua = (c: { name: string }, repetidos: Set<string>) =>
  repetidos.has(c.name.trim().toLowerCase());
