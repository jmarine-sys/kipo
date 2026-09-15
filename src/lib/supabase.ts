import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_PUBLISHABLE_KEY } from '$env/static/public';

// Estas claves son publicas POR DISENO. La seguridad no viene de que la clave sea
// secreta: viene de RLS aplicado en la base (ADR-002, ADR-003, ADR-007).
// Si la seguridad dependiera de ocultar esta clave, el modelo estaria mal.
export const supabase = createClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_PUBLISHABLE_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,

    // NECESARIO para el acceso con Google (ADR-008): la sesion vuelve en la URL
    // tras el redirect del proveedor.
    detectSessionInUrl: true,

    // PKCE aca es correcto, y la distincion importa:
    // el problema estructural que hizo descartar el magic link en ADR-008 es que el
    // cliente de correo abre el enlace en SU navegador embebido, distinto de aquel
    // que inicio el flujo, y el verificador guardado se pierde. Con un redirect de
    // OAuth el flujo empieza y termina en el MISMO navegador, asi que no ocurre.
    flowType: 'pkce'
  }
});
