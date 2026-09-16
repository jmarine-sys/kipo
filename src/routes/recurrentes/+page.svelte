<script lang="ts">
  import { onMount } from 'svelte';
  import { listAccounts, listCategories } from '$lib/ledger/api';
  import {
    listUpcoming, createScheduled, archiveScheduled, registerScheduled,
    skipScheduled, updateScheduled, nombreFrecuencia, cuandoFalta,
    FRECUENCIAS, type Upcoming, type Frecuencia
  } from '$lib/ledger/recurrentes';
  import { colorCategoria } from '$lib/categorias';
  import { money, today, shortDate } from '$lib/format';
  import type { Account, Category } from '$lib/types';

  let items = $state<Upcoming[]>([]);
  let cuentas = $state<Account[]>([]);
  let categorias = $state<Category[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);
  let busy = $state(false);

  let abierto = $state<string | null>(null);
  let montoRaw = $state('');
  let cuentaElegida = $state<string | null>(null);

  let creando = $state(false);
  let nDesc = $state('');
  let nCat = $state<string | null>(null);
  let nCuenta = $state<string | null>(null);
  let nMontoRaw = $state('');
  let nVariable = $state(false);
  let nFrec = $state<Frecuencia>('monthly');
  let nDesde = $state(today());

  const num = (s: string) => Number(s.replace(/\./g, '').replace(',', '.')) || 0;

  const pagables = $derived(cuentas.filter((a) => a.valuation === 'balance'));
  const hojas = $derived(
    categorias.filter((c) => c.kind === 'expense' && !categorias.some((x) => x.parent_id === c.id))
  );
  const vencidos = $derived(items.filter((i) => i.vencido));
  const proximos = $derived(items.filter((i) => !i.vencido));

  /** Lo que se viene en los próximos 30 días, que es la proyección útil. */
  const totalMes = $derived(
    items.filter((i) => i.dias <= 30 && i.currency === 'ARS' && i.amount !== null)
         .reduce((t, i) => t + Number(i.amount), 0)
  );

  function abrir(i: Upcoming) {
    if (abierto === i.id) { abierto = null; return; }
    abierto = i.id;
    montoRaw = i.amount ? String(Math.round(Number(i.amount))) : '';
    cuentaElegida = i.account_id;
    error = null;
  }

  async function load() {
    loading = true;
    try {
      [items, cuentas, categorias] = await Promise.all([
        listUpcoming(), listAccounts(), listCategories()
      ]);
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo cargar';
    } finally { loading = false; }
  }

  async function registrar(i: Upcoming) {
    busy = true; error = null;
    try {
      await registerScheduled(i.id, {
        amount: montoRaw ? num(montoRaw) : null,
        accountId: cuentaElegida
      });
      abierto = null;
      await load();
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo registrar';
    } finally { busy = false; }
  }

  async function saltear(i: Upcoming) {
    if (!confirm(`¿Saltear este período de "${i.description}"? No se registra ningún movimiento.`)) return;
    busy = true; error = null;
    try { await skipScheduled(i.id); abierto = null; await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo saltear'; }
    finally { busy = false; }
  }

  async function archivar(i: Upcoming) {
    if (!confirm(`¿Archivar "${i.description}"? Los movimientos ya registrados quedan intactos.`)) return;
    busy = true;
    try { await archiveScheduled(i.id); abierto = null; await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo archivar'; }
    finally { busy = false; }
  }

  async function crear(ev: SubmitEvent) {
    ev.preventDefault();
    if (!nCat) return;
    busy = true; error = null;
    try {
      await createScheduled({
        description: nDesc.trim(),
        category_id: nCat,
        account_id: nCuenta,
        amount: nVariable ? null : num(nMontoRaw),
        currency: 'ARS',
        frequency: nFrec,
        next_on: nDesde
      });
      nDesc = ''; nMontoRaw = ''; nVariable = false; creando = false;
      await load();
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo crear';
    } finally { busy = false; }
  }

  onMount(load);
</script>

<div class="page stack">
  <div class="spread">
    <a href="/" class="back" aria-label="Volver">←</a>
    <h1>Lo que se viene</h1>
    <span></span>
  </div>

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  {#if loading}
    <p class="dim">Cargando…</p>
  {:else}
    {#if totalMes > 0}
      <p class="proyeccion">
        En los próximos 30 días se vienen <b class="money">{money(totalMes)}</b>
        <span class="dim sm">· sin contar los de importe variable</span>
      </p>
    {/if}

    {#each [{ t: 'Vencidos', l: vencidos }, { t: 'Próximos', l: proximos }] as grupo}
      {#if grupo.l.length}
        <h2 class="lbl">{grupo.t}</h2>
        <ul class="list">
          {#each grupo.l as i}
            <li class="card" class:alerta={i.vencido}>
              <button class="fila" onclick={() => abrir(i)}>
                <span class="txt">
                  <b>{i.description}</b>
                  <span class="sub dim">
                    {#if i.category_parent}
                      <i class="punto" style="background:{colorCategoria(i.category_parent)}"></i>
                    {/if}
                    {i.category_name ?? '—'}
                    <span class="sep">·</span>{nombreFrecuencia(i.frequency)}
                    {#if i.account_name}<span class="sep">·</span>{i.account_name}{/if}
                  </span>
                </span>
                <span class="der">
                  <b class="money">{i.amount ? money(i.amount, i.currency) : 'variable'}</b>
                  <span class="cuando" class:venc={i.vencido}>{cuandoFalta(i.dias)}</span>
                </span>
              </button>

              {#if abierto === i.id}
                <div class="panel stack">
                  <div class="row campos">
                    <label class="campo">
                      <span>Importe</span>
                      <input class="monto" inputmode="decimal" bind:value={montoRaw}
                             placeholder={i.amount ? '' : 'cuánto vino'} />
                    </label>
                    <label class="campo">
                      <span>Se paga con</span>
                      <select bind:value={cuentaElegida}>
                        {#each pagables as a}<option value={a.id}>{a.name}</option>{/each}
                      </select>
                    </label>
                  </div>
                  <p class="dim sm nota">
                    Se registra con fecha {shortDate(i.next_on)} y la regla pasa al período siguiente.
                  </p>
                  <button class="btn-primary" onclick={() => registrar(i)} disabled={busy || !montoRaw || !cuentaElegida}>
                    {busy ? 'Registrando…' : 'Registrar el pago'}
                  </button>
                  <div class="finales">
                    <button onclick={() => saltear(i)} disabled={busy}>Saltear este período</button>
                    <button class="peligro" onclick={() => archivar(i)} disabled={busy}>Archivar</button>
                  </div>
                </div>
              {/if}
            </li>
          {/each}
        </ul>
      {/if}
    {/each}

    {#if !items.length}
      <p class="dim">
        Todavía no cargaste ninguna obligación recurrente. Sirven para que la app te
        anticipe impuestos, seguros, servicios y suscripciones.
      </p>
    {/if}

    {#if creando}
      <form class="card stack" onsubmit={crear}>
        <h2>Nueva obligación</h2>
        <label class="campo"><span>Qué es</span>
          <input bind:value={nDesc} required placeholder="Seguro del auto" />
        </label>

        <label class="campo"><span>Categoría</span>
          <select bind:value={nCat} required>
            <option value={null} disabled>Elegí una</option>
            {#each hojas as c}<option value={c.id}>{c.name}</option>{/each}
          </select>
        </label>

        <label class="campo"><span>Se paga con</span>
          <select bind:value={nCuenta}>
            <option value={null}>Lo decido cada vez</option>
            {#each pagables as a}<option value={a.id}>{a.name}</option>{/each}
          </select>
        </label>

        <label class="casilla">
          <input type="checkbox" bind:checked={nVariable} />
          El importe cambia cada período
        </label>
        {#if !nVariable}
          <label class="campo"><span>Importe</span>
            <input class="monto" inputmode="decimal" bind:value={nMontoRaw} required placeholder="45000" />
          </label>
        {/if}

        <div class="row campos">
          <label class="campo"><span>Cada cuánto</span>
            <select bind:value={nFrec}>
              {#each FRECUENCIAS as f}<option value={f.id}>{f.label}</option>{/each}
            </select>
          </label>
          <label class="campo"><span>Próxima vez</span>
            <input type="date" bind:value={nDesde} required />
          </label>
        </div>

        <button class="btn-primary" type="submit" disabled={busy || !nDesc.trim() || !nCat}>Crear</button>
        <button type="button" class="link" onclick={() => (creando = false)}>Cancelar</button>
      </form>
    {:else}
      <button class="btn-primary nueva" onclick={() => (creando = true)}>+ Nueva obligación</button>
    {/if}
  {/if}
</div>

<style>
  .back { font-size: 1.5rem; text-decoration: none; }
  h1 { font-size: 1.15rem; }
  .sm { font-size: .78rem; }
  .lbl { font-size: .72rem; text-transform: uppercase; letter-spacing: .06em; color: var(--text-dim); margin: .4rem 0 -.1rem; }

  .proyeccion { margin: 0; font-size: .9rem; }

  .list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .4rem; }
  .card { padding: 0; overflow: hidden; }
  /* Lo vencido se marca con el borde, no con el fondo: el fondo rojo sobre una
     lista entera grita, y esto puede ser rutina. */
  .card.alerta { border-color: color-mix(in srgb, var(--neg) 55%, transparent); }

  .fila {
    display: flex; align-items: center; justify-content: space-between; gap: .7rem;
    width: 100%; border: none; background: none; text-align: left;
    padding: .7rem .85rem; min-height: 58px;
  }
  .txt { display: flex; flex-direction: column; min-width: 0; gap: .12rem; }
  .txt b { font-size: .95rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sub { font-size: .74rem; display: flex; align-items: center; gap: .3rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sep { opacity: .5; }
  .punto { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; }

  .der { display: flex; flex-direction: column; align-items: flex-end; gap: .12rem; flex-shrink: 0; }
  .der b { font-size: .95rem; white-space: nowrap; }
  .cuando { font-size: .72rem; color: var(--text-dim); white-space: nowrap; }
  .cuando.venc { color: var(--neg); font-weight: 600; }

  .panel { padding: .8rem; background: var(--surface-2); }
  .panel p { margin: 0; }
  .nota { margin-top: -.2rem; }
  .campos { gap: .5rem; align-items: flex-end; }
  .campos > .campo { flex: 1; }
  .finales { display: flex; gap: .5rem; }
  .finales button { flex: 1; min-height: 42px; font-size: .85rem; }
  .peligro { color: var(--neg); background: none; border-color: color-mix(in srgb, var(--neg) 35%, transparent); }

  .monto { text-align: right; }
  /* el botón de cancelar no es un campo: que no pretenda serlo */
  .link { margin-top: -.35rem; }

  .nueva { width: 100%; }
  .link { border: none; background: none; color: var(--accent); min-height: 38px; }
  h2 { font-size: .95rem; }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius); font-size: .88rem;
  }
</style>
