import { supabase } from '$lib/supabase';
import type {
  FlujoInversion, ValorInversion, Faltante, ValorPortafolio, FlujoPortafolio
} from './cartera';

function fallar(contexto: string, error: { message: string } | null): never {
  throw new Error(error?.message ? `${contexto}: ${error.message}` : contexto);
}

export async function cargarCartera() {
  const [f, v, x, vp, fp] = await Promise.all([
    supabase.from('flujo_inversion').select('*'),
    supabase.from('valor_inversion').select('*'),
    supabase.from('medicion_faltante').select('*'),
    supabase.from('valor_portafolio').select('*'),
    supabase.from('flujo_portafolio').select('*')
  ]);
  if (f.error) fallar('No se pudieron leer los flujos', f.error);
  if (v.error) fallar('No se pudieron leer las inversiones', v.error);
  return {
    flujos: (f.data ?? []) as FlujoInversion[],
    valores: (v.data ?? []) as ValorInversion[],
    faltantes: (x.data ?? []) as Faltante[],
    portafolios: (vp.data ?? []) as ValorPortafolio[],
    flujosPortafolio: (fp.data ?? []) as FlujoPortafolio[]
  };
}
