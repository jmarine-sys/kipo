// Este modulo es PURO a proposito: no importa Supabase ni nada de $lib.
//
// No es purismo. `node --test` corre TypeScript directo pero no resuelve los
// alias de Vite, asi que un solo import de infraestructura deja todo el archivo
// sin poder testearse. La lectura de datos vive en `cartera.datos.ts`.
import { xirr, gananciaAbsoluta, totalAportado, antiguedadDias, type Flujo } from './rendimiento.ts';

export type Medida = 'USD' | 'UVA';

export interface FlujoInversion {
  account_id: string;
  valuation: 'market' | 'accrual';
  fecha: string;
  monto: string;
  unidad: string;
  usd: string | null;
  uva: string | null;
}

export interface ValorInversion {
  account_id: string;
  /** En cuántas carteras está. 0 = se mide por su cuenta (ADR-026 / OD-40). */
  carteras: number;
  name: string;
  valuation: 'market' | 'accrual';
  institution: string | null;
  matures_on: string | null;
  /** true si ya se vendió o venció. Vale cero pero sus flujos siguen contando. */
  cerrada: boolean;
  symbol: string | null;
  kind: string | null;
  quote_currency: string | null;
  saldo: string;
  valor_nativo: string | null;
  moneda: string | null;
  precio_al: string | null;
  usd: string | null;
  uva: string | null;
}

/** Un portafolio: el broker, con su efectivo y sus posiciones adentro. ADR-026. */
export interface ValorPortafolio {
  portfolio_id: string;
  name: string;
  fx_source: string | null;
  cerrado: boolean;
  cuentas: number;
  /** Cuántas cuentas de adentro no se pudieron valuar. Sin esto el total miente. */
  sin_valuar: number;
  usd: string | null;
  uva: string | null;
}

/** Solo lo que cruzó el borde del portafolio. Comprar adentro no aparece acá. */
export interface FlujoPortafolio {
  portfolio_id: string;
  fecha: string;
  unidad: string;
  monto: string;
  usd: string | null;
  uva: string | null;
}

export interface Faltante {
  fecha: string;
  sin_dolar: boolean;
  sin_uva: boolean;
  dolar_viejo: boolean;
  uva_viejo: boolean;
}

export interface Resultado {
  /** null cuando falta algún dato: la pantalla dice que no sabe */
  valor: number | null;
  invertido: number | null;
  ganancia: number | null;
  /** tasa anual, en tanto por uno. null si no se puede calcular */
  anual: number | null;
  dias: number;
  /** cuántas inversiones quedaron afuera del cálculo por falta de datos */
  incompletas: number;
}

const hoy = () => new Date().toISOString().slice(0, 10);

/**
 * El nucleo: aportes a lo largo del tiempo mas cuanto vale hoy, en una vara.
 *
 * Esta funcion no sabe si el borde es una posicion, un broker o tu patrimonio
 * entero: ADR-026 dice que son la misma cuenta con el borde corrido. Por eso hay
 * UNA sola implementacion y tres formas de alimentarla.
 */
function rendimiento(valor: number, aportes: Flujo[], incompletas: number): Resultado {
  const serie: Flujo[] = [...aportes, { fecha: hoy(), monto: valor }];
  return {
    valor,
    invertido: totalAportado(serie),
    ganancia: gananciaAbsoluta(serie),
    anual: xirr(serie),
    dias: antiguedadDias(serie, hoy()),
    incompletas
  };
}

const vacio = (incompletas: number): Resultado =>
  ({ valor: null, invertido: null, ganancia: null, anual: null, dias: 0, incompletas });

/**
 * El rendimiento de un conjunto de inversiones, en la vara elegida.
 *
 * Si a alguna le falta el precio o la cotización, queda AFUERA y se informa
 * cuántas: mezclar una posición sin valuar con las demás daría un total que
 * parece completo y no lo es.
 */
