<script lang="ts">
  import { onMount } from 'svelte';
  import { listEntries, deleteTransaction, toCSV, download, type EntryDetail } from '$lib/ledger/api';
  import { filasDeMovimientos, totales } from '$lib/ledger/presentacion';
  import { colorCategoria } from '$lib/categorias';
  import { money, monthRange, shortDate, today } from '$lib/format';

  type Periodo = 'mes' | 'trimestre' | 'semestre' | 'anio' | 'rango';
  const PERIODOS: { id: Periodo; label: string }[] = [
    { id: 'mes',       label: 'Mes' },
    { id: 'trimestre', label: '3 meses' },
    { id: 'semestre',  label: '6 meses' },
    { id: 'anio',      label: 'Año' },
    { id: 'rango',     label: 'Entre fechas' }
  ];

  let entries = $state<EntryDetail[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);

  let periodo = $state<Periodo>('mes');
  let offset = $state(0);                 // solo aplica al período 'mes'
  let desde = $state(''); let hasta = $state(today());
  let madres = $state<string[]>([]);      // categorías madre seleccionadas
  let verFiltros = $state(false);

  const p = (n: number) => String(n).padStart(2, '0');
  const iso = (d: Date) => `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;

  const rango = $derived.by(() => {
    if (periodo === 'rango') {
      return { from: desde || '2000-01-01', to: hasta || today(), label: 'entre fechas' };
    }
    if (periodo === 'mes') {
      const d = new Date(); d.setMonth(d.getMonth() + offset);
      return monthRange(d);
    }
    const meses = periodo === 'trimestre' ? 3 : periodo === 'semestre' ? 6 : 12;
    const fin = new Date();
    const ini = new Date(); ini.setMonth(ini.getMonth() - (meses - 1)); ini.setDate(1);
    return {
      from: iso(ini),
      to: iso(fin),
      label: `últimos ${meses} meses`
    };
  });

  /** Las categorías madre presentes en lo cargado. Solo se ofrece filtrar por lo que existe. */
  const madresDisponibles = $derived.by(() => {
    const s = new Set<string>();
    for (const e of entries) if (e.category_parent) s.add(e.category_parent);
    return [...s].sort();
  });

  const filtrando = $derived(madres.length > 0);

  function alternarMadre(m: string) {
    madres = madres.includes(m) ? madres.filter((x) => x !== m) : [...madres, m];
  }

  // La conversión de líneas a filas vive en $lib/ledger/presentacion: una
  // pantalla pide una fila, nunca interpreta un signo.
  const rows = $derived(
    filasDeMovimientos(entries)
      .filter((r) => !filtrando || (r.madre !== null && madres.includes(r.madre)))
  );

  const suma = $derived(totales(rows));

  let abierto = $state<string | null>(null);

  async function load() {
    loading = true; error = null;
    try { entries = await listEntries(rango.from, rango.to); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo cargar'; }
    finally { loading = false; }
  }

  async function remove(id: string) {
    if (!confirm('¿Borrar este movimiento? Se borran también sus líneas.')) return;
    try { await deleteTransaction(id); abierto = null; await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo borrar'; }
  }

  onMount(load);
  $effect(() => { rango.from; rango.to; load(); });
</script>

<div class="page stack">
  <div class="spread">
    <h1 class="cap">{periodo === 'mes' ? rango.label : rango.label}</h1>
    {#if periodo === 'mes'}
      <div class="row">
        <button class="nav" onclick={() => offset--} aria-label="Mes anterior">‹</button>
        <button class="nav" onclick={() => offset++} disabled={offset >= 0} aria-label="Mes siguiente">›</button>
      </div>
    {/if}
  </div>

  <button class="abrir-filtros" onclick={() => (verFiltros = !verFiltros)}>
    Filtros {verFiltros ? '▴' : '▾'}
    {#if filtrando}<span class="cuantos">{madres.length}</span>{/if}
  </button>

  {#if verFiltros}
    <div class="filtros stack">
      <div>
        <h2 class="lbl">Período</h2>
        <div class="wrap">
          {#each PERIODOS as pe}
            <button class="chip" class:on={periodo === pe.id}
                    onclick={() => (periodo = pe.id)}>{pe.label}</button>
          {/each}
        </div>
      </div>

      {#if periodo === 'rango'}
        <div class="row fechas">
          <label class="dim sm">Desde <input type="date" bind:value={desde} /></label>
          <label class="dim sm">Hasta <input type="date" bind:value={hasta} /></label>
        </div>
      {/if}

      {#if madresDisponibles.length}
        <div>
          <h2 class="lbl">Categoría</h2>
          <div class="wrap">
            {#each madresDisponibles as m}
              <button class="chip" class:on={madres.includes(m)} onclick={() => alternarMadre(m)}>
                <i class="punto" style="background:{colorCategoria(m)}"></i>{m}
              </button>
            {/each}
            {#if filtrando}
              <button class="chip limpiar" onclick={() => (madres = [])}>Quitar filtros</button>
            {/if}
          </div>
        </div>
      {/if}
    </div>
  {/if}

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  {#if loading}
    <p class="dim">Cargando…</p>
  {:else if !rows.length}
    <p class="dim">{filtrando ? 'Nada coincide con el filtro.' : 'Ningún movimiento en este período.'}</p>
  {:else}
    <p class="resumen dim">
      {rows.length} movimiento{rows.length === 1 ? '' : 's'}
      {#if suma.gastos}· <b class="money neg">{money(suma.gastos)}</b> en gastos{/if}
      {#if suma.ingresos}· <b class="money pos">{money(suma.ingresos)}</b> en ingresos{/if}
    </p>

    <ul class="list">
      {#each rows as r}
        <li class="card">
          <button class="fila" onclick={() => (abierto = abierto === r.id ? null : r.id)}>
            <span class="fecha dim">{shortDate(r.fecha)}</span>
            <span class="txt">
              <b>{r.titulo}</b>
              <span class="sub dim">
                {#if r.madre}<i class="punto" style="background:{colorCategoria(r.madre)}"></i>{r.madre}{/if}
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
      <button onclick={() => download(`kipo-${rango.from}_${rango.to}.csv`, toCSV(entries), 'text/csv')}>
        Exportar CSV
      </button>
      <button onclick={() => download(`kipo-${rango.from}_${rango.to}.json`, JSON.stringify(entries, null, 2), 'application/json')}>
        Exportar JSON
      </button>
    </div>
  {/if}
</div>

<style>
  .cap { text-transform: capitalize; font-size: 1.2rem; }
  .nav { min-width: 42px; min-height: 42px; padding: 0; }

  .abrir-filtros {
    align-self: flex-start; min-height: 38px; padding: 0 .8rem;
    font-size: .85rem; border-radius: 999px;
    display: inline-flex; align-items: center; gap: .4rem;
  }
  .cuantos {
    background: var(--accent); color: var(--accent-fg);
    border-radius: 999px; min-width: 18px; height: 18px;
    font-size: .7rem; display: grid; place-items: center; padding: 0 .3rem;
  }
  .filtros { background: var(--surface-2); border-radius: var(--radius); padding: .8rem; }
  .lbl { font-size: .72rem; text-transform: uppercase; letter-spacing: .06em; color: var(--text-dim); margin-bottom: .4rem; }
  .fechas { gap: .6rem; flex-wrap: wrap; }
  .fechas label { display: flex; flex-direction: column; gap: .2rem; flex: 1; min-width: 8rem; }
  .fechas input {
    min-height: 42px; padding: 0 .6rem; width: 100%;
    background: var(--surface); border: 1px solid var(--border); border-radius: 10px;
  }
  .chip {
    min-height: 38px; padding: 0 .8rem; border-radius: 999px; font-size: .84rem;
    display: inline-flex; align-items: center; gap: .4rem;
  }
  .chip.on { background: var(--accent); color: var(--accent-fg); border-color: transparent; font-weight: 600; }
  .chip.limpiar { color: var(--neg); border-style: dashed; }

  .resumen { font-size: .82rem; margin: 0; }

  .list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .4rem; }
  .card { padding: 0; overflow: hidden; }
  .fila {
    display: grid;
    grid-template-columns: 3.1rem minmax(0, 1fr) auto;
    align-items: center; gap: .6rem; width: 100%;
    border: none; background: none; padding: .65rem .85rem; min-height: 56px; text-align: left;
  }
  .fecha { font-size: .72rem; line-height: 1.2; }
  .txt { display: flex; flex-direction: column; min-width: 0; gap: .1rem; }
  .txt b { font-size: .95rem; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sub { font-size: .74rem; display: flex; align-items: center; gap: .3rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sep { opacity: .5; }
  .punto { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; display: inline-block; }

  .monto { font-size: 1rem; white-space: nowrap; }
  .monto.neg { color: var(--neg); }
  .monto.pos { color: var(--pos); }
  /* Neutro = no toca el resultado. La ausencia de color ES el mensaje. */
  .monto.neutro { color: var(--text-dim); font-weight: 500; }

  .acciones { padding: 0 .85rem .7rem; }
  .borrar {
    width: 100%; color: var(--neg); background: none;
    border-color: color-mix(in srgb, var(--neg) 35%, transparent); min-height: 42px;
  }
  .exp { margin-top: .5rem; }
  .exp button { flex: 1; }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius);
  }
</style>
