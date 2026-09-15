<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { listAccounts, listCategories, createTransaction } from '$lib/ledger/api';
  import { expense, income, transfer, exchange, impliedRate } from '$lib/ledger/entries';
  import { money, today } from '$lib/format';
  import { bump, byUse } from '$lib/frequent';
  import type { Account, Category } from '$lib/types';

  // Tres modos, no cuatro. "Transferir" y "Cambio" eran la misma intención —mover
  // plata de un lado a otro— y la diferencia (si cambia de moneda) la sabe la app
  // mirando las cuentas. Si el usuario tiene que preguntar en qué se diferencian,
  // la distinción no estaba en su cabeza: estaba en el modelo.
  type Mode = 'expense' | 'income' | 'move';
  const MODES: { id: Mode; label: string }[] = [
    { id: 'expense', label: 'Gasto' },
    { id: 'income',  label: 'Ingreso' },
    { id: 'move',    label: 'Mover' }
  ];

  let mode = $state<Mode>('expense');
  let raw = $state('');
  let raw2 = $state('');
  let accountId = $state<string | null>(null);
  let toAccountId = $state<string | null>(null);
  let categoryId = $state<string | null>(null);
  let date = $state(today());
  let note = $state('');
  let showNote = $state(false);
  let showAllCats = $state(false);
  let search = $state('');
  let busy = $state(false);
  let error = $state<string | null>(null);

  let accounts = $state<Account[]>([]);
  let categories = $state<Category[]>([]);
  let loaded = $state(false);

  const num = (s: string) => Number(s.replace(/\./g, '').replace(',', '.')) || 0;
  const amount = $derived(num(raw));
  const amount2 = $derived(num(raw2));

  const payable = $derived(accounts.filter((a) => a.valuation === 'balance'));
  const sources = $derived(
    mode === 'income' ? payable.filter((a) => a.kind === 'asset')
    : mode === 'move' ? accounts
    : payable
  );
  const account = $derived(accounts.find((a) => a.id === accountId) ?? null);
  const toAccount = $derived(accounts.find((a) => a.id === toAccountId) ?? null);
  const destinations = $derived(accounts.filter((a) => a.id !== accountId));

  // ---- categorías -----------------------------------------------------------
  const catKind = $derived(mode === 'income' ? 'income' : 'expense');
  const leaves = $derived(
    categories.filter((c) => c.kind === catKind && !categories.some((x) => x.parent_id === c.id))
  );
  /** Las seis más usadas cubren casi todo. El resto vive detrás de "Todas". */
  const top = $derived(byUse(leaves).slice(0, 6));
  const parentOf = (c: Category) => categories.find((p) => p.id === c.parent_id)?.name ?? null;
  const groups = $derived.by(() => {
    const q = search.trim().toLowerCase();
    const match = q
      ? leaves.filter((c) => c.name.toLowerCase().includes(q)
          || (parentOf(c) ?? '').toLowerCase().includes(q))
      : leaves;
    const map = new Map<string, Category[]>();
    for (const c of match) {
      const g = parentOf(c) ?? 'Sin agrupar';
      map.set(g, [...(map.get(g) ?? []), c]);
    }
    return [...map.entries()];
  });
  const chosen = $derived(categories.find((c) => c.id === categoryId) ?? null);

  // ---- mover: la app decide si es transferencia o cambio ---------------------
  const isExchange = $derived(
    mode === 'move' && !!account && !!toAccount && account.unit !== toAccount.unit
  );

  // ADR-004, los dos lados del ciclo de la tarjeta. La app tiene que decirlos en
  // voz alta: son el caso donde es más fácil contar el mismo gasto dos veces.
  const onCard    = $derived(mode === 'expense' && account?.kind === 'liability');
  const payingOff = $derived(mode === 'move' && toAccount?.kind === 'liability');
  const rate = $derived(isExchange && amount && amount2 ? impliedRate(amount, amount2) : null);

  const ready = $derived.by(() => {
    if (!amount || !accountId) return false;
    if (mode === 'expense' || mode === 'income') return !!categoryId;
    if (!toAccountId) return false;
    return isExchange ? !!amount2 : true;
  });

  const LAST = 'kipo:last-account';
  function remember(id: string) {
    try { localStorage.setItem(`${LAST}:${mode}`, id); } catch { /* modo privado */ }
  }
  function recall() {
    try {
      const id = localStorage.getItem(`${LAST}:${mode}`);
      accountId = id && sources.some((a) => a.id === id) ? id : (sources[0]?.id ?? null);
    } catch { accountId = sources[0]?.id ?? null; }
  }

  onMount(async () => {
    try {
      [accounts, categories] = await Promise.all([listAccounts(), listCategories()]);
      recall();
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo cargar';
    } finally { loaded = true; }
  });

  function setMode(m: Mode) {
    mode = m; categoryId = null; toAccountId = null; raw2 = '';
    showAllCats = false; search = '';
    recall();
  }

  /** Enfoca al montar. Equivale a autofocus pero sin el atributo, que confunde
      a los lectores de pantalla al saltar el foco sin avisar. */
  function focusOnMount(node: HTMLInputElement) {
    node.focus();
  }

  function pickCat(id: string) {
    categoryId = id;
    showAllCats = false;
    search = '';
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
        mode === 'expense' ? expense({ accountId, categoryId: categoryId!, amount, unit, ...common })
      : mode === 'income'  ? income({ accountId, categoryId: categoryId!, amount, unit, ...common })
      : isExchange
        ? exchange({ fromId: accountId, fromAmount: amount, fromUnit: unit,
                     toId: toAccountId!, toAmount: amount2, toUnit: toAccount!.unit,
                     asTrade: toAccount!.valuation === 'market', ...common })
        : transfer({ fromId: accountId, toId: toAccountId!, amount, unit, ...common });

      await createTransaction(input);
      remember(accountId);
      if (categoryId) bump(categoryId);
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

  {#if isExchange}
    <div class="second">
      <span class="dim">Recibís</span>
      <input class="money" inputmode="decimal" bind:value={raw2} placeholder="0" />
      <span class="dim">{toAccount?.unit}</span>
    </div>
    {#if rate}
      <p class="rate dim">
        Te queda a <strong>{money(rate, account?.unit)}</strong> por {toAccount?.unit}
      </p>
    {/if}
  {/if}

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  {#if !loaded}
    <p class="dim">Cargando…</p>
  {:else}
    {#if mode !== 'move'}
      <section>
        <h2 class="lbl">{mode === 'income' ? 'Origen' : 'Categoría'}</h2>

        {#if chosen && !showAllCats}
          <!-- Elegida: una sola ficha, y el resto se va del camino -->
          <div class="wrap">
            <button class="chip on" onclick={() => (showAllCats = true)}>
              {chosen.name}
              {#if parentOf(chosen)}<span class="tag">{parentOf(chosen)}</span>{/if}
              <span class="tag">cambiar</span>
            </button>
          </div>
        {:else if !showAllCats}
          <!-- Las de siempre primero: un toque cubre casi todos los gastos -->
          <div class="wrap">
            {#each top as c}
              <button class="chip" onclick={() => pickCat(c.id)}>{c.name}</button>
            {/each}
            {#if leaves.length > top.length}
              <button class="chip more" onclick={() => (showAllCats = true)}>Todas ▾</button>
            {/if}
          </div>
        {:else}
          <!-- Todas, agrupadas y con buscador: es lo que escala cuando crecen -->
          <div class="all">
            <input class="search" bind:value={search} placeholder="Buscar categoría…" use:focusOnMount />
            <div class="groups">
              {#each groups as [g, items]}
                <div class="group">
                  <h3>{g}</h3>
                  <div class="wrap">
                    {#each items as c}
                      <button class="chip" class:on={categoryId === c.id}
                              onclick={() => pickCat(c.id)}>{c.name}</button>
                    {/each}
                  </div>
                </div>
              {:else}
                <p class="dim sm">Nada coincide con «{search}».</p>
              {/each}
            </div>
            <button class="link" onclick={() => { showAllCats = false; search = ''; }}>Cerrar</button>
          </div>
        {/if}
      </section>
    {/if}

    <section>
      <h2 class="lbl">
        {mode === 'expense' ? 'Pagás con' : mode === 'income' ? 'Entra en' : 'Desde'}
      </h2>
      <div class="wrap">
        {#each sources as a}
          <button class="chip" class:on={accountId === a.id}
                  onclick={() => { accountId = a.id; if (toAccountId === a.id) toAccountId = null; }}>
            {a.name}{#if a.kind === 'liability'}<span class="tag">tarjeta</span>{/if}
          </button>
        {/each}
      </div>
    </section>

    {#if mode === 'move'}
      <section>
        <h2 class="lbl">Hacia</h2>
        <div class="wrap">
          {#each destinations as a}
            <button class="chip" class:on={toAccountId === a.id}
                    onclick={() => (toAccountId = a.id)}>
              {a.name}{#if a.unit !== account?.unit}<span class="tag">{a.unit}</span>{/if}
            </button>
          {:else}
            <p class="dim sm">No tenés otra cuenta a dónde mover.</p>
          {/each}
        </div>
        {#if payingOff}
          <p class="what dim sm">
            Pagás deuda de {toAccount?.name}. <strong>No es un gasto</strong>: ya lo contaste
            cuando compraste. Tu patrimonio no cambia — baja la plata y baja la deuda.
          </p>
        {:else if toAccount}
          <p class="what dim sm">
            {#if isExchange}
              Cambiás {account?.unit} por {toAccount.unit}. No es un gasto: tu patrimonio
              queda igual, solo cambia de moneda.
            {:else}
              Movés plata entre tus cuentas. No es un gasto: tu patrimonio queda igual.
            {/if}
          </p>
        {/if}
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

  .modes { display: grid; grid-template-columns: repeat(3, 1fr); gap: .35rem; margin-bottom: 1rem; }
  .modes button { min-height: 44px; font-size: .9rem; border-radius: 10px; }
  .modes button.on { background: var(--accent); color: var(--accent-fg); border-color: transparent; font-weight: 650; }

  .amount { display: flex; align-items: baseline; justify-content: center; gap: .5rem; padding: 1.1rem 0 .5rem; }
  .cur { color: var(--text-dim); font-size: 1rem; }
  .val { font-size: 2.9rem; font-weight: 600; letter-spacing: -0.02em; }
  .val.empty { color: var(--text-dim); }

  .second { display: flex; align-items: center; gap: .5rem; justify-content: center; margin-bottom: .4rem; }
  .second input {
    width: 8rem; text-align: right; font-size: 1.3rem;
    background: var(--surface); border: 1px solid var(--border);
    border-radius: var(--radius); min-height: 44px; padding: 0 .6rem;
  }
  .rate { text-align: center; font-size: .82rem; margin: 0 0 .6rem; }

  section { margin-bottom: .9rem; }
  .lbl { font-size: .74rem; text-transform: uppercase; letter-spacing: .06em; color: var(--text-dim); margin-bottom: .45rem; }

  .chip {
    min-height: 42px; padding: 0 .85rem; border-radius: 999px; font-size: .88rem;
    display: inline-flex; align-items: center; gap: .4rem;
  }
  .chip.on { background: var(--accent); color: var(--accent-fg); border-color: transparent; font-weight: 600; }
  .chip.more { border-style: dashed; }
  .tag { font-size: .68rem; opacity: .7; }
  .sm { font-size: .85rem; }
  .what { margin: .55rem 0 0; }

  .all { background: var(--surface-2); border-radius: var(--radius); padding: .7rem; }
  .search {
    width: 100%; min-height: 44px; padding: 0 .8rem; margin-bottom: .6rem;
    background: var(--surface); border: 1px solid var(--border); border-radius: 10px;
  }
  .groups { max-height: 42vh; overflow-y: auto; display: flex; flex-direction: column; gap: .75rem; }
  .group h3 {
    font-size: .72rem; text-transform: uppercase; letter-spacing: .06em;
    color: var(--text-dim); margin-bottom: .35rem;
  }
  .link { border: none; background: none; color: var(--accent); padding: .4rem 0 0; min-height: 32px; font-size: .85rem; text-align: left; }

  .note {
    width: 100%; min-height: var(--tap); padding: 0 .85rem;
    background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius);
  }

  .pad { display: grid; grid-template-columns: repeat(3, 1fr); gap: .5rem; margin: 1rem 0; }
  .key { min-height: 56px; font-size: 1.3rem; background: var(--surface-2); }
  .save { width: 100%; min-height: 56px; font-size: 1.05rem; }

  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius); font-size: .88rem;
  }
</style>
