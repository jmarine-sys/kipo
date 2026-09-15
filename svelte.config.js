import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
export default {
  preprocess: vitePreprocess(),
  kit: {
    // ADR-017: salida 100% estatica en modo SPA.
    // No hay servidor propio: el navegador habla directo con Supabase (ADR-007).
    adapter: adapter({ fallback: '200.html' })
  }
};
