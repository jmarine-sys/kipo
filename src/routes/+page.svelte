<script lang="ts">
  import { onMount } from 'svelte';
  import { listEntries, listBalances, summarize, type EntryDetail, type MonthSummary } from '$lib/ledger/api';
  import { money, monthRange } from '$lib/format';
  import type { AccountBalance } from '$lib/types';

  let entries = $state<EntryDetail[]>([]);
  let balances = $state<AccountBalance[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);

  const m = monthRange();
  const sum = $derived<MonthSummary>(summarize(entries));

  /** "Cuanto tengo disponible": punto 8 del brief, que la planilla no podia responder.
      Excluye plazos fijos y posiciones — is_spendable en ADR-012. */
  const available = $derived(
    balances
      .filter((b) => b.is_spendable && b.unit === 'ARS')
      .reduce((t, b) => t + Number(b.balance), 0)
  );
  const usd = $derived(
    balances.filter((b) => b.unit === 'USD').reduce((t, b) => t + Number(b.balance), 0)
  );
  const debt = $derived(
    balances.filter((b) => b.kind === 'liability').reduce((t, b) => t + Number(b.balance), 0)
  );

  onMount(async () => {
    try {
      [entries, balances] = await Promise.all([listEntries(m.from, m.to), listBalances()]);
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo cargar';
    } finally {
      loading = false;
    }
  });
</script>

<div class="page stack">
  <h1 class="cap">{m.label}</h1>

  {#if error}
    <p class="err">{error}</p>
  {:else if loading}
    <p class="dim">Cargando…</p>
  {:else}
    <section class="card">
      <div class="result">
        <span class="dim">Resultado del mes</span>
        <strong class="big money" class:pos={sum.result >= 0} class:neg={sum.result < 0}>
          {money(sum.result)}
        </strong>
        {#if sum.savingRate !== null}
          <span class="dim sm">
            Estás guardando el {(sum.savingRate * 100).toFixed(0)}% de lo que entró
          </span>
        {/if}
      </div>

      <div class="split" class:three={sum.adjustments !== 0}>
        <div><span class="dim">Ingresos</span><b class="money pos">{money(sum.income)}</b></div>
        <div><span class="dim">Gastos</span><b class="money neg">{money(sum.expense)}</b></div>
        {#if sum.adjustments !== 0}
          <!-- ADR-005: el ajuste resta del resultado, pero no es un gasto.
               Mezclarlo con "Gastos" mentiría sobre en qué gastaste. -->
          <div>
            <span class="dim">Ajustes</span>
            <b class="money" class:neg={sum.adjustments > 0}>{money(-sum.adjustments)}</b>
          </div>
        {/if}
      </div>

      <!-- Lo que corrige el error 1: ahorrar o invertir NO empeora este numero,
           porque las transferencias no tocan ninguna categoria. -->
      <p class="hint dim">
        Lo que moviste a ahorro o a inversiones no resta acá: cambiar plata de lugar
        no es un gasto.
      </p>
    </section>

    <section class="card">
      <div class="split3">
        <div><span class="dim">Disponible</span><b class="money">{money(available)}</b></div>
        <div><span class="dim">En dólares</span><b class="money">{money(usd, 'USD')}</b></div>
        <div><span class="dim">Tarjetas</span><b class="money" class:neg={debt < 0}>{money(debt)}</b></div>
      </div>
      <!-- ADR-005 / OD-13: la interfaz TIENE que decir que los saldos son estimados.
           Un numero que parece exacto y no lo es es peor que no tener numero. -->
      <p class="aprox">≈ Saldos estimados: no hay conciliación con el banco</p>
    </section>

    {#if sum.byCategory.length}
      <section class="card">
        <h2>En qué se fue</h2>
        <ul class="cats">
          {#each sum.byCategory.slice(0, 6) as c}
            <li class="spread">
              <span>{c.name}{#if c.parent}<span class="dim sm"> · {c.parent}</span>{/if}</span>
              <b class="money">{money(c.total)}</b>
            </li>
          {/each}
        </ul>
      </section>
    {:else}
      <section class="card empty">
        <p>Todavía no registraste nada este mes.</p>
        <a class="btn-primary go" href="/nuevo">Registrar un movimiento</a>
      </section>
    {/if}
  {/if}
</div>

<style>
  .cap { text-transform: capitalize; }
  .result { display: flex; flex-direction: column; gap: .15rem; margin-bottom: .9rem; }
  .big { font-size: 2.1rem; font-weight: 650; letter-spacing: -0.02em; }
  .sm { font-size: .82rem; }

  .split { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
  .split.three { grid-template-columns: repeat(3, 1fr); }
  .split3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: .5rem; }
  .split > div, .split3 > div { display: flex; flex-direction: column; gap: .1rem; font-size: .82rem; }
  .split b, .split3 b { font-size: 1.05rem; }

  .hint { font-size: .78rem; margin: .9rem 0 0; padding-top: .75rem; border-top: 1px solid var(--border); }
  .aprox { margin: .8rem 0 0; }

  h2 { margin-bottom: .6rem; }
  .cats { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .55rem; }

  .empty { text-align: center; }
  .go { display: inline-block; text-decoration: none; padding: .8rem 1.2rem; border-radius: var(--radius); margin-top: .5rem; }

  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius);
  }
</style>
