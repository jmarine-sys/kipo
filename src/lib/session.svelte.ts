import type { Session } from '@supabase/supabase-js';
import { supabase } from '$lib/supabase';

/** Estado de sesion compartido. Svelte 5: $state en un modulo .svelte.ts. */
export const session = $state<{ value: Session | null; ready: boolean }>({
  value: null,
  ready: false
});

export async function initSession() {
  const { data } = await supabase.auth.getSession();
  session.value = data.session;
  session.ready = true;
  supabase.auth.onAuthStateChange((_event, s) => {
    session.value = s;
  });
}

export async function signOut() {
  await supabase.auth.signOut();
  session.value = null;
}
