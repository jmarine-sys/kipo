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
