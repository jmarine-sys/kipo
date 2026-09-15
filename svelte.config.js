import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
export default {
  preprocess: vitePreprocess(),
  kit: {
    // ADR-017: salida 100% estatica en modo SPA.
    // No hay servidor propio: el navegador habla directo con Supabase (ADR-007).
    //
    // El fallback es index.html porque es el archivo que Cloudflare Workers sirve
    // en modo single-page-application. SvelteKit desaconseja index.html cuando hay
    // una home prerenderizada, pero aca prerender = false: no hay conflicto posible.
    adapter: adapter({ fallback: 'index.html' })
  }
};
