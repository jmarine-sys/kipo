<script lang="ts">
  import { onMount } from 'svelte';
  import { listEntries, deleteTransaction, toCSV, download, type EntryDetail } from '$lib/ledger/api';
  import { money, monthRange, shortDate } from '$lib/format';

  let entries = $state<EntryDetail[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);
  let offset = $state(0);

  const range = $derived.by(() => {
    const d = new Date();
    d.setMonth(d.getMonth() + offset);
    return monthRange(d);
  });

  /** Una fila por MOVIMIENTO, no por linea: el usuario piensa en movimientos.
      La linea que se muestra es la de la categoria, o la de la cuenta origen si no hay. */
  const rows = $derived.by(() => {
    const byTx = new Map<string, EntryDetail[]>();
    for (const e of entries) {
      const list = byTx.get(e.transaction_id) ?? [];
      list.push(e);
      byTx.set(e.transaction_id, list);
    }
    return [...byTx.entries()].map(([id, es]) => {
      const cat = es.find((e) => e.category_id);
      const neg = es.find((e) => Number(e.amount) < 0 && e.account_id);
      const pos = es.find((e) => Number(e.amount) > 0 && e.account_id);
      const head = es[0];
      return {
        id,
        date: head.occurred_on,
        kind: head.tx_kind,
        title: cat?.category_name ?? head.description ?? 'Movimiento',
        sub: cat
          ? [neg?.account_name ?? pos?.account_name, head.description].filter(Boolean).join(' · ')
          : `${neg?.account_name ?? '—'} → ${pos?.account_name ?? '—'}`,
        amount: cat ? Number(cat.amount) : Math.abs(Number(neg?.amount ?? 0)),
        unit: cat?.unit ?? neg?.unit ?? 'ARS',
        isCategory: !!cat,
        isIncome: cat?.category_kind === 'income'
      };
    });
  });

  async function load() {
    loading = true; error = null;
    try {
      entries = await listEntries(range.from, range.to);
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo cargar';
    } finally {
      loading = false;
    }
  }

  async function remove(id: string) {
    if (!confirm('¿Borrar este movimiento? Se borran también sus líneas.')) return;
    try {
      await deleteTransaction(id);
      await load();
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo borrar';
    }
  }

  onMount(load);
  $effect(() => { offset; load(); });
</script>

<div class="page stack">
  <div class="spread">
    <h1 class="cap">{range.label}</h1>
    <div class="row">
      <button class="nav" onclick={() => offset--} aria-label="Mes anterior">‹</button>
      <button class="nav" onclick={() => offset++} disabled={offset >= 0} aria-label="Mes siguiente">›</button>
    </div>
  </div>

  {#if error}<p class="err">{error}</p>{/if}

  {#if loading}
    <p class="dim">Cargando…</p>
  {:else if !rows.length}
    <p class="dim">Ningún movimiento este mes.</p>
  {:else}
    <ul class="list">
      {#each rows as r}
        <li class="card item">
          <div class="meta">
            <span class="d dim">{shortDate(r.date)}</span>
            <div class="txt">
              <b>{r.title}</b>
              {#if r.sub}<span class="dim sm">{r.sub}</span>{/if}
            </div>
          </div>
          <div class="right">
            <b class="money" class:neg={r.isCategory && !r.isIncome} class:pos={r.isIncome}>
              {r.isCategory && !r.isIncome ? '−' : r.isIncome ? '+' : ''}{money(r.amount, r.unit)}
            </b>
            {#if !r.isCategory}<span class="dim sm">no afecta el resultado</span>{/if}
            <button class="del" onclick={() => remove(r.id)} aria-label="Borrar">✕</button>
          </div>
        </li>
      {/each}
    </ul>

    <!-- Principio de datos exportables del brief §20 -->
    <div class="row exp">
      <button onclick={() => download(`kipo-${range.from.slice(0,7)}.csv`, toCSV(entries), 'text/csv')}>
        Exportar CSV
      </button>
      <button onclick={() => download(`kipo-${range.from.slice(0,7)}.json`, JSON.stringify(entries, null, 2), 'application/json')}>
        Exportar JSON
      </button>
    </div>
  {/if}
</div>

<style>
  .cap { text-transform: capitalize; }
  .nav { min-width: 42px; min-height: 42px; padding: 0; }
  .list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .5rem; }
  .item { display: flex; align-items: center; justify-content: space-between; gap: .75rem; padding: .7rem .85rem; }
  .meta { display: flex; align-items: center; gap: .7rem; min-width: 0; }
  .d { font-size: .74rem; min-width: 3.1rem; }
  .txt { display: flex; flex-direction: column; min-width: 0; }
  .txt b { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sm { font-size: .76rem; }
  .right { display: flex; align-items: center; gap: .6rem; text-align: right; }
  .right > b { white-space: nowrap; }
  .right { flex-direction: row; }
  .del { border: none; background: none; color: var(--text-dim); min-height: 32px; min-width: 32px; padding: 0; }
  .exp { margin-top: .5rem; }
  .exp button { flex: 1; }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius);
  }
</style>
