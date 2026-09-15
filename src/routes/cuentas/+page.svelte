<script lang="ts">
  import { onMount } from 'svelte';
  import { listBalances, listCategories, createTransaction, archiveAccount } from '$lib/ledger/api';
  import { adjustment } from '$lib/ledger/entries';
  import { signOut } from '$lib/session.svelte';
  import { money, today } from '$lib/format';
  import type { AccountBalance, Category } from '$lib/types';

  let balances = $state<AccountBalance[]>([]);
  let categories = $state<Category[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);

  let openId = $state<string | null>(null);
  let realRaw = $state('');
  let busy = $state(false);

  /** El modelo calcula por mecánica (ADR-012); la interfaz agrupa por intuición. */
  const GROUPS = [
    { id: 'balance', title: 'Disponible',   hint: 'Plata que podés usar hoy' },
    { id: 'accrual', title: 'Inmovilizado', hint: 'Comprometido hasta su vencimiento' },
    { id: 'market',  title: 'Invertido',    hint: 'Se valúa a precio de mercado' }
  ] as const;

  const grouped = $derived(
    GROUPS.map((g) => ({ ...g, items: balances.filter((b) => b.valuation === g.id) }))
      .filter((g) => g.items.length)
  );

  const adjustCat = $derived(categories.find((c) => c.is_system && c.name === 'Ajustes'));
  const open = $derived(balances.find((b) => b.account_id === openId) ?? null);
  const real = $derived(Number(realRaw.replace(/\./g, '').replace(',', '.')) || 0);
  const delta = $derived(open ? real - Number(open.balance) : 0);

  async function load() {
    loading = true;
    try {
      [balances, categories] = await Promise.all([listBalances(), listCategories()]);
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo cargar';
    } finally {
      loading = false;
    }
  }

  /** ADR-005: la válvula de escape de los saldos aproximados.
      No se "corrige" el saldo a mano: se registra un movimiento contra Ajustes,
      así la deriva queda MEDIDA y no escondida. */
  async function applyAdjust() {
    if (!open || !adjustCat || !delta) return;
    busy = true; error = null;
    try {
      await createTransaction(adjustment({
        accountId: open.account_id,
        adjustCategoryId: adjustCat.id,
        delta,
        unit: open.unit,
        date: today(),
        description: 'Ajuste de saldo'
      }));
      openId = null; realRaw = '';
      await load();
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo ajustar';
    } finally {
      busy = false;
    }
  }

  async function archive(id: string, name: string) {
    if (!confirm(`¿Archivar "${name}"? No se borra: sus movimientos quedan intactos.`)) return;
    try { await archiveAccount(id); await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo archivar'; }
  }

  onMount(load);
</script>

<div class="page stack">
  <div class="spread">
    <h1>Cuentas</h1>
    <a class="add" href="/cuentas/nueva">+ Nueva</a>
  </div>

  {#if error}<p class="err">{error}</p>{/if}

  {#if loading}
    <p class="dim">Cargando…</p>
  {:else}
    {#each grouped as g}
      <section class="card">
        <header><h2>{g.title}</h2> <span class="dim sm">{g.hint}</span></header>
        <ul>
          {#each g.items as b}
            <li>
              <button class="acc spread" onclick={() => { openId = openId === b.account_id ? null : b.account_id; realRaw = ''; }}>
                <span>{b.name}{#if b.kind === 'liability'}<span class="tag">deuda</span>{/if}</span>
                <b class="money" class:neg={Number(b.balance) < 0}>{money(b.balance, b.unit)}</b>
              </button>

              {#if openId === b.account_id}
                <div class="panel stack">
                  {#if g.id === 'balance' && adjustCat}
                    <label class="dim sm">
                      ¿Cuánto dice en realidad?
                      <input inputmode="decimal" bind:value={realRaw} placeholder={String(b.balance).split('.')[0]} />
                    </label>
                    {#if delta}
                      <p class="sm">
                        Se registra un ajuste de
                        <b class="money" class:neg={delta < 0} class:pos={delta > 0}>
                          {delta > 0 ? '+' : ''}{money(delta, b.unit)}
                        </b>
                        contra <em>Ajustes</em>, así la diferencia queda medida.
                      </p>
                      <button class="btn-primary" onclick={applyAdjust} disabled={busy}>
                        {busy ? 'Ajustando…' : 'Ajustar saldo'}
                      </button>
                    {/if}
                  {/if}
                  <button class="arch" onclick={() => archive(b.account_id, b.name)}>Archivar cuenta</button>
                </div>
              {/if}
            </li>
          {/each}
        </ul>
      </section>
    {/each}

    <p class="aprox">≈ Saldos estimados: no hay conciliación con el banco</p>

    <a class="link" href="/categorias">Administrar categorías →</a>
    <button class="out" onclick={signOut}>Cerrar sesión</button>
  {/if}
</div>

<style>
  .add { text-decoration: none; font-size: .88rem; font-weight: 600; }
  header { margin-bottom: .6rem; }
  header h2 { display: inline; margin-right: .4rem; }
  .sm { font-size: .78rem; }
  ul { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .3rem; }
  .acc { width: 100%; border: none; background: none; padding: .45rem 0; min-height: 40px; text-align: left; }
  .tag { font-size: .68rem; color: var(--text-dim); margin-left: .4rem; }
  .panel { padding: .75rem; margin: .2rem 0 .5rem; background: var(--surface-2); border-radius: 10px; }
  .panel input {
    width: 100%; min-height: 44px; margin-top: .3rem; padding: 0 .7rem;
    background: var(--surface); border: 1px solid var(--border); border-radius: 10px;
    font-size: 1.05rem; text-align: right;
  }
  .panel p { margin: 0; }
  .arch { color: var(--neg); background: none; border-color: transparent; min-height: 40px; }
  .link { display: block; text-align: center; padding: .6rem; font-size: .9rem; }
  .out { width: 100%; color: var(--neg); }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius);
  }
</style>
