<script lang="ts">
  import { onMount } from 'svelte';
  import {
    misLibros, cambiarLibro, crearInvitacion, aceptarInvitacion, crearLibro,
    cuentasDeLibro, aportarALibro, type Libro, type CuentaDeOtroLibro
  } from '$lib/ledger/libros';
  import { listAccounts } from '$lib/ledger/api';
  import { money, today } from '$lib/format';
  import type { Account } from '$lib/types';

  let libros = $state<Libro[]>([]);
  let loading = $state(true);
  let busy = $state(false);
  let error = $state<string | null>(null);

  let codigo = $state<string | null>(null);
  let copiado = $state(false);
  let entrando = $state(false);
  let codigoIngresado = $state('');

  const activo = $derived(libros.find((l) => l.activo) ?? null);
  const otros = $derived(libros.filter((l) => !l.activo));

  let creando = $state(false);
  let nombreNuevo = $state('');

  // ---- pasar plata a otro libro -------------------------------------------
  let pasando = $state(false);
  let destino = $state('');
  let cuentaOrigen = $state('');
  let cuentaDestino = $state('');
  let montoRaw = $state('');
  let detalle = $state('');
  let misCuentas = $state<Account[]>([]);
  let cuentasAlla = $state<CuentaDeOtroLibro[]>([]);

  const monto = $derived(Number(montoRaw.replace(/\./g, '').replace(',', '.')) || 0);
  const origen = $derived(misCuentas.find((c) => c.id === cuentaOrigen) ?? null);

  // Solo cuentas de la misma moneda: un aporte no es un cambio. Si hiciera falta
  // cambiar de moneda, son dos operaciones distintas y conviene que se vean.
  const destinosPosibles = $derived(cuentasAlla.filter((c) => !origen || c.unit === origen.unit));

  const listoParaPasar = $derived(!!destino && !!cuentaOrigen && !!cuentaDestino && monto > 0);

  async function elegirDestino(id: string) {
    destino = id; cuentaDestino = '';
    cuentasAlla = id ? await cuentasDeLibro(id) : [];
  }
  const soyDuenio = $derived(activo?.role === 'owner');

  async function correr(fn: () => Promise<void>) {
    busy = true; error = null;
    try { await fn(); libros = await misLibros(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo'; }
    finally { busy = false; }
  }

  async function invitar() {
    busy = true; error = null; copiado = false;
    try { codigo = await crearInvitacion('member'); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo invitar'; }
    finally { busy = false; }
  }

  async function copiar() {
    if (!codigo) return;
    try { await navigator.clipboard.writeText(codigo); copiado = true; }
    catch { /* sin permiso de portapapeles se lee y se dicta, que es para lo que es */ }
  }

  onMount(async () => {
    try { libros = await misLibros(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo cargar'; }
    finally { loading = false; }
  });
</script>

<div class="page stack">
  <div class="spread">
    <a href="/cuentas" class="back" aria-label="Volver">←</a>
    <h1>Libros</h1>
    <span></span>
  </div>

  <p class="dim sm intro">
    Un libro son unas cuentas, unas categorías y su historia. Podés llevar el tuyo
    y además entrar al de otra persona — <b>nunca se mezclan</b>: mirás uno por vez.
  </p>

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  {#if loading}
    <p class="dim">Cargando…</p>
  {:else}
    <ul class="list">
      {#each libros as l (l.ledger_id)}
        <li class="card fila" class:on={l.activo}>
          <button class="elegir" disabled={busy || l.activo}
                  onclick={() => correr(() => cambiarLibro(l.ledger_id))}>
            <span class="txt">
              <b>{l.name}</b>
              <span class="dim sm">
                {l.role === 'owner' ? 'Tuyo' : 'Te invitaron'}
                {#if l.miembros > 1}
                  <span class="sep">·</span>{l.miembros} personas
                {/if}
              </span>
            </span>
            {#if l.activo}
              <span class="marca">estás acá</span>
            {:else}
              <span class="dim sm">cambiar →</span>
            {/if}
          </button>
        </li>
      {/each}
    </ul>

    {#if soyDuenio}
      <section class="card stack">
        <h2>Invitar a alguien</h2>
        <p class="dim sm">
          Va a poder <b>registrar y borrar movimientos</b> en <em>{activo?.name}</em>,
          pero no crear ni borrar cuentas y categorías, ni invitar a nadie más.
        </p>

        {#if codigo}
          <div class="codigo">
            <b>{codigo}</b>
            <button class="chico" onclick={copiar}>{copiado ? 'Copiado' : 'Copiar'}</button>
          </div>
          <p class="dim sm">
            Pasáselo por donde quieras. Sirve <b>una sola vez</b> y vence en una semana.
          </p>
        {:else}
          <button class="btn-primary" onclick={invitar} disabled={busy}>
            {busy ? 'Generando…' : 'Generar un código'}
          </button>
        {/if}
      </section>
    {/if}

    {#if otros.length}
      <section class="card stack">
        <h2>Pasar plata a otro libro</h2>
        <p class="dim sm">
          En <em>{activo?.name}</em> sale como <b>gasto</b>: esa plata ya no la
          podés usar sola. En el otro libro entra como ingreso.
        </p>

        {#if pasando}
          <label class="campo"><span>¿A qué libro?</span>
            <select value={destino} onchange={(e) => elegirDestino(e.currentTarget.value)}>
              <option value="">Elegí uno</option>
              {#each otros as l}<option value={l.ledger_id}>{l.name}</option>{/each}
            </select>
          </label>

          <label class="campo"><span>Sale de</span>
            <select bind:value={cuentaOrigen}>
              <option value="">Elegí una cuenta</option>
              {#each misCuentas as c}<option value={c.id}>{c.name} · {c.unit}</option>{/each}
            </select>
          </label>

          <label class="campo"><span>Entra en</span>
            <select bind:value={cuentaDestino} disabled={!destino}>
              <option value="">{destino ? 'Elegí una cuenta' : 'Primero elegí el libro'}</option>
              {#each destinosPosibles as c}<option value={c.id}>{c.name} · {c.unit}</option>{/each}
            </select>
            {#if destino && origen && !destinosPosibles.length}
              <span class="dim sm">Ese libro no tiene ninguna cuenta en {origen.unit}.</span>
            {/if}
          </label>

          <label class="campo"><span>Cuánto</span>
            <input class="monto" inputmode="decimal" bind:value={montoRaw} placeholder="0" />
          </label>

          <label class="campo"><span>Para qué (opcional)</span>
            <input bind:value={detalle} placeholder="Gastos de la casa" />
          </label>

          <div class="row">
            <button type="button" class="chico" onclick={() => (pasando = false)}>Cancelar</button>
            <button class="btn-primary" disabled={busy || !listoParaPasar}
                    onclick={() => correr(async () => {
                      await aportarALibro({
                        destino, cuentaOrigen, cuentaDestino, monto,
                        fecha: today(), detalle: detalle.trim() || null
                      });
                      montoRaw = ''; detalle = ''; pasando = false;
                    })}>
              {monto > 0 ? `Pasar ${money(monto, origen?.unit)}` : 'Pasar'}
            </button>
          </div>
        {:else}
          <button onclick={() => { pasando = true; listAccounts().then((a) => (misCuentas = a.filter((x) => x.valuation === 'balance'))); }}>
            Pasar plata
          </button>
        {/if}
      </section>
    {/if}

    {#if creando}
      <form class="card stack" onsubmit={(e) => {
              e.preventDefault();
              correr(async () => { await crearLibro(nombreNuevo); nombreNuevo = ''; creando = false; });
            }}>
        <label class="campo">
          <span>Nombre del libro</span>
          <input bind:value={nombreNuevo} placeholder="Casa" required />
        </label>
        <p class="dim sm">
          Nace vacío, con las mismas categorías que el tuyo y ninguna cuenta. Vas a
          pasar a mirarlo enseguida.
        </p>
        <div class="row">
          <button type="button" class="chico" onclick={() => (creando = false)}>Cancelar</button>
          <button class="btn-primary" disabled={busy || !nombreNuevo.trim()}>Crear</button>
        </div>
      </form>
    {:else}
      <button onclick={() => (creando = true)}>Nuevo libro</button>
    {/if}

    {#if entrando}
      <form class="card stack" onsubmit={(e) => {
              e.preventDefault();
              correr(async () => { await aceptarInvitacion(codigoIngresado); codigoIngresado = ''; entrando = false; });
            }}>
        <label class="campo">
          <span>El código que te pasaron</span>
          <input bind:value={codigoIngresado} placeholder="A1B2C3D4" required
                 autocapitalize="characters" spellcheck="false" />
        </label>
        <div class="row">
          <button type="button" class="chico" onclick={() => (entrando = false)}>Cancelar</button>
          <button class="btn-primary" disabled={busy || !codigoIngresado.trim()}>Entrar</button>
        </div>
      </form>
    {:else}
      <button onclick={() => (entrando = true)}>Tengo un código de invitación</button>
    {/if}
  {/if}
</div>

<style>
  .back { font-size: 1.5rem; text-decoration: none; }
  h1 { font-size: 1.15rem; }
  h2 { font-size: .95rem; margin: 0; }
  .intro { margin: 0; }
  .list { list-style: none; margin: 0; padding: 0; display: grid; gap: .45rem; }
  .fila { padding: 0; }
  .fila.on { border-color: var(--accent); }
  .elegir {
    width: 100%; display: flex; align-items: center; justify-content: space-between;
    gap: .6rem; padding: .75rem .85rem; background: none; border: none; text-align: left;
    min-height: var(--tap); color: inherit;
  }
  .txt { display: flex; flex-direction: column; gap: .15rem; }
  .marca {
    font-size: .7rem; padding: .12rem .45rem; border-radius: 999px;
    background: var(--accent); color: var(--accent-fg); white-space: nowrap;
  }
  .sep { margin: 0 .3rem; opacity: .5; }
  .sm { font-size: .77rem; }
  .codigo {
    display: flex; align-items: center; justify-content: space-between; gap: .6rem;
    padding: .7rem .85rem; border-radius: 10px; background: var(--surface-2);
  }
  .codigo b { font-size: 1.35rem; letter-spacing: .12em; font-variant-numeric: tabular-nums; }
  .campo { display: flex; flex-direction: column; gap: .3rem; }
  .campo > span:first-child { font-size: .78rem; color: var(--text-dim); }
  .campo input { letter-spacing: .12em; text-transform: uppercase; }
  .row { display: flex; gap: .4rem; }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    padding: .6rem .8rem; border-radius: 10px; margin: 0;
  }
</style>