export function calcular(
  valores: ValorInversion[],
  flujos: FlujoInversion[],
  medida: Medida
): Resultado {
  const campo = medida === 'USD' ? 'usd' : 'uva';
  const usables = valores.filter((v) => v[campo] !== null);
  const incompletas = valores.length - usables.length;
  if (!usables.length) return vacio(incompletas);

  const ids = new Set(usables.map((v) => v.account_id));
  return rendimiento(
    usables.reduce((t, v) => t + Number(v[campo]), 0),
    flujos
      .filter((f) => ids.has(f.account_id) && f[campo] !== null)
      .map((f) => ({ fecha: f.fecha, monto: Number(f[campo]) })),
    incompletas
  );
}

/**
 * El rendimiento de un portafolio entero: sus posiciones MAS su efectivo, contra
 * lo unico que cruzo el borde.
 *
 * La diferencia con `calcular` no es de formula sino de que se le da de comer.
 * Acá comprar adentro no figura, porque `flujo_portafolio` ya no lo trae.
 */
export function calcularPortafolio(
  p: ValorPortafolio,
  flujos: FlujoPortafolio[],
  medida: Medida
): Resultado {
  const campo = medida === 'USD' ? 'usd' : 'uva';
  if (p[campo] === null) return vacio(p.sin_valuar || 1);
  return rendimiento(
    Number(p[campo]),
    flujos
      .filter((f) => f.portfolio_id === p.portfolio_id && f[campo] !== null)
      .map((f) => ({ fecha: f.fecha, monto: Number(f[campo]) })),
    p.sin_valuar
  );
}

/** Los tres grupos en que tiene sentido mirar una cartera. */
export const GRUPOS = [
  { id: 'cripto',  label: 'Cripto',       test: (v: ValorInversion) => v.kind === 'crypto' },
  { id: 'bursatil', label: 'Bursátil',    test: (v: ValorInversion) => v.valuation === 'market' && v.kind !== 'crypto' },
  { id: 'plazos',  label: 'Plazos fijos', test: (v: ValorInversion) => v.valuation === 'accrual' }
] as const;

/** Cuántas de estas inversiones ya se cerraron. */
export function cerradas(valores: ValorInversion[]): number {
  return valores.filter((v) => v.cerrada).length;
}


/**
 * El rendimiento de TODO, sin contar nada dos veces.
 *
 * Cada portafolio entra como una unidad —con su efectivo adentro y sin sus
 * movimientos internos— y las inversiones que no pertenecen a ninguno entran
 * por su cuenta. Sumar los dos conjuntos sin filtrar contaría las posiciones de
 * un broker dos veces: una dentro del portafolio y otra sueltas.
 */
export function calcularTodo(
  portafolios: ValorPortafolio[],
  valores: ValorInversion[],
  flujosP: FlujoPortafolio[],
  flujosI: FlujoInversion[],
  medida: Medida
): Resultado {
  const campo = medida === 'USD' ? 'usd' : 'uva';

  const sueltas = valores.filter((v) => !v.carteras);
  const usables = sueltas.filter((v) => v[campo] !== null);
  const carteras = portafolios.filter((p) => p[campo] !== null);

  const incompletas =
    sueltas.length - usables.length +
    portafolios.reduce((t, p) => t + (p[campo] === null ? Math.max(p.cuentas, 1) : p.sin_valuar), 0);

  if (!usables.length && !carteras.length) return vacio(incompletas);

  const ids = new Set(usables.map((v) => v.account_id));
  const pids = new Set(carteras.map((p) => p.portfolio_id));

  return rendimiento(
    usables.reduce((t, v) => t + Number(v[campo]), 0) +
      carteras.reduce((t, p) => t + Number(p[campo]), 0),
    [
      ...flujosI
        .filter((f) => ids.has(f.account_id) && f[campo] !== null)
        .map((f) => ({ fecha: f.fecha, monto: Number(f[campo]) })),
      ...flujosP
        .filter((f) => pids.has(f.portfolio_id) && f[campo] !== null)
        .map((f) => ({ fecha: f.fecha, monto: Number(f[campo]) }))
    ],
    incompletas
  );
}
