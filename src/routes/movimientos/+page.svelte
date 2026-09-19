<script lang="ts">
  import { onMount } from 'svelte';
  import { listEntries, deleteTransaction, toCSV, download, type EntryDetail } from '$lib/ledger/api';
  import { filasDeMovimientos, totales, cotizacionDe, type Fila } from '$lib/ledger/presentacion';
  import { colorCategoria } from '$lib/categorias';
  import Cuenta from '$lib/Cuenta.svelte';
  import { nombresRepetidos, esAmbigua } from '$lib/ledger/tipos';
  import { money, monthRange, shortDate, today } from '$lib/format';
  import Vacio from '$lib/Vacio.svelte';

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

  // La conversión de líneas a filas vive en $lib/ledger/presentacion: una
  // pantalla pide una fila, nunca interpreta un signo.
  const todas = $derived(filasDeMovimientos(entries));

  let hijas = $state<string[]>([]);
  let buscar = $state('');

  const filtrando = $derived(madres.length > 0 || hijas.length > 0);

  const alternar = (lista: string[], v: string) =>
    lista.includes(v) ? lista.filter((x) => x !== v) : [...lista, v];

  /**
   * Los grupos y las categorías presentes, ordenados por cuánto se usan.
   *
   * Se ofrecen unos pocos y el resto por buscador, igual que las fechas: una
   * fila de veinte fichas no es un filtro, es una lista. El criterio es cuántos
   * movimientos tiene cada una EN LO QUE SE ESTÁ VIENDO — no hace falta
   * consultar nada, ya están en pantalla.
   */
  function porUso(clave: (r: Fila) => string | null, de: Fila[]): [string, number][] {
    const n = new Map<string, number>();
    for (const r of de) {
      const k = clave(r);
      if (k) n.set(k, (n.get(k) ?? 0) + 1);
    }
    return [...n.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
  }

  const gruposUsados = $derived(porUso((r) => r.grupo, todas));

  /**
   * Las hijas que se ofrecen. Al elegir un grupo, solo las de ESE grupo: las de
   * otro no llevan a ningún lado porque ya quedaron fuera del filtro.
   */
  const hijasUsadas = $derived(
    porUso(
      (r) => (r.grupo && r.titulo !== r.grupo ? r.titulo : null),
      madres.length ? todas.filter((r) => r.grupo !== null && madres.includes(r.grupo)) : todas
    )
  );

  const coincide = (t: string) =>
    !buscar.trim() || t.toLowerCase().includes(buscar.trim().toLowerCase());

  /** Unas pocas, más las elegidas y las que coincidan con la búsqueda. */
  function aOfrecer(lista: [string, number][], elegidas: string[], tope = 6): [string, number][] {
    const base = buscar.trim()
      ? lista.filter(([t]) => coincide(t))
      : [...lista.slice(0, tope), ...lista.filter(([t]) => elegidas.includes(t))];
    return base.filter(([t], i, a) => a.findIndex(([o]) => o === t) === i);
  }

  /** Pasa si coincide con CUALQUIER filtro elegido: es lo que espera quien tilda. */
  const rows = $derived(
    todas.filter((r) => !filtrando
      || (r.grupo !== null && madres.includes(r.grupo))
      || hijas.includes(r.titulo))
  );

  /** Los nombres repetidos de TODO lo que se está viendo, para aclarar el banco
      solo donde hace falta. */
  const repetidos = $derived(nombresRepetidos(
    rows.flatMap((r) => [r.cuenta, r.desde, r.hacia].filter(Boolean) as { name: string }[])
  ));

  /** La nota, salvo que sea la categoría otra vez: eso no es una nota. */
  const notaUtil = (r: { nota: string | null; titulo: string; grupo: string | null }) =>
    r.nota && r.nota !== r.titulo && r.nota !== r.grupo ? r.nota : null;

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

      {#if gruposUsados.length}
        <div class="cats">
          <div class="spread">
            <h2 class="lbl">Categoría</h2>
            {#if filtrando}
              <button class="link" onclick={() => { madres = []; hijas = []; buscar = ''; }}>
                Quitar filtros
              </button>
            {/if}
          </div>

          <input class="buscar" bind:value={buscar} placeholder="Buscar una categoría…" />

          <span class="lbl chico">Grupos</span>
          <div class="wrap">
            {#each aOfrecer(gruposUsados, madres) as [m, n]}
              <button class="chip" class:on={madres.includes(m)}
                      onclick={() => (madres = alternar(madres, m))}>
                <i class="punto" style="background:{colorCategoria(m)}"></i>{m}
                <span class="cuantos">{n}</span>
              </button>
            {:else}
              <span class="dim sm">Ningún grupo coincide.</span>
            {/each}
          </div>

          {#if hijasUsadas.length}
            <span class="lbl chico">
              Categorías{#if madres.length} de lo elegido{/if}
            </span>
            <div class="wrap">
              {#each aOfrecer(hijasUsadas, hijas) as [c, n]}
                <button class="chip" class:on={hijas.includes(c)}
                        onclick={() => (hijas = alternar(hijas, c))}>
                  {c}<span class="cuantos">{n}</span>
                </button>
              {:else}
                <span class="dim sm">Ninguna coincide.</span>
              {/each}
            </div>
          {/if}
        </div>
      {/if}
    </div>
  {/if}

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  {#if loading}
    <p class="dim">Cargando…</p>
  {:else if !rows.length}
    {#if filtrando}
        <!-- Resultado de búsqueda vacío: no hace falta alentar a nadie, hace
             falta poder quitar el filtro. -->
        <Vacio conMascota={false}
               titulo="Nada coincide con el filtro."
               detalle="Probá con otra categoría o ampliá el período."
               accion="Quitar filtros" onaccion={() => { madres = []; hijas = []; buscar = ''; }} />
      {:else}
        <Vacio titulo="Ningún movimiento en este período."
               detalle={periodo === 'mes' ? 'Probá con otro mes.' : null}
               href="/nuevo?volver=/movimientos" accion="Registrar un movimiento" />
    {/if}
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
            <!-- LO OBLIGATORIO Y NADA MÁS: qué fue, de qué cuenta salió, cuánto.
                 Todo lo demás —el grupo en texto, la nota— se amontonaba en una
                 línea que no se podía leer. Ahora está al tocar, que además es
                 donde la nota por fin aparece: hasta hoy se cargaba y no se veía
                 en ninguna pantalla. -->
            <span class="txt">
              <span class="titulo">
                {#if r.grupo}
                  <i class="punto" style="background:{colorCategoria(r.grupo)}"
                     title={r.grupo}></i>
                {/if}
                <b class="corta">{r.titulo}</b>
              </span>
              <!-- En una transferencia el subtítulo son las dos cuentas por su
                   nombre pelado, sin etiquetas: en el ancho que queda, «Caja de
                   ahorro ARS → Banco Santander USD» no se lee. Lo completo está
                   al tocar. -->
              {#if r.desde || r.hacia}
                <span class="sub dim corta">
                  {r.desde?.name ?? '—'} → {r.hacia?.name ?? '—'}
                </span>
              {:else if r.cuenta}
                <span class="sub dim">
                  <Cuenta cuenta={r.cuenta} ambigua={esAmbigua(r.cuenta, repetidos)} banco="nunca" />
                </span>
              {/if}
            </span>
            <b class="monto money {r.clase}">{r.signo}{money(r.monto, r.unit)}</b>
          </button>

          {#if abierto === r.id}
            <div class="detalle">
              <dl>
                {#if r.grupo && r.grupo !== r.titulo}
                  <dt>Grupo</dt><dd>{r.grupo}</dd>
                {/if}
                {#if r.cuenta}
                  <dt>Cuenta</dt>
                  <dd><Cuenta cuenta={r.cuenta} banco="siempre" /></dd>
                {/if}
                {#if r.desde}
                  <dt>Sale de</dt>
                  <dd>
                    <Cuenta cuenta={r.desde} banco="siempre" />
                    <b class="money">−{money(r.monto, r.unit)}</b>
                  </dd>
                {/if}
                {#if r.hacia}
                  <dt>Entra en</dt>
                  <dd>
                    <Cuenta cuenta={r.hacia} banco="siempre" />
                    <!-- Solo cuando difiere: en una transferencia común entra lo
                         mismo que sale y repetirlo es ruido. En un cambio, es el
                         dato que no estaba en ningún lado. -->
                    <b class="money">+{money(r.entro?.monto ?? r.monto, r.entro?.unit ?? r.unit)}</b>
                  </dd>
                {/if}
                {#if r.entro}
                  {@const c = cotizacionDe({ monto: r.monto, unit: r.unit }, r.entro)}
                  {#if c}
                    <dt>Cotización</dt>
                    <dd>1 {c.uno} = {money(c.equivale, c.en)}</dd>
                  {/if}
                {/if}
                <!-- Siempre presente, con «—» cuando no dice nada nuevo. Una
                     regla creada sin nota se guarda con el nombre de la
                     categoría como descripción, así que el movimiento mostraba
                     la categoría repetida haciéndose pasar por nota. -->
                <dt>Nota</dt>
                <dd class:dim={!notaUtil(r)}>{notaUtil(r) ?? '—'}</dd>
              </dl>
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
  /* Acotado a los renglones: si mañana esta pantalla tiene una tarjeta que no
     sea un renglón, no queremos que se quede sin relleno por accidente. */
  .list > li.card { padding: 0; overflow: hidden; }
  .fila {
    display: grid;
    grid-template-columns: 3.1rem minmax(0, 1fr) auto;
    align-items: center; gap: .6rem; width: 100%;
    border: none; background: none; padding: .65rem .85rem; min-height: 56px; text-align: left;
  }
  .fecha { font-size: .72rem; line-height: 1.2; }
  .txt { display: flex; flex-direction: column; min-width: 0; gap: .1rem; }
  .txt b { font-size: .95rem; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .cats { display: flex; flex-direction: column; gap: .4rem; }
  .lbl.chico { font-size: .68rem; margin: .2rem 0 0; }
  .buscar { width: 100%; }
  .cuantos {
    font-size: .68rem; opacity: .6; margin-left: .1rem;
    font-variant-numeric: tabular-nums;
  }
  .titulo { display: flex; align-items: baseline; gap: .4rem; min-width: 0; }
  /* El nombre de una categoría puede ser largo; la fila, no. Mismo criterio que
     en la lista de cuentas: se recorta lo que se puede adivinar. */
  .corta { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sub.corta { display: block; }
  .detalle dd { display: flex; align-items: baseline; gap: .5rem; flex-wrap: wrap; }
  .detalle { padding: .2rem .85rem .8rem; display: grid; gap: .6rem; }
  .detalle dl {
    margin: 0; display: grid; grid-template-columns: auto 1fr;
    gap: .25rem .7rem; font-size: .82rem; align-items: baseline;
  }
  .detalle dt { color: var(--text-dim); }
  .detalle dd { margin: 0; min-width: 0; overflow-wrap: anywhere; }
  .flecha { opacity: .5; }
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
</style>
