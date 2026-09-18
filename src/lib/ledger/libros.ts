import { supabase } from '$lib/supabase';

/**
 * Libros compartidos — ADR-028.
 *
 * ADR-003 dice que el libro no existe para la interfaz, y sigue valiendo: el
 * cliente nunca manda un `ledger_id` al guardar nada. Lo único que puede hacer
 * es decir "quiero mirar este otro", y el resto lo resuelve la base.
 */
export interface Libro {
  ledger_id: string;
  name: string;
  role: 'owner' | 'member';
  activo: boolean;
  miembros: number;
  joined_at: string;
}

function fallar(contexto: string, error: { message: string } | null): never {
  throw new Error(error?.message ? `${contexto}: ${error.message}` : contexto);
}

export async function misLibros(): Promise<Libro[]> {
  const { data, error } = await supabase.from('mi_libro').select('*').order('joined_at');
  if (error) fallar('No se pudieron leer tus libros', error);
  return (data ?? []) as Libro[];
}

/**
 * Cambia el libro activo.
 *
 * No hace falta tocar ninguna otra consulta: la política de RLS de todas las
 * tablas filtra por el libro activo, así que cambiarlo cambia la app entera —
 * incluidas las consultas que escribamos el año que viene.
 */
export async function cambiarLibro(ledgerId: string): Promise<void> {
  const { error } = await supabase.rpc('cambiar_libro', { p_ledger: ledgerId });
  if (error) fallar('No se pudo cambiar de libro', error);
}

/** Devuelve el código para pasarle a la otra persona. Solo el dueño puede. */
export async function crearInvitacion(role: 'member' | 'owner' = 'member'): Promise<string> {
  const { data, error } = await supabase.rpc('crear_invitacion', { p_role: role });
  if (error) fallar('No se pudo crear la invitación', error);
  return data as string;
}

export async function aceptarInvitacion(codigo: string): Promise<void> {
  const { error } = await supabase.rpc('aceptar_invitacion', { p_code: codigo.trim() });
  if (error) fallar('No se pudo aceptar', error);
}
