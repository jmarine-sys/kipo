import { supabase } from '$lib/supabase';
import { xirr, gananciaAbsoluta, totalAportado, antiguedadDias, type Flujo } from './rendimiento';

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
  name: string;
  valuation: 'market' | 'accrual';
  institution: string | null;
  matures_on: string | null;
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

export interface Faltante {
  fecha: string;
  sin_dolar: boolean;
  sin_uva: boolean;
  dolar_viejo: boolean;
  uva_viejo: boolean;
}

function fallar(contexto: string, error: { message: string } | null): never {
  throw new Error(error?.message ? `${contexto}: ${error.message}` : contexto);
}

export async function cargarCartera() {
  const [f, v, x] = await Promise.all([
    supabase.from('flujo_inversion').select('*'),
    supabase.from('valor_inversion').select('*'),
    supabase.from('medicion_faltante').select('*')
  ]);
  if (f.error) fallar('No se pudieron leer los flujos', f.error);
  if (v.error) fallar('No se pudieron leer las inversiones', v.error);
  return {
    flujos: (f.data ?? []) as FlujoInversion[],
    valores: (v.data ?? []) as ValorInversion[],
    faltantes: (x.data ?? []) as Faltante[]
  };
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
  if (!usables.length) {
    return { valor: null, invertido: null, ganancia: null, anual: null, dias: 0, incompletas };
  }

  const ids = new Set(usables.map((v) => v.account_id));
  const propios = flujos.filter((f) => ids.has(f.account_id) && f[campo] !== null);

  const serie: Flujo[] = propios.map((f) => ({ fecha: f.fecha, monto: Number(f[campo]) }));
  const valor = usables.reduce((t, v) => t + Number(v[campo]), 0);
  serie.push({ fecha: hoy(), monto: valor });

  return {
    valor,
    invertido: totalAportado(serie),
    ganancia: gananciaAbsoluta(serie),
    anual: xirr(serie),
    dias: antiguedadDias(serie, hoy()),
    incompletas
  };
}

/** Los tres grupos en que tiene sentido mirar una cartera. */
export const GRUPOS = [
  { id: 'cripto',  label: 'Cripto',       test: (v: ValorInversion) => v.kind === 'crypto' },
  { id: 'bursatil', label: 'Bursátil',    test: (v: ValorInversion) => v.valuation === 'market' && v.kind !== 'crypto' },
  { id: 'plazos',  label: 'Plazos fijos', test: (v: ValorInversion) => v.valuation === 'accrual' }
] as const;
