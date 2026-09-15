import { sveltekit } from '@sveltejs/kit/vite';
import { SvelteKitPWA } from '@vite-pwa/sveltekit';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [
    sveltekit(),
    SvelteKitPWA({
      registerType: 'autoUpdate',
      // ADR-006: el service worker cachea la INTERFAZ, nunca los datos.
      // Si no hay senial, la app lo dice; no finge que guardo.
      workbox: {
        globPatterns: ['**/*.{js,css,html,svg,woff2}'],
        navigateFallback: '/200.html'
      },
      manifest: {
        id: '/',
        name: 'kipo',
        short_name: 'kipo',
        description: 'Finanzas personales',
        lang: 'es-AR',
        start_url: '/',
        // Absoluto, no './'. Con scope relativo Android puede no reconocer que la
        // aplicacion cubre toda la navegacion, y no oculta la barra de direcciones.
        scope: '/',
        display: 'standalone',
        background_color: '#0f1115',
        theme_color: '#0f1115',
        // Estos archivos TIENEN que existir y decodificarse como PNG. Si faltan,
        // Android degrada la instalacion a un acceso directo -no va al cajon de
        // aplicaciones y no oculta la barra- y no dice por que.
        // Se generan con: python3 scripts/iconos.py
        icons: [
          { src: '/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
          { src: '/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
          { src: '/icon-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' }
        ]
      }
    })
  ]
});
