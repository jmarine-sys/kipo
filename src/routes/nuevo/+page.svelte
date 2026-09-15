<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { listAccounts, listCategories, createTransaction } from '$lib/ledger/api';
  import { expense, income, transfer, exchange, impliedRate } from '$lib/ledger/entries';
  import { money, today } from '$lib/format';
  import type { Account, Category } from '$lib/types';

  type Mode = 'expense' | 'income' | 'transfer' | 'exchange';
  const MODES: { id: Mode; label: string }[] = [
    { id: 'expense',  label: 'Gasto' },
    { id: 'income',   label: 'Ingreso' },
    { id: 'transfer', label: 'Transferir' },
    { id: 'exchange', label: 'Cambio' }
  ];

  let mode = $state<Mode>('expense');
  let raw = $state('');          // lo tecleado: "25000" o "1234,56"
  let raw2 = $state('');         // monto destino, solo en 'exchange'
  let accountId = $state<string | null>(null);
  let toAccountId = $state<string | null>(null);
  let categoryId = $state<string | null>(null);
  let date = $state(today());
  let note = $state('');
  let showNote = $state(false);
  let busy = $state(false);
  let error = $state<string | null>(null);

  let accounts = $state<Account[]>([]);
  let categories = $state<Category[]>([]);
  let loaded = $state(false);

  const num = (s: string) => Number(s.replace(/\./g, '').replace(',', '.')) || 0;
  const amount = $derived(num(raw));
  const amount2 = $derived(num(raw2));

  /** Cuentas con las que se paga o se cobra: familia 'balance' (ADR-012).
      Un plazo fijo o un CEDEAR no sirven para pagar el supermercado. */
  const payable = $derived(accounts.filter((a) => a.valuation === 'balance'));
  // en un ingreso no cobras en una tarjeta de credito
  const sources = $derived(mode === 'income' ? payable.filter((a) => a.kind === 'asset') : payable);
  const account = $derived(accounts.find((a) => a.id === accountId) ?? null);
  const toAccount = $derived(accounts.find((a) => a.id === toAccountId) ?? null);

  const catKind = $derived(mode === 'income' ? 'income' : 'expense');
  const leaves = $derived(
    categories.filter((c) => c.kind === catKind && !categories.some((x) => x.parent_id === c.id))
  );

  /** En 'transfer' las dos cuentas comparten unidad; en 'exchange' NO pueden compartirla. */
  const destinations = $derived(
    accounts.filter((a) =>
      a.id !== accountId &&
      (mode === 'transfer' ? a.unit === account?.unit : a.unit !== account?.unit)
    )
  );

  const rate = $derived(
    mode === 'exchange' && amount && amount2 ? impliedRate(amount, amount2) : null
  );

  const ready = $derived.by(() => {
    if (!amount || !accountId) return false;
    if (mode === 'expense' || mode === 'income') return !!categoryId;
    if (mode === 'transfer') return !!toAccountId;
    return !!toAccountId && !!amount2;
  });

  // La cuenta usada la ultima vez queda preseleccionada: es lo que convierte
  // "gasto, supermercado, monto, cuenta, guardar" en tres toques reales.
  const LAST = 'kipo:last-account';
  function remember(id: string) {
    try { localStorage.setItem(`${LAST}:${mode}`, id); } catch { /* modo privado */ }
  }
  function recall() {
    try {
      const id = localStorage.getItem(`${LAST}:${mode}`);
      if (id && sources.some((a) => a.id === id)) accountId = id;
      else accountId = sources[0]?.id ?? null;
    } catch { accountId = sources[0]?.id ?? null; }
  }

  onMount(async () => {
    try {
      [accounts, categories] = await Promise.all([listAccounts(), listCategories()]);
      recall();
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo cargar';
    } finally {
      loaded = true;
    }
  });

  function setMode(m: Mode) {
    mode = m;
    categoryId = null;
    toAccountId = null;
    raw2 = '';
    recall();
  }

  function tap(k: string) {
    if (k === '⌫') { raw = raw.slice(0, -1); return; }
    if (k === ',') { if (!raw.includes(',')) raw += raw ? ',' : '0,'; return; }
    if (raw.includes(',') && raw.split(',')[1].length >= 2) return;
    if (raw === '0') raw = '';
    raw += k;
  }

  async function save() {
    if (!ready || !accountId) return;
    busy = true; error = null;
    try {
      const unit = account!.unit;
      const common = { date, description: note || null };
      const input =
        mode === 'expense'  ? expense({ accountId, categoryId: categoryId!, amount, unit, ...common })
      : mode === 'income'   ? income({ accountId, categoryId: categoryId!, amount, unit, ...common })
      : mode === 'transfer' ? transfer({ fromId: accountId, toId: toAccountId!, amount, unit, ...common })
      : exchange({ fromId: accountId, fromAmount: amount, fromUnit: unit,
                   toId: toAccountId!, toAmount: amount2, toUnit: toAccount!.unit,
                   asTrade: toAccount!.valuation === 'market', ...common });

      await createTransaction(input);
      remember(accountId);
      goto('/');
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo guardar';
      busy = false;
    }
  }
</script>

