<script lang="ts">
  import '../app.css';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { session, initSession } from '$lib/session.svelte';

  let { children } = $props();

  const isLogin = $derived(page.url.pathname.startsWith('/login'));
  const authed  = $derived(!!session.value);

  onMount(initSession);

  $effect(() => {
    if (session.ready && !authed && !isLogin) goto('/login', { replaceState: true });
    if (session.ready && authed && isLogin) goto('/', { replaceState: true });
  });

  const tabs = [
    { href: '/',            label: 'Inicio',      icon: '◧' },
    { href: '/movimientos', label: 'Movimientos', icon: '≡' },
    { href: '/cuentas',     label: 'Cuentas',     icon: '▤' }
  ];
</script>

{#if !session.ready}
  <div class="boot"><span class="dim">Cargando…</span></div>
{:else}
  {@render children()}

  {#if authed && !isLogin}
    <nav class="tabbar">
      {#each tabs as t}
        <a href={t.href} class:active={page.url.pathname === t.href}>
          <span class="ic" aria-hidden="true">{t.icon}</span>
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
    font-size: .72rem;
  }
  .tabbar a.active { color: var(--accent); }
  .ic { font-size: 1.1rem; line-height: 1; }

  /* El boton de registrar es el mas grande y el mas a mano: es el 90% del uso. */
  .fab {
    position: absolute;
    right: 1rem; bottom: calc(100% + .75rem);
    width: 62px; height: 62px;
    border-radius: 50%;
    background: var(--accent); color: var(--accent-fg);
    display: grid; place-items: center;
    box-shadow: 0 6px 20px rgb(0 0 0 / .3);
    text-decoration: none;
  }
  .fab:active { transform: scale(.94); }
</style>
