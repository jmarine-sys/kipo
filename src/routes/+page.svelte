<script lang="ts">
  import { onMount } from 'svelte';
  import { listEntries, listBalances, summarize, type EntryDetail, type MonthSummary } from '$lib/ledger/api';
  import { money, monthRange } from '$lib/format';
  import { colorCategoria } from '$lib/categorias';
  import { listUpcoming, cuandoFalta, type Upcoming } from '$lib/ledger/recurrentes';
  import type { AccountBalance } from '$lib/types';

  let entries = $state<EntryDetail[]>([]);
  let balances = $state<AccountBalance[]>([]);
  let viene = $state<Upcoming[]>([]);
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

  /** Lo que se viene: vencidos primero, y solo lo de los próximos 30 días. */
  const pendientes = $derived(viene.filter((v) => v.dias <= 30));
  const vencidos = $derived(pendientes.filter((v) => v.vencido).length);

  onMount(async () => {
    try {
      [entries, balances, viene] = await Promise.all([
        listEntries(m.from, m.to), listBalances(), listUpcoming()
      ]);
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

    {#if pendientes.length}
      <!-- Brief §10: "quiero que la aplicación pueda anticiparme estos gastos".
           Solo aparece si hay algo en los próximos 30 días: una tarjeta vacía
           permanente es ruido. -->
      <section class="card">
        <div class="spread cab">
          <h2>Lo que se viene</h2>
          <a href="/recurrentes" class="sm">Ver todo →</a>
        </div>
        {#if vencidos}
          <p class="vencidos">
            {vencidos} vencid{vencidos === 1 ? 'o' : 'os'} sin registrar
          </p>
        {/if}
        <ul class="viene">
          {#each pendientes.slice(0, 3) as v}
            <li class="spread">
              <span class="qué">
                {#if v.category_parent}
                  <i class="punto" style="background:{colorCategoria(v.category_parent)}"></i>
                {/if}
                {v.description}
              </span>
              <span class="cuanto">
                <b class="money">{v.amount ? money(v.amount, v.currency) : '—'}</b>
                <span class="dim sm" class:neg={v.vencido}>{cuandoFalta(v.dias)}</span>
              </span>
            </li>
          {/each}
        </ul>
      </section>
    {/if}

    {#if sum.byCategory.length}
      <section class="card">
        <h2>En qué se fue</h2>
        <ul class="cats">
          {#each sum.byCategory.slice(0, 6) as c}
            <li class="spread">
              <span class="cat">
                <i class="punto" style="background:{colorCategoria(c.parent)}"></i>{c.name}
              </span>
              <b class="money">{money(c.total)}</b>
            </li>
          {/each}
        </ul>
      </section>
    {:else}
      <section class="card empty">
        <img src="/marca/kipo-duda.svg" alt="" width="160" height="150" />
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

  /* auto-fit en vez de un numero fijo de columnas: con montos grandes la grilla
     baja a 2 o 1 columna en vez de dejar que el numero se salga de la tarjeta.
     El minmax garantiza que una cifra de siete digitos entre entera. */
  .split, .split3 {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(8.5rem, 1fr));
    gap: .75rem .6rem;
  }
  .split > div, .split3 > div {
    display: flex; flex-direction: column; gap: .1rem;
    font-size: .82rem;
    min-width: 0;   /* sin esto, el contenido que no parte estira la celda */
  }
  .split b, .split3 b {
    font-size: clamp(.95rem, 4vw, 1.05rem);
    min-width: 0;
  }

  .hint { font-size: .78rem; margin: .9rem 0 0; padding-top: .75rem; border-top: 1px solid var(--border); }
  .aprox { margin: .8rem 0 0; }

  h2 { margin-bottom: .6rem; }
  .cats { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .55rem; }
  .cat { display: inline-flex; align-items: center; gap: .45rem; min-width: 0;
         overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  /* mismo distintivo que en Movimientos: la madre es un punto, no texto */
  .punto { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; }

  .cab { margin-bottom: .5rem; }
  .cab a { text-decoration: none; font-weight: 600; }
  .vencidos {
    margin: 0 0 .5rem; font-size: .82rem; font-weight: 600; color: var(--neg);
  }
  .viene { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .5rem; }
  .viene li { gap: .6rem; }
  .qué { display: inline-flex; align-items: center; gap: .45rem; min-width: 0;
         overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .cuanto { display: flex; flex-direction: column; align-items: flex-end; gap: .05rem; flex-shrink: 0; }
  .cuanto b { font-size: .92rem; white-space: nowrap; }

  .empty { text-align: center; }
  .empty img { display: block; margin: .25rem auto .4rem; width: 160px; height: auto; }
  .go { display: inline-block; text-decoration: none; padding: .8rem 1.2rem; border-radius: var(--radius); margin-top: .5rem; }

  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius);
  }
</style>