<div class="page">
  <div class="spread top">
    <a href="/" class="back" aria-label="Volver">←</a>
    <input class="date" type="date" bind:value={date} />
  </div>

  <div class="modes" role="tablist">
    {#each MODES as m}
      <button role="tab" aria-selected={mode === m.id} class:on={mode === m.id}
              onclick={() => setMode(m.id)}>{m.label}</button>
    {/each}
  </div>

  <div class="amount">
    <span class="cur">{account?.unit ?? ''}</span>
    <span class="val money" class:empty={!raw}>{raw || '0'}</span>
  </div>

  {#if mode === 'exchange'}
    <div class="second">
      <span class="dim">Recibís</span>
      <input class="money" inputmode="decimal" bind:value={raw2} placeholder="0" />
      <span class="dim">{toAccount?.unit ?? ''}</span>
    </div>
    {#if rate}
      <!-- ADR-010: el tipo de cambio no se guarda, es el cociente. Se muestra para
           que puedas comprobar que no te equivocaste de orden de magnitud (OD-21). -->
      <p class="rate dim">Tipo de cambio implícito: <strong>{money(rate, toAccount?.unit === 'ARS' ? 'USD' : 'ARS')}</strong> por unidad</p>
    {/if}
  {/if}

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  {#if !loaded}
    <p class="dim">Cargando…</p>
  {:else}
    {#if mode === 'expense' || mode === 'income'}
      <section>
        <h2 class="lbl">{mode === 'income' ? 'Origen' : 'Categoría'}</h2>
        <div class="wrap">
          {#each leaves as c}
            <button class="chip" class:on={categoryId === c.id}
                    onclick={() => (categoryId = c.id)}>{c.name}</button>
          {/each}
        </div>
      </section>
    {/if}

    <section>
      <h2 class="lbl">{mode === 'expense' ? 'Pagás con' : mode === 'income' ? 'Entra en' : 'Desde'}</h2>
      <div class="wrap">
        {#each sources as a}
          <button class="chip" class:on={accountId === a.id}
                  onclick={() => { accountId = a.id; if (toAccountId === a.id) toAccountId = null; }}>
            {a.name}{#if a.kind === 'liability'}<span class="tag">tarjeta</span>{/if}
          </button>
        {/each}
      </div>
    </section>

    {#if mode === 'transfer' || mode === 'exchange'}
      <section>
        <h2 class="lbl">Hacia</h2>
        <div class="wrap">
          {#each destinations as a}
            <button class="chip" class:on={toAccountId === a.id}
                    onclick={() => (toAccountId = a.id)}>{a.name} <span class="tag">{a.unit}</span></button>
          {:else}
            <p class="dim sm">
              {mode === 'transfer'
                ? 'No hay otra cuenta en la misma moneda.'
                : 'No hay ninguna cuenta en otra moneda. Un cambio necesita dos monedas distintas.'}
            </p>
          {/each}
        </div>
      </section>
    {/if}

    {#if showNote}
      <input class="note" bind:value={note} placeholder="Nota (opcional)" />
    {:else}
      <button class="link" onclick={() => (showNote = true)}>+ agregar nota</button>
    {/if}
  {/if}

  <div class="pad">
    {#each ['1','2','3','4','5','6','7','8','9',',','0','⌫'] as k}
      <button class="key" onclick={() => tap(k)}>{k}</button>
    {/each}
  </div>

  <button class="btn-primary save" onclick={save} disabled={!ready || busy}>
    {busy ? 'Guardando…' : 'Guardar'}
  </button>
</div>

<style>
  .page { padding-bottom: 2rem; }
  .top { margin-bottom: .75rem; }
  .back { font-size: 1.5rem; text-decoration: none; min-width: var(--tap); }
  .date {
    background: var(--surface); border: 1px solid var(--border);
    border-radius: var(--radius); min-height: 38px; padding: 0 .6rem; font-size: .85rem;
  }

  .modes { display: grid; grid-template-columns: repeat(4, 1fr); gap: .35rem; margin-bottom: 1rem; }
  .modes button { min-height: 42px; padding: 0 .3rem; font-size: .85rem; border-radius: 10px; }
  .modes button.on { background: var(--accent); color: var(--accent-fg); border-color: transparent; font-weight: 650; }

  .amount {
    display: flex; align-items: baseline; justify-content: center; gap: .5rem;
    padding: 1.1rem 0 .5rem;
  }
  .cur { color: var(--text-dim); font-size: 1rem; }
  .val { font-size: 2.9rem; font-weight: 600; letter-spacing: -0.02em; }
  .val.empty { color: var(--text-dim); }

  .second { display: flex; align-items: center; gap: .5rem; justify-content: center; margin-bottom: .5rem; }
  .second input {
    width: 8rem; text-align: right; font-size: 1.3rem;
    background: var(--surface); border: 1px solid var(--border);
    border-radius: var(--radius); min-height: 44px; padding: 0 .6rem;
  }
  .rate { text-align: center; font-size: .8rem; margin: 0 0 .5rem; }

  section { margin-bottom: .9rem; }
  .lbl { font-size: .74rem; text-transform: uppercase; letter-spacing: .06em; color: var(--text-dim); margin-bottom: .45rem; }

  .chip {
    min-height: 42px; padding: 0 .85rem; border-radius: 999px; font-size: .88rem;
    display: inline-flex; align-items: center; gap: .4rem;
  }
  .chip.on { background: var(--accent); color: var(--accent-fg); border-color: transparent; font-weight: 600; }
  .tag { font-size: .68rem; opacity: .7; }
  .sm { font-size: .85rem; }

  .note {
    width: 100%; min-height: var(--tap); padding: 0 .85rem;
    background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius);
  }
  .link { border: none; background: none; color: var(--accent); padding: 0; min-height: 32px; font-size: .85rem; text-align: left; }

  .pad { display: grid; grid-template-columns: repeat(3, 1fr); gap: .5rem; margin: 1rem 0; }
  .key { min-height: 56px; font-size: 1.3rem; background: var(--surface-2); }

  .save { width: 100%; min-height: 56px; font-size: 1.05rem; }

  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius); font-size: .88rem;
  }
</style>
