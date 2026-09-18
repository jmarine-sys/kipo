<script lang="ts">
  import Vacio from '$lib/Vacio.svelte';
  import { onMount } from 'svelte';
  import {
    listBalances, listCategories, createTransaction,
    archiveAccount, renameAccount, deleteAccount
  } from '$lib/ledger/api';
  import { adjustment } from '$lib/ledger/entries';
  import { signOut } from '$lib/session.svelte';
  import { prefs, elegirTema, alternarPrivado, type Tema } from '$lib/preferencias.svelte';
  import { money, today } from '$lib/format';
  import type { AccountBalance, Category } from '$lib/types';

  let balances = $state<AccountBalance[]>([]);
  let categories = $state<Category[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);

  let abierta = $state<string | null>(null);
  let nombre = $state('');
  let realRaw = $state('');
  let busy = $state(false);

  /** El modelo calcula por mecánica (ADR-012); la interfaz agrupa por intuición. */
  const GRUPOS = [
    { id: 'balance', titulo: 'Disponible',   pista: 'Plata que podés usar hoy' },
    { id: 'accrual', titulo: 'Inmovilizado', pista: 'Comprometido hasta su vencimiento' },
    { id: 'market',  titulo: 'Invertido',    pista: 'Se valúa a precio de mercado' }
  ] as const;

  const grupos = $derived(
    GRUPOS.map((g) => ({ ...g, items: balances.filter((b) => b.valuation === g.id) }))
      .filter((g) => g.items.length)
  );

  /**
   * La categoría de ajustes se busca por lo que ES, no por cómo se llama.
   * Antes se buscaba por el nombre «Ajustes» y renombrarla —algo que ahora se
   * puede hacer— habría roto el ajuste de saldo en silencio.
   */
  const catAjuste = $derived(
    categories.find((c) => c.is_system && c.kind === 'expense') ?? null
  );

  const abierto = $derived(balances.find((b) => b.account_id === abierta) ?? null);
  const real = $derived(Number(realRaw.replace(/\./g, '').replace(',', '.')) || 0);
  const delta = $derived(abierto ? real - Number(abierto.balance) : 0);

  function abrir(b: AccountBalance) {
    if (abierta === b.account_id) { abierta = null; return; }
    abierta = b.account_id;
    nombre = b.name;
    realRaw = '';
    error = null;
  }

  async function load() {
    loading = true;
    try {
      [balances, categories] = await Promise.all([listBalances(), listCategories()]);
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo cargar';
    } finally { loading = false; }
  }

  async function guardarNombre() {
    if (!abierto || !nombre.trim() || nombre.trim() === abierto.name) return;
    busy = true; error = null;
    try { await renameAccount(abierto.account_id, nombre); await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo renombrar'; }
    finally { busy = false; }
  }

  /**
   * ADR-005: la válvula de escape de los saldos aproximados. No se "corrige" el
   * saldo a mano: se registra un movimiento contra Ajustes, así la deriva queda
   * MEDIDA y no escondida.
   */
  async function ajustar() {
    if (!abierto || !catAjuste || !delta) return;
    busy = true; error = null;
    try {
      await createTransaction(adjustment({
        accountId: abierto.account_id, adjustCategoryId: catAjuste.id,
        delta, unit: abierto.unit, date: today(), description: 'Ajuste de saldo'
      }));
      abierta = null; realRaw = '';
      await load();
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo ajustar';
    } finally { busy = false; }
  }

  async function archivar(b: AccountBalance) {
    if (!confirm(`¿Archivar "${b.name}"? No se borra: sus movimientos quedan intactos.`)) return;
    busy = true;
    try { await archiveAccount(b.account_id); abierta = null; await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo archivar'; }
    finally { busy = false; }
  }

  async function borrar(b: AccountBalance) {
    if (!confirm(`¿Borrar "${b.name}" definitivamente? No tiene movimientos, así que no se pierde nada.`)) return;
    busy = true;
    try { await deleteAccount(b.account_id); abierta = null; await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo borrar'; }
    finally { busy = false; }
  }

  onMount(load);
</script>

<div class="page stack">
  <div class="spread">
    <h1>Cuentas</h1>
    <div class="row altas">
      <a class="add" href="/cuentas/plazo-fijo">+ Plazo fijo</a>
      <a class="add" href="/cuentas/nueva">+ Cuenta</a>
    </div>
  </div>

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  {#if loading}
    <p class="dim">Cargando…</p>
  {:else}
    {#if !grupos.length}
      <Vacio titulo="Todavía no tenés cuentas."
             detalle="Una cuenta es cada lugar donde hay plata tuya: el efectivo, el banco, la tarjeta, los dólares. Cada gasto sale de una."
             href="/cuentas/nueva" accion="Crear la primera" />
    {/if}

    {#each grupos as g}
      <section class="card">
        <header><h2>{g.titulo}</h2> <span class="dim sm">{g.pista}</span></header>
        <ul>
          {#each g.items as b}
            <li>
              <button class="acc spread" onclick={() => abrir(b)}>
                <span class="nom">
                  {b.name}{#if b.kind === 'liability'}<span class="tag">deuda</span>{/if}
                </span>
                <b class="money" class:neg={Number(b.balance) < 0}>{money(b.balance, b.unit)}</b>
              </button>

              {#if abierta === b.account_id}
                <div class="panel stack">
                  <label class="campo">
                    <span>Nombre</span>
                    <span class="row">
                      <input bind:value={nombre} />
                      <button class="btn-primary chico" disabled={busy || nombre.trim() === b.name || !nombre.trim()}
                              onclick={guardarNombre}>Guardar</button>
                    </span>
                  </label>

                  {#if g.id === 'balance' && catAjuste}
                    <label class="campo">
                      <span>¿Cuánto dice en realidad?</span>
                      <input class="monto" inputmode="decimal" bind:value={realRaw}
                             placeholder={String(b.balance).split('.')[0]} />
                    </label>
                    {#if delta}
                      <p class="sm">
                        Se registra un ajuste de
                        <b class="money" class:neg={delta < 0} class:pos={delta > 0}>
                          {delta > 0 ? '+' : ''}{money(delta, b.unit)}
                        </b>
                        contra <em>{catAjuste.name}</em>, así la diferencia queda medida.
                      </p>
                      <button class="btn-primary" onclick={ajustar} disabled={busy}>
                        {busy ? 'Ajustando…' : 'Ajustar saldo'}
                      </button>
                    {/if}
                  {/if}

                  <div class="finales">
                    {#if b.movimientos === 0}
                      <button class="peligro" onclick={() => borrar(b)} disabled={busy}>Borrar</button>
                      <span class="dim sm">No tiene movimientos</span>
                    {:else}
                      <button class="peligro" onclick={() => archivar(b)} disabled={busy}>Archivar</button>
                      <span class="dim sm">
                        {b.movimientos} movimiento{b.movimientos === 1 ? '' : 's'}: no se puede borrar
                      </span>
                    {/if}
                  </div>
                </div>
              {/if}
            </li>
          {/each}
        </ul>
      </section>
    {/each}

    <p class="aprox">≈ Saldos estimados: no hay conciliación con el banco</p>
    <a class="link" href="/inversiones">Ver inversiones →</a>
    <a class="link" href="/categorias">Administrar categorías →</a>

    <section class="card stack">
      <h2>Preferencias</h2>

      <div>
        <span class="rotulo">Tema</span>
        <div class="temas">
          {#each [['auto','Automático'],['claro','Claro'],['oscuro','Oscuro']] as [id, etiqueta]}
            <button class:on={prefs.tema === id} onclick={() => elegirTema(id as Tema)}>
              {etiqueta}
            </button>
          {/each}
        </div>
        {#if prefs.tema === 'auto'}
          <p class="dim sm ayuda">Sigue lo que tenga configurado tu teléfono.</p>
        {/if}
      </div>

      <label class="casilla">
        <input type="checkbox" checked={prefs.privado} onchange={alternarPrivado} />
        <span>
          Ocultar los importes
          <span class="dim sm bloque">Los difumina en toda la app, para mirarla con gente al lado.</span>
        </span>
      </label>
    </section>

    <button class="out" onclick={signOut}>Cerrar sesión</button>
  {/if}
</div>

<style>
  .altas { gap: .9rem; }
  .add { text-decoration: none; font-size: .86rem; font-weight: 600; white-space: nowrap; }
  header { margin-bottom: .6rem; }
  header h2 { display: inline; margin-right: .4rem; }
  .sm { font-size: .78rem; }
  ul { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .3rem; }

  .acc { width: 100%; border: none; background: none; padding: .45rem 0; min-height: 42px; text-align: left; gap: .6rem; }
  .nom { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .acc b { white-space: nowrap; }
  .tag { font-size: .68rem; color: var(--text-dim); margin-left: .4rem; }

  .panel { padding: .8rem; margin: .2rem 0 .5rem; background: var(--surface-2); border-radius: 10px; }
  .campo .row { gap: .4rem; }
  .campo .row input { flex: 1; }
  .monto { text-align: right; font-size: 1.05rem; }
  .chico { min-height: 44px; padding: 0 .9rem; flex-shrink: 0; }
  .panel p { margin: 0; }

  .finales {
    display: flex; align-items: center; gap: .6rem; flex-wrap: wrap;
    padding-top: .6rem; border-top: 1px solid var(--border);
  }
  .peligro {
    color: var(--neg); background: none;
    border-color: color-mix(in srgb, var(--neg) 35%, transparent);
    min-height: 40px; padding: 0 .9rem;
  }

  .link { display: block; text-align: center; padding: .6rem; font-size: .9rem; }
  .rotulo { font-size: .78rem; color: var(--text-dim); display: block; margin-bottom: .4rem; }
  .temas { display: grid; grid-template-columns: repeat(3, 1fr); gap: .35rem; }
  .temas button { min-height: 42px; border-radius: 10px; font-size: .86rem; padding: 0 .3rem; }
  .temas button.on { background: var(--accent); color: var(--accent-fg); border-color: transparent; font-weight: 650; }
  .ayuda { margin: .45rem 0 0; }
  .bloque { display: block; margin-top: .1rem; }
  .casilla { align-items: flex-start; padding-top: .2rem; }
  .casilla input { margin-top: .2rem; }
  .out { width: 100%; color: var(--neg); }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius); font-size: .88rem;
  }
</style>
