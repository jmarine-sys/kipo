<script lang="ts">
  import '../app.css';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { session, initSession } from '$lib/session.svelte';
  import { cargarPreferencias } from '$lib/preferencias.svelte';

  let { children } = $props();

  const isLogin = $derived(page.url.pathname.startsWith('/login'));
  const authed  = $derived(!!session.value);

  onMount(() => {
    cargarPreferencias();
    initSession();
  });

  $effect(() => {
    if (session.ready && !authed && !isLogin) goto('/login', { replaceState: true });
    if (session.ready && authed && isLogin) goto('/', { replaceState: true });
  });

  // Cinco destinos, y dos de ellos están acá por el mismo motivo: se construyeron
  // enteros y no se llegaba.
  //
  // 'Agenda': la única puerta era una tarjeta de Inicio que aparece cuando ya
  // cargaste un recurrente, y para cargar el primero había que entrar ahí.
  //
  // 'Cartera': estaba a tres clicks —Cuentas, Ver inversiones, Rendimiento— y el
  // último era un enlace de texto en el encabezado de una subpantalla. Es la
  // pantalla que contesta la pregunta central del proyecto; no puede estar
  // escondida detrás de la administración de cuentas.
  const tabs = [
    { href: '/',             label: 'Inicio',      icon: 'casa' },
    { href: '/movimientos',  label: 'Movimientos', icon: 'lista' },
    { href: '/cartera',      label: 'Cartera',     icon: 'cartera' },
    { href: '/recurrentes',  label: 'Agenda',      icon: 'agenda' },
    { href: '/cuentas',      label: 'Cuentas',     icon: 'cuentas' }
  ];

  // Durante la puesta en marcha la barra estorba: ofrece salidas a pantallas que
  // todavia no tienen nada que mostrar. ADR-027.
  const enPuestaEnMarcha = $derived(page.url.pathname === '/comenzar');

  /** Una subpantalla marca su pestaña: /cartera/portafolios enciende Cartera. */
  const enSeccion = (href: string) =>
    href === '/' ? page.url.pathname === '/' : page.url.pathname.startsWith(href);
</script>

{#if !session.ready}
  <div class="boot"><span class="dim">Cargando…</span></div>
{:else}
  {@render children()}

  {#if authed && !isLogin && !enPuestaEnMarcha}
    <nav class="tabbar">
      {#each tabs as t}
        <a href={t.href} class:active={enSeccion(t.href)}>
          {@render icono(t.icon)}
          <span class="lb">{t.label}</span>
        </a>
      {/each}
      <a href="/nuevo" class="fab" aria-label="Registrar movimiento">
        <!-- Trazo dibujado, no el caracter '+': una tipografia en peso liviano
             adelgaza el signo hasta volverlo casi invisible sobre el color. -->
        <svg viewBox="0 0 24 24" width="30" height="30" aria-hidden="true" focusable="false">
          <path d="M12 5.5v13M5.5 12h13" stroke="currentColor" stroke-width="2.8"
                stroke-linecap="round" fill="none"/>
        </svg>
      </a>
    </nav>
  {/if}
{/if}

<!-- Dibujados y no caracteres Unicode: los simbolos geometricos se ven distintos
     en cada telefono, y algunos ni se dibujan. -->
{#snippet icono(cual: string)}
  <svg class="ic" viewBox="0 0 24 24" width="22" height="22" fill="none"
       stroke="currentColor" stroke-width="1.8" stroke-linecap="round"
       stroke-linejoin="round" aria-hidden="true" focusable="false">
    {#if cual === 'casa'}
      <path d="M3 10.5 12 3l9 7.5" />
      <path d="M5.5 9.5V20h13V9.5" />
      <path d="M9.5 20v-6h5v6" />
    {:else if cual === 'lista'}
      <path d="M4 7h16M4 12h16M4 17h10" />
    {:else if cual === 'cartera'}
      <path d="M4 19.5V4.5" />
      <path d="M4 19.5h16" />
      <path d="M7.5 15.5l3.5-4 3 2.5 4.5-6" />
    {:else if cual === 'agenda'}
      <rect x="3.2" y="5" width="17.6" height="15.5" rx="2.5" />
      <path d="M8 3v4M16 3v4M3.2 10h17.6" />
      <circle cx="8.5" cy="14" r="1.1" fill="currentColor" stroke="none" />
    {:else}
      <rect x="3" y="6" width="18" height="13" rx="2.5" />
      <path d="M3 10h18" />
      <circle cx="16.5" cy="14.5" r="1.2" fill="currentColor" stroke="none" />
    {/if}
  </svg>
{/snippet}

<style>
  .boot { display: grid; place-items: center; min-height: 60vh; }

  .tabbar {
    position: fixed; inset: auto 0 0 0;
    display: flex; justify-content: space-around; align-items: stretch;
    background: var(--surface);
    border-top: 1px solid var(--border);
    padding-bottom: env(safe-area-inset-bottom);
    z-index: 10;
  }
  .tabbar a {
    flex: 1;
    display: flex; flex-direction: column; align-items: center; justify-content: center;
    gap: 2px;
    min-height: var(--tap);
    padding: .5rem 0;
    color: var(--text-dim);
    text-decoration: none;
    font-size: .68rem;
  }
  .tabbar .lb { white-space: nowrap; }
  .tabbar a.active { color: var(--accent); }
  .ic { display: block; }

  /* El boton de registrar es el mas grande y el mas a mano: es el 90% del uso. */
  .fab {
    position: absolute;
    right: 1rem; bottom: calc(100% + .75rem);
    width: 62px; height: 62px;
    border-radius: 50%;
    background: var(--fab-bg); color: var(--fab-fg);
    display: grid; place-items: center;
    box-shadow: 0 6px 20px rgb(0 0 0 / .3);
    text-decoration: none;
  }
  .fab:active { transform: scale(.94); }
</style>
