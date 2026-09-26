import { supabase } from '$lib/supabase';

/**
 * Con qué dólar se está midiendo cada cosa.
 *
 * Aparte de `dolares.ts` porque ese módulo no importa nada —es la condición para
 * probarlo con `node --test`— y esto necesita el cliente de Supabase.
 */
export interface DolarEnUso {
  fuente: string;
  cuentas: number;
  /** Si alguna de esas cuentas lo hereda del libro en vez de elegirlo. */
  alguna_por_defecto: boolean;
}

export async function dolaresEnUso(): Promise<DolarEnUso[]> {
  const { data, error } = await supabase.from('dolar_en_uso').select('*').order('cuentas', { ascending: false });
  if (error) throw new Error(`No se pudo leer con qué dólar se mide: ${error.message}`);
  return (data ?? []) as DolarEnUso[];
}
