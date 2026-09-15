<script lang="ts">
  import { onMount } from 'svelte';
  import { listEntries, deleteTransaction, toCSV, download, type EntryDetail } from '$lib/ledger/api';
  import { colorCategoria } from '$lib/categorias';
  import { money, monthRange, shortDate } from '$lib/format';

  let entries = $state<EntryDetail[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);
  let offset = $state(0);
  let abierto = $state<string | null>(null);

  const range = $derived.by(() => {
    const d = new Date();
    d.setMonth(d.getMonth() + offset);
    return monthRange(d);
  });

  /**
   * Una fila por MOVIMIENTO, no por línea: el usuario piensa en movimientos.
   *
   * Se muestra solo la SUBCATEGORÍA, y la categoría madre va como un punto de
   * color (OD-27). En una lista que se lee cientos de veces, escribir
   * "Gastos variables · Supermercado" en cada renglón gasta el ancho que
   * necesita el monto, y en un celular termina truncando las dos cosas.
   */
  const rows = $derived.by(() => {
    const byTx = new Map<string, EntryDetail[]>();
    for (const e of entries) {
      byTx.set(e.transaction_id, [...(byTx.get(e.transaction_id) ?? []), e]);
    }
    return [...byTx.entries()].map(([id, es]) => {
      const cat = es.find((e) => e.category_id);
      const neg = es.find((e) => Number(e.amount) < 0 && e.account_id);
      const pos = es.find((e) => Number(e.amount) > 0 && e.account_id);
      const head = es[0];
      const esIngreso = cat?.category_kind === 'income';

      return {
        id,
        date: head.occurred_on,
        titulo: cat ? (cat.category_name ?? '—') : `${neg?.account_name ?? '—'} → ${pos?.account_name ?? '—'}`,
        madre: cat?.category_parent ?? null,
        cuenta: cat ? (neg?.account_name ?? pos?.account_name ?? null) : null,
        nota: head.description,
        monto: cat ? Number(cat.amount) : Math.abs(Number(neg?.amount ?? 0)),
        unit: cat?.unit ?? neg?.unit ?? 'ARS',
        // el color del monto ES el mensaje: rojo sale, verde entra, neutro no
        // toca el resultado. No hace falta escribirlo en cada renglón.
        clase: !cat ? 'neutro' : esIngreso ? 'pos' : 'neg',
        signo: !cat ? '' : esIngreso ? '+' : '−'
      };
    });
  });

  async function load() {
    loading = true; error = null;
    try { entries = await listEntries(range.from, range.to); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo cargar'; }
    finally { loading = false; }
  }

  async function remove(id: string) {
    if (!confirm('¿Borrar este movimiento? Se borran también sus líneas.')) return;
    try { await deleteTransaction(id); abierto = null; await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo borrar'; }
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
        <li class="card">
          <button class="fila" onclick={() => (abierto = abierto === r.id ? null : r.id)}>
            <span class="fecha dim">{shortDate(r.date)}</span>

            <span class="txt">
              <b>{r.titulo}</b>
              <span class="sub dim">
                {#if r.madre}
                  <i class="punto" style="background:{colorCategoria(r.madre)}"></i>{r.madre}
                {/if}
                {#if r.cuenta}<span class="sep">·</span>{r.cuenta}{/if}
                {#if r.nota}<span class="sep">·</span>{r.nota}{/if}
              </span>
            </span>

            <b class="monto money {r.clase}">{r.signo}{money(r.monto, r.unit)}</b>
          </button>

          {#if abierto === r.id}
            <div class="acciones">
              <button class="borrar" onclick={() => remove(r.id)}>Borrar movimiento</button>
            </div>
          {/if}
        </li>
      {/each}
    </ul>

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
  .list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .4rem; }
  .card { padding: 0; overflow: hidden; }

  .fila {
    display: grid;
    grid-template-columns: 3.1rem minmax(0, 1fr) auto;  /* minmax(0,1fr) evita que el centro empuje al monto */
    align-items: center;
    gap: .6rem;
    width: 100%;
    border: none; background: none;
    padding: .65rem .85rem;
    min-height: 56px;
    text-align: left;
  }

  .fecha { font-size: .72rem; line-height: 1.2; }

  .txt { display: flex; flex-direction: column; min-width: 0; gap: .1rem; }
  .txt b {
    font-size: .95rem; font-weight: 600;
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  }
  .sub {
    font-size: .74rem;
    display: flex; align-items: center; gap: .3rem;
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  }
  .sep { opacity: .5; }

  /* El distintivo de la categoría madre: un punto, no su nombre escrito. */
  .punto {
    width: 7px; height: 7px; border-radius: 50%;
    flex-shrink: 0; display: inline-block;
  }

  .monto { font-size: 1rem; white-space: nowrap; }
  .monto.neg { color: var(--neg); }
  .monto.pos { color: var(--pos); }
  /* Neutro = no toca el resultado. La ausencia de color ES el mensaje;
     escribirlo en cada renglón robaba el ancho que necesita el monto. */
  .monto.neutro { color: var(--text-dim); font-weight: 500; }

  .acciones { padding: 0 .85rem .7rem; }
  .borrar {
    width: 100%; color: var(--neg); background: none;
    border-color: color-mix(in srgb, var(--neg) 35%, transparent);
    min-height: 42px;
  }

  .exp { margin-top: .5rem; }
  .exp button { flex: 1; }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius);
  }
</style>
