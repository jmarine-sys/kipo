<script lang="ts">
  import { onMount } from 'svelte';
  import { cargarCartera } from '$lib/ledger/cartera.datos';
  import {
    calcular, calcularTodo, calcularPortafolio, cerradas, GRUPOS,
    type FlujoInversion, type ValorInversion, type Faltante,
    type ValorPortafolio, type FlujoPortafolio
  } from '$lib/ledger/cartera';
  import { prefs, elegirMedida, elegirObjetivo } from '$lib/preferencias.svelte';
  import { money, shortDate } from '$lib/format';
  import Vacio from '$lib/Vacio.svelte';

  let flujos = $state<FlujoInversion[]>([]);
  let valores = $state<ValorInversion[]>([]);
  let faltantes = $state<Faltante[]>([]);
  let portafolios = $state<ValorPortafolio[]>([]);
  let flujosPf = $state<FlujoPortafolio[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);

  const medida = $derived(prefs.medida);
  const unidad = $derived(medida === 'USD' ? 'USD' : 'UVA');

  // ADR-026: el borde es el portafolio. Cada uno entra como una unidad y las
  // inversiones sueltas por su cuenta, sin contar las de adentro dos veces.
  const total = $derived(calcularTodo(portafolios, valores, flujosPf, flujos, medida));

  const carteras = $derived(
    portafolios.map((p) => ({ p, r: calcularPortafolio(p, flujosPf, medida) }))
  );
  const grupos = $derived(
    GRUPOS.map((g) => {
      const v = valores.filter(g.test);
      return { ...g, cantidad: v.length, r: calcular(v, flujos, medida) };
    }).filter((g) => g.cantidad > 0)
  );

  const objetivo = $derived(prefs.objetivo / 100);
  const anual = $derived(total.anual);
  const diferencia = $derived(anual === null ? null : (anual - objetivo) * 100);

  /** Cuánto del objetivo se cubrió, acotado para que la barra no se desborde. */
  const avance = $derived(
    anual === null || objetivo <= 0 ? 0 : Math.max(0, Math.min(1.35, anual / objetivo))
  );

  const yaCerradas = $derived(cerradas(valores));
  const vivas = $derived(valores.length - yaCerradas);
  const sinDato = $derived(faltantes.filter((f) => f.sin_dolar || f.sin_uva).length);
  const desfasado = $derived(faltantes.filter((f) => f.dolar_viejo || f.uva_viejo).length);

  const pct = (n: number) => `${n >= 0 ? '+' : ''}${(n * 100).toFixed(1)}%`;

  onMount(async () => {
    try {
      const c = await cargarCartera();
      flujos = c.flujos; valores = c.valores; faltantes = c.faltantes;
      portafolios = c.portafolios; flujosPf = c.flujosPortafolio;
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo cargar';
    } finally { loading = false; }
  });
</script>

