<script lang="ts">
  import { onMount } from 'svelte';
  import { listBalances } from '$lib/ledger/api';
  import {
    listPosiciones, venderActivo, guardarPrecio, rendimiento, familiaDe,
    type Posicion
  } from '$lib/ledger/inversiones';
  import { cotizaSola, porQueNoCotiza } from '$lib/ledger/precios';
  import { money, today, shortDate, num } from '$lib/format';
  import Vacio from '$lib/Vacio.svelte';
  import { cargarCartera } from '$lib/ledger/cartera.datos';
  import type { ValorInversion } from '$lib/ledger/cartera';
  import type { AccountBalance } from '$lib/types';

  let posiciones = $state<Posicion[]>([]);

  /**
   * Los plazos fijos, acá — OD-45.
   *
   * Se creaban desde esta pantalla y NO aparecían en ella: solo en Cuentas y en
   * Cartera. Ese era el desconcierto real, más que dónde se registra el
   * vencimiento. Una inversión tiene que verse donde se carga.
   */
  let plazos = $state<ValorInversion[]>([]);
  let cuentas = $state<AccountBalance[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);
  let busy = $state(false);

  let abierta = $state<string | null>(null);
  let precioRaw = $state('');
  let vUnidades = $state('');
  let vMonto = $state('');
  let vHacia = $state<string | null>(null);

  /** Las posiciones separadas por familia, en el mismo orden que el alta. */
  const GRUPOS_POSICION = $derived([
    { id: 'bursatil', titulo: 'Bursátil',
      items: posiciones.filter((p) => familiaDe(p.kind) === 'bursatil') },
    { id: 'cripto', titulo: 'Cripto',
      items: posiciones.filter((p) => familiaDe(p.kind) === 'cripto') }
  ]);

  const efectivo = $derived(cuentas.filter((c) => c.valuation === 'balance' && c.kind === 'asset'));

  /** Los totales solo suman lo que tiene precio: de lo demás no sabemos. */
  const conPrecio = $derived(posiciones.filter((p) => p.valor !== null));
  const sinPrecio = $derived(posiciones.filter((p) => p.valor === null));
  const totalValor = $derived(conPrecio.reduce((t, p) => t + Number(p.valor), 0));
  const totalInvertido = $derived(conPrecio.reduce((t, p) => t + Number(p.invertido), 0));
  const totalGanancia = $derived(totalValor - totalInvertido);
  const totalRend = $derived(rendimiento(totalInvertido, totalGanancia));
  const monedaTotal = $derived(conPrecio[0]?.quote_currency ?? 'USD');

  const abierto = $derived(posiciones.find((p) => p.account_id === abierta) ?? null);

  function abrir(p: Posicion) {
    if (abierta === p.account_id) { abierta = null; return; }
    abierta = p.account_id;
    precioRaw = p.precio ? String(Number(p.precio)) : '';
    vUnidades = ''; vMonto = ''; vHacia = efectivo[0]?.account_id ?? null;
    error = null;
  }

  async function load() {
    loading = true;
    try {
      [posiciones, cuentas] = await Promise.all([listPosiciones(), listBalances()]);
      cargarCartera()
        .then((c) => (plazos = c.valores.filter((v) => v.valuation === 'accrual' && !v.cerrada)))
        .catch(() => {});
    }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo cargar'; }
    finally { loading = false; }
  }

  async function actualizarPrecio(p: Posicion) {
    if (!precioRaw) return;
    busy = true; error = null;
    try { await guardarPrecio(p.instrument_id, num(precioRaw), p.quote_currency, today()); await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo guardar'; }
    finally { busy = false; }
  }

  async function vender(p: Posicion) {
    if (!vHacia) return;
    busy = true; error = null;
    try {
      await venderActivo(p.account_id, num(vUnidades), vHacia, num(vMonto), today());
      abierta = null;
      await load();
    } catch (e) { error = e instanceof Error ? e.message : 'No se pudo vender'; }
    finally { busy = false; }
  }

  onMount(load);
</script>

<div class="page stack">
  <div class="spread">
    <a href="/cuentas" class="back" aria-label="Volver">←</a>
    <h1>Lo que tenés</h1>
    <a href="/cartera" class="rend">¿Cuánto rinde? →</a>
  </div>

  <!-- Un plazo fijo es una inversión y se espera verlo acá. Vivía colgado de
       Cuentas, donde nadie lo iba a buscar: por dentro se parece a una cuenta,
       pero lo que importa es qué significa para quien lo usa. ADR-033. -->
  {#if plazos.length}
    <section class="card stack pf">
      <h2>Plazos fijos</h2>
      <ul class="lista">
        {#each plazos as p}
          <li class="spread">
            <span class="txt">
              <b>{p.name}</b>
              <span class="dim sm">
                vence el {shortDate(p.matures_on ?? '')}
                {#if p.institution}<span class="sep">·</span>{p.institution}{/if}
              </span>
            </span>
            <b class="money">{money(p.valor_nativo ?? 0, p.moneda ?? 'ARS')}</b>
          </li>
        {/each}
      </ul>
      <!-- Dónde se cobra, dicho acá: el usuario lo cargaba en esta pantalla y el
           vencimiento aparecía en otra sin que nada lo anticipara. -->
      <p class="dim sm">Se cobran desde <a href="/recurrentes">Agenda</a> al vencer.</p>
    </section>
  {/if}

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  {#if loading}
    <p class="dim">Cargando…</p>
  {:else if !posiciones.length && !plazos.length}
    <!-- Los plazos fijos cuentan. Se constituyen desde esta misma pantalla, así
         que sin ellos en la condición el primero que cargabas te dejaba mirando
         su tarjeta arriba y "todavía no registraste ninguna inversión" abajo. -->
    <Vacio titulo="Todavía no registraste ninguna inversión."
           detalle="Un plazo fijo, cripto, CEDEARs, acciones o fondos."
           accion="Registrar la primera" href="/inversiones/nueva" />
  {:else}
    {#if conPrecio.length}
      <section class="card total">
        <div class="spread">
          <span class="dim">Valor actual</span>
          <b class="money grande">{money(totalValor, monedaTotal)}</b>
        </div>
        <div class="spread linea">
          <span class="dim">Invertido</span>
          <span class="money">{money(totalInvertido, monedaTotal)}</span>
        </div>
        <div class="spread linea">
          <span class="dim">Ganancia</span>
          <b class="money" class:pos={totalGanancia >= 0} class:neg={totalGanancia < 0}>
            {money(totalGanancia, monedaTotal)}
            {#if totalRend !== null}<span class="pct">{totalRend >= 0 ? '+' : ''}{totalRend.toFixed(1)}%</span>{/if}
          </b>
        </div>
        <!-- Brief §20, transparencia: si el cálculo deja algo afuera, hay que decirlo. -->
        {#if sinPrecio.length}
          <p class="aviso dim">
            No incluye {sinPrecio.length} posición{sinPrecio.length === 1 ? '' : 'es'} sin precio cargado.
          </p>
        {/if}
      </section>
    {/if}

    <!-- Una tarjeta por familia. Todo junto en una lista mezclaba un CEDEAR en
         pesos con un bitcoin en dólares, que no se comparan entre sí ni se leen
         igual: la unidad de uno son acciones y la del otro decimales. -->
    {#each GRUPOS_POSICION as g}
      {#if g.items.length}
      <h2 class="lbl">{g.titulo}</h2>
      <ul class="list">
      {#each g.items as p}
        <li class="card">
          <button class="fila" onclick={() => abrir(p)}>
            <span class="txt">
              <b>{p.symbol}</b>
              <span class="sub dim">
                {Number(p.unidades).toFixed(Math.min(p.decimals, 8))} unidades
                {#if p.institution}<span class="sep">·</span>{p.institution}{/if}
                {#if p.fx_source}<span class="sep">·</span>al {p.fx_source.toUpperCase()}{/if}
                {#if !cotizaSola(p)}<span class="sep">·</span><span class="manual">a mano</span>{/if}
              </span>
            </span>
            <span class="der">
              {#if p.valor !== null}
                <b class="money">{money(p.valor, p.quote_currency)}</b>
                <span class="pct" class:pos={Number(p.ganancia) >= 0} class:neg={Number(p.ganancia) < 0}>
                  {Number(p.ganancia) >= 0 ? '+' : ''}{money(p.ganancia ?? 0, p.quote_currency)}
                </span>
              {:else}
                <!-- Sin precio no se inventa un número: se pide. -->
                <span class="dim sinp">sin precio</span>
              {/if}
            </span>
          </button>

          {#if abierta === p.account_id}
            <div class="panel stack">
              <label class="campo">
                <span>Precio de una unidad ({p.quote_currency})</span>
                <span class="row">
                  <input class="monto" inputmode="decimal" bind:value={precioRaw} />
                  <button class="btn-primary chico" onclick={() => actualizarPrecio(p)}
                          disabled={busy || !precioRaw}>Guardar</button>
                </span>
              </label>
              {#if !cotizaSola(p)}
                <!-- El motivo lo da el mismo módulo que decide quién cotiza, así
                     que no puede explicar algo distinto de lo que hace. -->
                <p class="dim sm nota">
                  Esta posición <b>no cotiza sola</b>: hay que cargarle el precio acá.
                  {porQueNoCotiza(p)}
                </p>
              {/if}
              {#if p.precio_al}
                <p class="dim sm nota">
                  Último precio del {shortDate(p.precio_al)}
                  {#if p.precio_fuente === 'manual'}· cargado a mano{/if}
                </p>
              {/if}

              <div class="row campos">
                <label class="campo"><span>Vender unidades</span>
                  <input class="monto" inputmode="decimal" bind:value={vUnidades}
                         placeholder={Number(p.unidades).toFixed(Math.min(p.decimals, 8))} />
                </label>
                <label class="campo"><span>Recibís</span>
                  <input class="monto" inputmode="decimal" bind:value={vMonto} />
                </label>
              </div>
              <label class="campo"><span>Entra en</span>
                <select bind:value={vHacia}>
                  {#each efectivo as c}<option value={c.account_id}>{c.name}</option>{/each}
                </select>
              </label>
              <button class="btn-primary" onclick={() => vender(p)}
                      disabled={busy || !vUnidades || !vMonto || !vHacia}>
                {busy ? 'Registrando…' : 'Registrar la venta'}
              </button>
              <p class="dim sm nota">
                Vender no cambia tu patrimonio: cambia de forma. La ganancia ya estaba
                contada mientras el precio subía.
              </p>
            </div>
          {/if}
        </li>
      {/each}
      </ul>
      {/if}
    {/each}

    <!-- El alta tiene pantalla propia, como la de cuentas. Desplegarla acá
         empujaba la lista media pantalla para abajo cada vez que la tocabas, y
         son dos momentos distintos: registrar algo y mirar cómo va. -->
    <a class="btn-primary nueva" href="/inversiones/nueva">+ Nueva inversión</a>
  {/if}
</div>

<style>
  .back { font-size: 1.5rem; text-decoration: none; }
  .rend { text-decoration: none; font-size: .86rem; font-weight: 600; white-space: nowrap; }
  .sm { font-size: .78rem; }

  .total .grande { font-size: 1.5rem; }
  .total .linea { margin-top: .45rem; font-size: .88rem; }
  .pct { font-size: .8rem; margin-left: .3rem; }
  .pf h2 { font-size: .95rem; margin: 0; }
  .pf .lista { list-style: none; margin: 0; padding: 0; display: grid; gap: .5rem; }
  .pf .txt { display: flex; flex-direction: column; gap: .1rem; }
  .aviso { margin: .7rem 0 0; font-size: .78rem; padding-top: .6rem; border-top: 1px solid var(--border); }

  .list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .4rem; }
  .list > li.card { padding: 0; overflow: hidden; }
  .fila {
    display: flex; align-items: center; justify-content: space-between; gap: .7rem;
    width: 100%; border: none; background: none; text-align: left;
    padding: .7rem .85rem; min-height: 58px;
  }
  .txt { display: flex; flex-direction: column; min-width: 0; gap: .12rem; }
  .txt b { font-size: 1rem; }
  .sub { font-size: .74rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sep { opacity: .5; }
  .der { display: flex; flex-direction: column; align-items: flex-end; gap: .1rem; flex-shrink: 0; }
  .der b { white-space: nowrap; }
  .sinp { font-size: .8rem; font-style: italic; }

  .panel { padding: .85rem; background: var(--surface-2); }
  .panel p { margin: 0; }
  .nota { margin-top: -.15rem; }
  .campos { gap: .5rem; align-items: flex-end; }
  .campos > .campo { flex: 1; }
  .campo .row { gap: .4rem; }
  .campo .row input { flex: 1; }
  .chico { min-height: 48px; padding: 0 .9rem; flex-shrink: 0; }
  .monto { text-align: right; }
  .manual { color: var(--warn); }
  .pf h2 { font-size: .95rem; margin: 0; }
  .pf .lista { list-style: none; margin: 0; padding: 0; display: grid; gap: .5rem; }
  .pf .txt { display: flex; flex-direction: column; gap: .1rem; }
  .aviso {
    margin: 0; padding: .65rem .8rem; border-radius: 10px; font-size: .82rem;
    background: color-mix(in srgb, var(--warn) 12%, transparent);
    border: 1px solid color-mix(in srgb, var(--warn) 35%, transparent);
  }
  .nueva { width: 100%; }
  h2 { font-size: .95rem; }
</style>
