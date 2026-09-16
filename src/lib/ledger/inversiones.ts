import { supabase } from '$lib/supabase';

/**
 * Plazos fijos — ADR-014.
 *
 * Son la familia 'accrual' de ADR-012: no cotizan, devengan. Su valor final se
 * conoce el día que se constituyen, así que no necesitan ninguna fuente de
 * precios: necesitan una fecha. Por eso reusan el motor de eventos futuros de
 * ADR-016, el mismo de los gastos recurrentes.
 */

function fallar(contexto: string, error: { message: string } | null): never {
  throw new Error(error?.message ? `${contexto}: ${error.message}` : contexto);
}

export interface NuevoPlazoFijo {
  nombre: string;
  /** de qué cuenta sale el capital */
  desdeId: string;
  capital: number;
  vence: string;
  /** cuánto vuelve al vencimiento, capital incluido */
  esperado: number;
  institucion?: string | null;
  fecha?: string | null;
}

/** Crea la cuenta, mueve la plata y agenda el vencimiento, todo junto. */
export async function crearPlazoFijo(p: NuevoPlazoFijo): Promise<string> {
  const { data, error } = await supabase.rpc('create_plazo_fijo', {
    p_nombre: p.nombre.trim(),
    p_desde: p.desdeId,
    p_capital: p.capital,
    p_vence: p.vence,
    p_esperado: p.esperado,
    p_institucion: p.institucion ?? null,
    p_on: p.fecha ?? null
  });
  if (error) fallar('No se pudo constituir el plazo fijo', error);
  return data as string;
}

/**
 * El capital vuelve y el interés se reconoce como ingreso.
 * El interés se CALCULA —lo que volvió menos lo que había—, no se pide: pedirlo
 * por separado abriría la puerta a que los dos números no coincidan.
 */
export async function registrarVencimiento(
  eventoId: string,
  opciones: { total?: number | null; haciaId?: string | null; fecha?: string | null } = {}
): Promise<string> {
  const { data, error } = await supabase.rpc('register_maturity', {
    p_event: eventoId,
    p_total: opciones.total ?? null,
    p_to: opciones.haciaId ?? null,
    p_on: opciones.fecha ?? null
  });
  if (error) fallar('No se pudo registrar el vencimiento', error);
  return data as string;
}

/** La tasa nominal anual que implican capital, monto final y plazo. */
export function tasaImplicita(capital: number, esperado: number, dias: number): number | null {
  if (!capital || !dias || esperado <= capital) return null;
  return ((esperado - capital) / capital) * (365 / dias) * 100;
}

/** Cuántos días hay entre dos fechas ISO. */
export function diasEntre(desde: string, hasta: string): number {
  const a = new Date(desde + 'T00:00:00');
  const b = new Date(hasta + 'T00:00:00');
  return Math.round((b.getTime() - a.getTime()) / 86400000);
}

// ---------------------------------------------------------------------------
// Posiciones de mercado — ADR-012, familia 'market'
// ---------------------------------------------------------------------------

export interface Posicion {
  account_id: string;
  name: string;
  institution: string | null;
  instrument_id: string;
  symbol: string;
  instrument_name: string;
  kind: string;
  quote_currency: string;
  decimals: number;
  unidades: string;
  /** null si nunca se cargó un precio: la app dice que no sabe, no muestra cero */
  precio: string | null;
  precio_al: string | null;
  precio_fuente: string | null;
  valor: string | null;
  invertido: string;
  ganancia: string | null;
}

export const TIPOS_ACTIVO = [
  { id: 'crypto', label: 'Cripto' },
  { id: 'cedear', label: 'CEDEAR' },
  { id: 'stock',  label: 'Acción' },
  { id: 'etf',    label: 'ETF' },
  { id: 'fund',   label: 'Fondo' },
  { id: 'bond',   label: 'Bono' },
  { id: 'other',  label: 'Otro' }
] as const;

export async function listPosiciones(): Promise<Posicion[]> {
  const { data, error } = await supabase.from('posicion').select('*').order('symbol');
  if (error) fallar('No se pudieron leer las inversiones', error);
  return data ?? [];
}

export interface Compra {
  symbol: string;
  nombre: string;
  kind: string;
  moneda: string;
  decimals: number;
  desdeId: string;
  monto: number;
  unidades: number;
  broker?: string | null;
  fecha?: string | null;
}

/** Crea el instrumento y la posición si es la primera compra. */
export async function comprarActivo(c: Compra): Promise<string> {
  const { data, error } = await supabase.rpc('comprar_activo', {
    p_symbol: c.symbol.trim().toUpperCase(),
    p_nombre: c.nombre.trim() || c.symbol.trim().toUpperCase(),
    p_kind: c.kind,
    p_moneda: c.moneda,
    p_decimals: c.decimals,
    p_desde: c.desdeId,
    p_monto: c.monto,
    p_unidades: c.unidades,
    p_broker: c.broker ?? null,
    p_on: c.fecha ?? null
  });
  if (error) fallar('No se pudo registrar la compra', error);
  return data as string;
}

export async function venderActivo(
  posId: string, unidades: number, haciaId: string, monto: number, fecha?: string | null
): Promise<string> {
  const { data, error } = await supabase.rpc('vender_activo', {
    p_pos: posId, p_unidades: unidades, p_hacia: haciaId, p_monto: monto,
    p_on: fecha ?? null
  });
  if (error) fallar('No se pudo registrar la venta', error);
  return data as string;
}

/**
 * Guarda el precio de un activo para una fecha.
 *
 * Hoy se carga a mano. La decisión de traerlos automáticamente ya está tomada
 * (OD-06) pero falta elegir la fuente (OD-30), y eso es investigación, no
 * código: bloquear la funcionalidad hasta resolverlo sería postergarla por algo
 * que no depende de esta pantalla.
 *
 * Cada precio guarda de DÓNDE salió, así que el día que lleguen automáticos
 * conviven sin ambigüedad.
 */
export async function guardarPrecio(
  instrumentId: string, precio: number, moneda: string, fecha: string
): Promise<void> {
  const { error } = await supabase
    .from('price')
    .upsert(
      { instrument_id: instrumentId, on_date: fecha, price: precio,
        currency: moneda, source: 'manual' },
      { onConflict: 'instrument_id,on_date,source' }
    );
  if (error) fallar('No se pudo guardar el precio', error);
}

/** Cuánto rindió, en porcentaje sobre lo invertido. */
export function rendimiento(invertido: number, ganancia: number): number | null {
  if (!invertido || invertido <= 0) return null;
  return (ganancia / invertido) * 100;
}