<div class="page stack">
  <!-- Sin flecha de volver: Cartera es un destino de la barra, no una
       subpantalla de Inversiones. La relación se invirtió y con razón — el
       rendimiento es la pregunta, las posiciones son el detalle. -->
  <div class="spread">
    <h1>Inversiones</h1>
    <a href="/inversiones" class="rend">Lo que tenés →</a>
  </div>

  <!-- ADR-023: toda pantalla que muestre un rendimiento tiene que decir con qué
       vara lo midió. Por eso el selector está arriba y no escondido. -->
  <div class="medidas">
    <button class:on={medida === 'USD'} onclick={() => elegirMedida('USD')}>
      En dólares
      <span class="dim sm">¿le gano al dólar?</span>
    </button>
    <button class:on={medida === 'UVA'} onclick={() => elegirMedida('UVA')}>
      En poder adquisitivo
      <span class="dim sm">¿le gano a la inflación?</span>
    </button>
  </div>

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  {#if loading}
    <p class="dim">Cargando…</p>
  {:else if !valores.length && !portafolios.length}
    <Vacio titulo="Todavía no hay inversiones que medir."
           detalle="Cargá un plazo fijo o una compra y acá vas a ver si estás llegando a tu objetivo."
           href="/inversiones" accion="Ir a inversiones" />
  {:else}
    <section class="card objetivo">
      {#if anual === null}
        <p class="nosé">
          Todavía no puedo calcularlo.
          <span class="dim sm">
            {#if sinDato}
              Faltan cotizaciones de {sinDato} fecha{sinDato === 1 ? '' : 's'}.
            {:else}
              Hace falta al menos un aporte y una valuación con fechas distintas.
            {/if}
          </span>
        </p>
      {:else}
        <span class="dim">Rendimiento anual, {medida === 'USD' ? 'en dólares' : 'en poder adquisitivo'}</span>
        <b class="tasa" class:pos={anual >= objetivo} class:neg={anual < 0}>{pct(anual)}</b>

        <div class="barra">
          <div class="relleno" class:logrado={anual >= objetivo}
               style="width: {Math.min(100, avance * 100 / 1.35)}%"></div>
          <div class="marca" style="left: {100 / 1.35}%"></div>
        </div>

        <p class="veredicto">
          {#if diferencia !== null && diferencia >= 0}
            Estás <b class="pos">{diferencia.toFixed(1)} puntos por encima</b> de tu objetivo del {prefs.objetivo}%.
          {:else if diferencia !== null}
            Te faltan <b class="neg">{Math.abs(diferencia).toFixed(1)} puntos</b> para tu objetivo del {prefs.objetivo}%.
          {/if}
        </p>

        <label class="campo meta">
          <span>Tu objetivo anual</span>
          <span class="row">
            <input type="number" min="0" max="200" step="0.5" value={prefs.objetivo}
                   oninput={(e) => elegirObjetivo(Number(e.currentTarget.value) || 0)} />
            <span class="dim">% anual</span>
          </span>
        </label>
      {/if}
    </section>

    {#if total.valor !== null}
      <section class="card">
        <div class="cifras">
          <div><span class="dim">Valor hoy</span><b class="money">{money(total.valor, unidad)}</b></div>
          <div><span class="dim">Invertido</span><b class="money">{money(total.invertido ?? 0, unidad)}</b></div>
          <div>
            <span class="dim">Ganancia</span>
            <b class="money" class:pos={(total.ganancia ?? 0) >= 0} class:neg={(total.ganancia ?? 0) < 0}>
              {money(total.ganancia ?? 0, unidad)}
            </b>
          </div>
        </div>
        {#if total.dias}
          <p class="dim sm nota">
            Medido sobre {total.dias} días desde tu primer aporte.
            {#if yaCerradas}
              <!-- Importante que se diga: el número incluye lo que ya vendiste, y
                   eso es lo que lo convierte en tu historial de inversión y no
                   solo una foto de lo que tenés hoy. -->
              Incluye {yaCerradas} {yaCerradas === 1 ? 'inversión ya cerrada' : 'inversiones ya cerradas'}
              además de {vivas === 1 ? 'la que tenés' : `las ${vivas} que tenés`} abierta{vivas === 1 ? '' : 's'}.
            {/if}
          </p>
        {/if}
      </section>
    {/if}

    {#if carteras.length}
      <h2 class="lbl">Por portafolio</h2>
      <ul class="list">
        {#each carteras as { p, r } (p.portfolio_id)}
          <li class="card fila">
            <span class="txt">
              <b>{p.name}</b>
              <span class="dim sm">
                {p.cuentas} {p.cuentas === 1 ? 'cuenta' : 'cuentas'}
                {#if r.valor !== null}<span class="sep">·</span>{money(r.valor, unidad)}{/if}
                {#if p.sin_valuar}<span class="sep">·</span><span class="aviso">{p.sin_valuar} sin valuar</span>{/if}
              </span>
            </span>
            {#if r.anual !== null}
              <b class="tasa-chica" class:pos={r.anual >= objetivo} class:neg={r.anual < 0}>
                {pct(r.anual)}
              </b>
            {:else}
              <span class="dim sm">sin datos</span>
            {/if}
          </li>
        {/each}
      </ul>
      <a class="gestionar" href="/cartera/portafolios">Dónde invertís →</a>
    {:else}
      <a class="gestionar destacado" href="/cartera/portafolios">
        <b>Agrupá tus inversiones por broker</b>
        <span class="dim sm">
          Así el efectivo que dejás quieto cuenta, y comprar adentro deja de figurar
          como un aporte nuevo.
        </span>
      </a>
    {/if}

    {#if grupos.length > 1}
      <h2 class="lbl">Por tipo</h2>
      <ul class="list">
        {#each grupos as g}
          <li class="card fila">
            <span class="txt">
              <b>{g.label}</b>
              <span class="dim sm">
                {g.cantidad} {g.cantidad === 1 ? 'inversión' : 'inversiones'}
                {#if g.r.valor !== null}<span class="sep">·</span>{money(g.r.valor, unidad)}{/if}
              </span>
            </span>
            {#if g.r.anual !== null}
              <b class="tasa-chica" class:pos={g.r.anual >= objetivo} class:neg={g.r.anual < 0}>
                {pct(g.r.anual)}
              </b>
            {:else}
              <span class="dim sm">sin datos</span>
            {/if}
          </li>
        {/each}
      </ul>
    {/if}

    <!-- Brief §20: si el cálculo deja algo afuera, hay que decirlo. -->
    {#if total.incompletas || sinDato || desfasado}
      <section class="card avisos">
        <h2>Lo que este número no incluye</h2>
        <ul>
          {#if total.incompletas}
            <li>{total.incompletas} inversión{total.incompletas === 1 ? '' : 'es'} sin precio cargado.</li>
          {/if}
          {#if sinDato}
            <li>Faltan cotizaciones de {sinDato} fecha{sinDato === 1 ? '' : 's'} con movimientos.</li>
          {/if}
          {#if desfasado}
            <li>
              {desfasado} fecha{desfasado === 1 ? '' : 's'} se valuaron con una cotización de más de
              una semana antes.
            </li>
          {/if}
        </ul>
        <p class="dim sm">
          Se cargan solas todos los días. Si faltan las viejas, corré una vez el flujo
          <em>Cotizaciones</em> indicando desde qué fecha.
        </p>
      </section>
    {/if}
  {/if}
</div>

<style>
  .sm { font-size: .78rem; }
  .sep { opacity: .5; }
  .lbl { font-size: .72rem; text-transform: uppercase; letter-spacing: .06em; color: var(--text-dim); margin: .3rem 0 -.1rem; }

  .rend { font-size: .82rem; text-decoration: none; color: var(--accent); }
  .gestionar {
    display: flex; flex-direction: column; gap: .15rem;
    padding: .7rem .85rem; border-radius: 10px; text-decoration: none;
    color: var(--text); font-size: .86rem;
  }
  .gestionar.destacado { background: var(--surface); border: 1px dashed var(--border); }
  .aviso { color: var(--warn); }
  .medidas { display: grid; grid-template-columns: 1fr 1fr; gap: .4rem; }
  .medidas button {
    display: flex; flex-direction: column; align-items: flex-start; gap: .1rem;
    min-height: 56px; padding: .5rem .7rem; border-radius: 10px; font-size: .88rem;
    text-align: left;
  }
  .medidas button.on { background: var(--accent); color: var(--accent-fg); border-color: transparent; font-weight: 650; }
  .medidas button.on .dim { color: var(--accent-fg); opacity: .75; }

  .objetivo { text-align: center; }
  .tasa { display: block; font-size: 2.6rem; font-weight: 700; letter-spacing: -0.03em; margin: .1rem 0 .7rem; }
  .nosé { margin: 0; display: flex; flex-direction: column; gap: .2rem; }

  .barra {
    position: relative; height: 10px; border-radius: 999px;
    background: var(--surface-2); overflow: hidden; margin-bottom: .7rem;
  }
  .relleno { height: 100%; background: var(--warn); border-radius: 999px; transition: width .3s ease; }
  .relleno.logrado { background: var(--pos); }
  /* dónde está el objetivo, para leer la barra de un vistazo */
  .marca { position: absolute; top: -2px; bottom: -2px; width: 2px; background: var(--text); opacity: .55; }

  .veredicto { margin: 0 0 .9rem; font-size: .9rem; }
  .meta { align-items: center; }
  .meta .row { justify-content: center; gap: .4rem; }
  .meta input { width: 5.5rem; text-align: right; }

  .cifras { display: grid; grid-template-columns: repeat(auto-fit, minmax(7.5rem, 1fr)); gap: .75rem .6rem; }
  .cifras > div { display: flex; flex-direction: column; gap: .1rem; font-size: .8rem; min-width: 0; }
  .cifras b { font-size: clamp(.95rem, 4vw, 1.05rem); }
  .nota { margin: .8rem 0 0; }

  .list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .4rem; }
  .fila { display: flex; align-items: center; justify-content: space-between; gap: .7rem; }
  .txt { display: flex; flex-direction: column; min-width: 0; gap: .1rem; }
  .tasa-chica { font-size: 1.05rem; white-space: nowrap; }

  .avisos h2 { font-size: .9rem; margin-bottom: .4rem; }
  .avisos ul { margin: 0 0 .6rem; padding-left: 1.1rem; font-size: .85rem; }
  .avisos li { margin-bottom: .2rem; }
  .avisos p { margin: 0; }

</style>
