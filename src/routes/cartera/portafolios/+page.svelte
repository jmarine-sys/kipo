<script lang="ts">
  import { onMount } from 'svelte';
  import {
    listarPortafolios, cuentasAsignables, crearPortafolio, asignarCuenta, archivarPortafolio,
    type Portafolio, type CuentaDePortafolio
  } from '$lib/ledger/portafolios';
  import Vacio from '$lib/Vacio.svelte';

  let portafolios = $state<Portafolio[]>([]);
  let cuentas = $state<CuentaDePortafolio[]>([]);
  let loading = $state(true);
  let busy = $state(false);
  let error = $state<string | null>(null);

  let nombre = $state('');
  let fuente = $state('');
  let creando = $state(false);

  /** Las que quedaron afuera de todo portafolio. Son las que miden mal en silencio. */
  const sueltas = $derived(cuentas.filter((c) => !c.portfolio_id));

  async function load() {
    const [p, c] = await Promise.all([listarPortafolios(), cuentasAsignables()]);
    portafolios = p; cuentas = c;
  }

  async function correr(fn: () => Promise<void>) {
    busy = true; error = null;
    try { await fn(); await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo'; }
    finally { busy = false; }
  }

  async function crear(e: SubmitEvent) {
    e.preventDefault();
    const n = nombre.trim();
    if (!n) return;
    await correr(async () => {
      await crearPortafolio(n, fuente || null);
      nombre = ''; fuente = ''; creando = false;
    });
  }

  const deQuien = (p: Portafolio) => cuentas.filter((c) => c.portfolio_id === p.id);

  onMount(async () => {
    try { await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo cargar'; }
    finally { loading = false; }
  });
</script>

<div class="page stack">
  <div class="spread">
    <a href="/cartera" class="back" aria-label="Volver">←</a>
    <h1>Portafolios</h1>
    <span></span>
  </div>

  <p class="dim sm intro">
    Un portafolio es tu cuenta en un broker: el efectivo que tenés ahí más las posiciones.
    Lo que importa es <b>qué entra y qué sale</b> — comprar adentro no es un aporte nuevo,
    es la misma plata cambiando de forma.
  </p>

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  {#if loading}
    <p class="dim">Cargando…</p>
  {:else}
    {#if !portafolios.length}
      <Vacio titulo="Todavía no hay portafolios."
             detalle="Creá uno por cada broker donde operás: Binance, Balanz, el que sea." />
    {/if}

    {#each portafolios as p (p.id)}
      <section class="card stack pf">
        <div class="spread cab">
          <span class="txt">
            <b>{p.name}</b>
            <span class="dim sm">
              {deQuien(p).length} {deQuien(p).length === 1 ? 'cuenta' : 'cuentas'}
              {#if p.fx_source}<span class="sep">·</span>al {p.fx_source.toUpperCase()}{/if}
            </span>
          </span>
          <button class="chico" disabled={busy}
                  onclick={() => correr(() => archivarPortafolio(p.id))}>Archivar</button>
        </div>

        <ul class="cuentas">
          {#each cuentas as c (c.id)}
            {#if c.portfolio_id === p.id || !c.portfolio_id}
              <li>
                <label class="casilla">
                  <input type="checkbox" checked={c.portfolio_id === p.id} disabled={busy}
                         onchange={(e) => correr(() =>
                           asignarCuenta(c.id, e.currentTarget.checked ? p.id : null))} />
                  <span>
                    {c.name}
                    <span class="dim sm">
                      {c.valuation === 'market' ? 'posición' : c.unit}
                      {#if c.institution}<span class="sep">·</span>{c.institution}{/if}
                    </span>
                  </span>
                </label>
              </li>
            {/if}
          {/each}
        </ul>
      </section>
    {/each}

    <!-- ADR-026: una cuenta que se olvida de apuntar a su portafolio no rompe
         nada, mide mal en silencio. Por eso se dice acá y no se deja pasar. -->
    {#if portafolios.length && sueltas.length}
      <section class="card avisos">
        <h2>Fuera de todo portafolio</h2>
        <ul>
          {#each sueltas as c (c.id)}<li>{c.name}</li>{/each}
        </ul>
        <p class="dim sm">
          Se miden por su cuenta. Si en realidad viven dentro de un broker, marcalas arriba:
          mientras estén sueltas, comprar con ese efectivo va a contarse como un aporte nuevo.
        </p>
      </section>
    {/if}

    {#if creando}
      <form class="card stack" onsubmit={crear}>
        <label class="campo">
          <span>Nombre</span>
          <input bind:value={nombre} placeholder="Binance" required />
        </label>
        <label class="campo">
          <span>Con qué dólar se mide</span>
          <select bind:value={fuente}>
            <option value="">El del libro</option>
            <option value="ccl">Contado con liqui</option>
            <option value="mep">MEP</option>
            <option value="cripto">Cripto</option>
            <option value="blue">Blue</option>
            <option value="oficial">Oficial</option>
          </select>
        </label>
        <p class="dim sm">
          Cada cuenta puede decir otra cosa y le gana a esto. Un CEDEAR se sigue
          midiendo al contado con liqui aunque el portafolio diga MEP.
        </p>
        <div class="row">
          <button type="button" class="chico" onclick={() => (creando = false)}>Cancelar</button>
          <button class="btn-primary" disabled={busy || !nombre.trim()}>Crear</button>
        </div>
      </form>
    {:else}
      <button class="btn-primary" onclick={() => (creando = true)}>Nuevo portafolio</button>
    {/if}
  {/if}
</div>

<style>
  .back { font-size: 1.5rem; text-decoration: none; }
  h1 { font-size: 1.15rem; }
  .intro { margin: 0; }
  .pf { gap: .6rem; }
  .cab { align-items: flex-start; }
  .txt { display: flex; flex-direction: column; gap: .15rem; }
  .sm { font-size: .76rem; }
  .sep { margin: 0 .35rem; opacity: .5; }
  .cuentas { list-style: none; margin: 0; padding: 0; display: grid; gap: .1rem; }
  .cuentas .casilla { display: flex; align-items: center; gap: .6rem; padding: .45rem 0; }
  .cuentas .casilla > span { display: flex; flex-direction: column; gap: .1rem; }
  .avisos h2 { font-size: .9rem; margin: 0 0 .4rem; }
  .avisos ul { margin: 0 0 .5rem; padding-left: 1.1rem; }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    padding: .6rem .8rem; border-radius: 10px; margin: 0;
  }
</style>
