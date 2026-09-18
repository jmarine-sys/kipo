<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { listEntries, listBalances, type EntryDetail } from '$lib/ledger/api';
  import { summarize, type MonthSummary } from '$lib/ledger/presentacion';
  import { money, monthRange } from '$lib/format';
  import { colorCategoria } from '$lib/categorias';
  import { listUpcoming, cuandoFalta, type Upcoming } from '$lib/ledger/recurrentes';
  import { prefs, alternarPrivado } from '$lib/preferencias.svelte';
  import Vacio from '$lib/Vacio.svelte';
  import { misLibros, cambiarLibro, type Libro } from '$lib/ledger/libros';
  import type { AccountBalance } from '$lib/types';

  let entries = $state<EntryDetail[]>([]);
  let balances = $state<AccountBalance[]>([]);
  let viene = $state<Upcoming[]>([]);
  let vieneRoto = $state(false);
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
  /**
   * El nombre del libro activo, y solo cuando hay más de uno.
   *
   * Con un libro es ruido. Con dos, no saber en cuál estás es peor que cualquier
   * otro error de la app: cargás el gasto en el libro equivocado y nada avisa.
   */
  let libros = $state<Libro[]>([]);
  const libroActivo = $derived(libros.find((l) => l.activo) ?? null);
  /** El selector solo tiene sentido con más de uno. Con uno es ruido. */
  const hayVarios = $derived(libros.length > 1);

  /**
   * Cambiar de libro recarga TODO, y tiene que ser así: la política de RLS
   * filtra por el libro activo, así que después de cambiarlo cualquier dato que
   * quedara en pantalla sería del libro anterior.
   */
  async function cambiar(id: string) {
    if (!id || id === libroActivo?.ledger_id) return;
    loading = true;
    try { await cambiarLibro(id); await cargar(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo cambiar de libro'; }
    finally { loading = false; }
  }

  /**
   * Solo lo de ESTE mes — OD-45.
   *
   * Antes eran «los próximos 30 días», que a fin de mes mete cosas del que
   * viene y a principio se come medio calendario. Inicio es literalmente la
   * vista de un mes: mezclarle otro rompe la única promesa que hace.
   *
   * Los vencidos entran igual, sean de cuando sean: eso no es del mes que
   * viene, es una deuda de ahora.
   */
  const finDeMes = (() => {
    const h = new Date();
    return new Date(h.getFullYear(), h.getMonth() + 1, 0).toISOString().slice(0, 10);
  })();

  const pendientes = $derived(viene.filter((v) => v.vencido || v.next_on <= finDeMes));
  const vencidos = $derived(pendientes.filter((v) => v.vencido).length);

  async function cargar() {
    try {
      // Lo esencial: sin esto no hay página que mostrar.
      [entries, balances] = await Promise.all([listEntries(m.from, m.to), listBalances()]);

      // En segundo plano: saber en qué libro estás no puede demorar la pantalla.
      misLibros().then((ls) => (libros = ls)).catch(() => {});

      // Sin cuentas no hay nada que registrar ni que mostrar: todo movimiento
      // sale de algun lado. En vez de una pantalla vacia que explica, se lleva a
      // la puesta en marcha, que es lo que hay que hacer (ADR-027).
      if (!balances.length) { goto('/comenzar'); return; }

      // Lo que se viene es accesorio. Si falla —por ejemplo porque falta
      // aplicar una migración— la página tiene que seguir andando y avisar,
      // no caerse entera. Un accesorio no puede tirar abajo lo principal.
      try {
        viene = await listUpcoming();
        vieneRoto = false;
      } catch {
        viene = [];
        vieneRoto = true;
      }
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo cargar';
    }
  }

  onMount(async () => {
    await cargar();
    loading = false;
  });
</script>

<div class="page stack">
  <div class="spread encabezado">
    <span class="titulo">
      <h1 class="cap">{m.label}</h1>
      <!-- Un desplegable y no un enlace: cambiar de libro es algo que hacés
           seguido, y mandarte a otra pantalla para volver corta el hilo. -->
      {#if hayVarios}
        <select class="libro" value={libroActivo?.ledger_id ?? ''}
                onchange={(e) => cambiar(e.currentTarget.value)}
                aria-label="Cambiar de libro">
          {#each libros as l}<option value={l.ledger_id}>{l.name}</option>{/each}
        </select>
      {/if}
    </span>
    <span class="acciones">
    <a class="ojo" href="/ajustes" aria-label="Ajustes">
      <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor"
           stroke-width="1.7" stroke-linecap="round" aria-hidden="true">
        <circle cx="12" cy="12" r="3.4" />
        <circle cx="12" cy="12" r="7.6" stroke-dasharray="2.4 3.57" />
      </svg>
    </a>
    <button class="ojo" onclick={alternarPrivado}
            aria-pressed={prefs.privado}
            aria-label={prefs.privado ? 'Mostrar los importes' : 'Ocultar los importes'}>
      <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor"
           stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z" />
        <circle cx="12" cy="12" r="3.2" />
        {#if prefs.privado}<path d="M4 20 20 4" />{/if}
      </svg>
    </button>
    </span>
  </div>

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

        <!-- OD-24: el resultado se lleva el TOTAL de una compra en cuotas el día
             que la hiciste. Es honesto -ese día tu patrimonio bajó todo- pero
             deja el mes incomparable con los otros si no se dice. Se explica el
             número que hay; NO se muestra un segundo resultado "como se paga",
             porque serían dos verdades sin decir cuál mirar. -->
        {#if sum.cuotas.compras}
          <p class="cuotas-aviso">
            Incluye <b>{money(sum.cuotas.total)}</b> de
            {sum.cuotas.compras === 1 ? 'una compra en cuotas' : `${sum.cuotas.compras} compras en cuotas`}:
            el mes se lleva el total porque tu patrimonio bajó todo hoy, aunque
            vayas a pagar <b>{money(sum.cuotas.porMes)}</b> por mes.
          </p>
        {/if}
      </div>

      <div class="split" class:three={sum.adjustments !== 0}>
        <div><span class="dim">Ingresos</span><b class="money pos">{money(sum.income)}</b></div>
        <div><span class="dim">Gastos</span><b class="money neg">{money(sum.expense)}</b></div>
        {#if sum.adjustments !== 0}
          <!-- ADR-005: el ajuste resta del resultado, pero no es un gasto.
               Mezclarlo con "Gastos" mentiría sobre en qué gastaste. -->
          <div>
            <span class="dim">{sum.adjustmentsName ?? 'Ajuste de saldo'}</span>
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

    {#if vieneRoto}
      <section class="card aviso">
        <p>
          No se pudo leer lo que se viene. El resto de la página funciona.
          <span class="dim sm">Suele ser una migración de base sin aplicar.</span>
        </p>
      </section>
    {/if}

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
      <Vacio titulo="Todavía no registraste nada este mes."
             href="/nuevo" accion="Registrar un movimiento" />
    {/if}
  {/if}
</div>

<style>
  .cap { text-transform: capitalize; }
  .encabezado { align-items: center; }
  .ojo {
    border: none; background: none; color: var(--text-dim);
    min-width: var(--tap); min-height: var(--tap); padding: 0;
    display: grid; place-items: center;
  }
  .ojo[aria-pressed='true'] { color: var(--accent); }
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

  .aviso { border-color: color-mix(in srgb, var(--warn) 45%, transparent); }
  .aviso p { margin: 0; font-size: .86rem; }
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


  .cuotas-aviso {
    margin: .6rem 0 0; padding: .55rem .7rem; border-radius: 10px;
    font-size: .78rem; line-height: 1.4; text-align: left;
    background: color-mix(in srgb, var(--warn) 10%, transparent);
    border: 1px solid color-mix(in srgb, var(--warn) 30%, transparent);
  }

  .acciones { display: flex; align-items: center; gap: .1rem; }
  .titulo { display: flex; align-items: baseline; gap: .5rem; flex-wrap: wrap; }
  .libro {
    font-size: .74rem; color: var(--accent); font-weight: 600;
    padding: .2rem 1.4rem .2rem .5rem; border-radius: 999px;
    background: color-mix(in srgb, var(--accent) 12%, transparent);
    border: none; appearance: none; min-height: 0;
    background-image: linear-gradient(45deg, transparent 50%, currentColor 50%),
                      linear-gradient(135deg, currentColor 50%, transparent 50%);
    background-position: calc(100% - 12px) 55%, calc(100% - 8px) 55%;
    background-size: 4px 4px, 4px 4px;
    background-repeat: no-repeat;
  }

  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius);
  }
</style>
