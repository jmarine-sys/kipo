<script lang="ts">
  import { onMount } from 'svelte';
  import { listBalances } from '$lib/ledger/api';
  import {
    listPosiciones, comprarActivo, venderActivo, guardarPrecio,
    rendimiento, TIPOS_ACTIVO, FAMILIAS_INVERSION, etiquetaDeKind, familiaDe,
    type Posicion
  } from '$lib/ledger/inversiones';
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

  let comprando = $state(false);
  let cSymbol = $state('');
  let cKind = $state('crypto');
  let familia = $state<'bursatil' | 'cripto' | null>(null);

  const familiaElegida = $derived(FAMILIAS_INVERSION.find((f) => f.id === familia) ?? null);

  /** Las posiciones separadas por familia, en el mismo orden que el alta. */
  const GRUPOS_POSICION = $derived([
    { id: 'bursatil', titulo: 'Bursátil',
      items: posiciones.filter((p) => familiaDe(p.kind) === 'bursatil') },
    { id: 'cripto', titulo: 'Cripto',
      items: posiciones.filter((p) => familiaDe(p.kind) === 'cripto') }
  ]);

  /** Elegir la familia fija lo que esa familia ya sabe: el tipo y la moneda. */
  function elegirFamilia(id: 'bursatil' | 'cripto') {
    familia = id;
    const f = FAMILIAS_INVERSION.find((x) => x.id === id);
    cKind = f?.kinds?.[0] ?? 'crypto';
    cMoneda = f?.moneda ?? 'ARS';
  }
  let cMoneda = $state('USDT');
  let cDecimals = $state(8);
  let cDesde = $state<string | null>(null);
  let cMonto = $state('');
  let cUnidades = $state('');
  let cBroker = $state('');
  let cRatio = $state('');
  let cSubyacente = $state('');

  const efectivo = $derived(cuentas.filter((c) => c.valuation === 'balance' && c.kind === 'asset'));

  /**
   * Si esta posición recibe precio automático.
   *
   * Tiene que decir lo MISMO que `scripts/precios.mjs`, que es quien de verdad
   * los trae. Si las dos reglas se separan, la pantalla miente: dice "cotiza
   * sola" sobre algo que nadie va a cotizar.
   */
  function cotizaSola(p: Posicion) {
    if (p.kind === 'crypto') return p.quote_currency === 'USD' || p.quote_currency === 'USDT';
    if (['cedear', 'stock', 'etf'].includes(p.kind)) {
      return p.quote_currency === 'ARS' && !!(p.underlying_symbol ?? p.symbol);
    }
    return false;
  }

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

  async function comprar(e: SubmitEvent) {
    e.preventDefault();
    if (!cDesde) return;
    busy = true; error = null;
    try {
      await comprarActivo({
        // El nombre ya no se pide: el ticker lo es. Se manda igual porque la
        // función lo exige, y duplicarlo acá no puede discrepar.
        symbol: cSymbol, nombre: cSymbol.trim().toUpperCase(), kind: cKind, moneda: cMoneda,
        decimals: cDecimals, desdeId: cDesde, monto: num(cMonto),
        unidades: num(cUnidades), broker: cBroker.trim() || null, fecha: today(),
        ratio: cKind === 'cedear' && cRatio ? num(cRatio) : null,
        subyacente: cKind === 'cedear' ? (cSubyacente.trim() || null) : null
      });
      cSymbol = ''; cMonto = ''; cUnidades = ''; comprando = false;
      await load();
    } catch (err) { error = err instanceof Error ? err.message : 'No se pudo comprar'; }
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
  {:else if !posiciones.length && !comprando}
    <Vacio titulo="Todavía no registraste ninguna inversión."
           detalle="Cripto, CEDEARs, acciones o fondos: todo lo que se valúe por unidades y precio."
           accion="Registrar la primera" onaccion={() => (comprando = true)} />
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
                <p class="dim sm nota">
                  Esta posición <b>no cotiza sola</b>: hay que cargarle el precio acá.
                  {#if p.kind === 'cedear'}
                    Le falta el símbolo de la acción que representa, que es con el que
                    se le pide el precio a BYMA.
                  {:else}
                    No hay fuente automática configurada para {p.kind} en {p.quote_currency}.
                  {/if}
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

    {#if comprando}
      <form class="card stack" onsubmit={comprar}>
        <h2>Registrar una inversión</h2>

        <!-- Las tres familias en un solo lugar. El plazo fijo era un botón
             suelto arriba y la compra otro abajo, así que «invertir» se hacía de
             dos maneras según en qué invirtieras. -->
        <div class="familias">
          {#each FAMILIAS_INVERSION as f}
            {#if f.ruta}
              <a class="opcion" href={f.ruta}>
                {f.label}<span class="dim sm">{f.pista}</span>
              </a>
            {:else}
              <button type="button" class="opcion" class:on={familia === f.id}
                      onclick={() => elegirFamilia(f.id as 'bursatil' | 'cripto')}>
                {f.label}<span class="dim sm">{f.pista}</span>
              </button>
            {/if}
          {/each}
        </div>

        {#if familiaElegida}
          {#if (familiaElegida.kinds?.length ?? 0) > 1}
            <fieldset>
              <legend class="dim">Qué es</legend>
              <div class="wrap">
                {#each familiaElegida.kinds ?? [] as k}
                  <button type="button" class="chip" class:on={cKind === k}
                          onclick={() => (cKind = k)}>{etiquetaDeKind(k)}</button>
                {/each}
              </div>
            </fieldset>
          {/if}

          <div class="row campos">
            <!-- Sin «Nombre»: para eso está el ticker. Pedir las dos cosas era
                 pedir dos veces lo mismo y dejar que discrepen. -->
            <label class="campo"><span>Símbolo</span>
              <input bind:value={cSymbol} required maxlength="12"
                     placeholder={familia === 'cripto' ? 'BTC' : 'AAPL'} />
            </label>
            <label class="campo"><span>Moneda</span>
              <input bind:value={cMoneda} required maxlength="6" />
            </label>
          </div>

          <label class="campo"><span>Sale de</span>
            <select bind:value={cDesde} required>
              <option value={null} disabled>Elegí una cuenta</option>
              {#each efectivo as c}<option value={c.account_id}>{c.name} · {money(c.balance, c.unit)}</option>{/each}
            </select>
          </label>

          <div class="row campos">
            <label class="campo"><span>Cuánto pagaste</span>
              <input class="monto" inputmode="decimal" bind:value={cMonto} required />
            </label>
            <label class="campo"><span>Cuántas unidades</span>
              <input class="monto" inputmode="decimal" bind:value={cUnidades} required />
            </label>
          </div>

          {#if num(cMonto) && num(cUnidades)}
            <!-- ADR-010: el precio no se guarda, es el cociente. Se muestra para
                 que puedas comprobar que no te equivocaste de orden de magnitud. -->
            <p class="resumen">
              Te quedó a <b class="money">{money(num(cMonto) / num(cUnidades), cMoneda)}</b> por unidad
            </p>
          {/if}

          <label class="campo"><span>Dónde</span>
            <input bind:value={cBroker} maxlength="24"
                   placeholder={familia === 'cripto' ? 'Binance' : 'Balanz'} />
          </label>

          {#if cKind === 'cedear'}
            <div class="row campos">
              <label class="campo"><span>Ratio</span>
                <input class="monto" inputmode="decimal" bind:value={cRatio} placeholder="20" />
              </label>
              <label class="campo"><span>Acción que representa</span>
                <input bind:value={cSubyacente} placeholder="AAPL" required />
              </label>
            </div>
            <p class="aviso">
              Se mide al <b>contado con liqui</b>: el precio en pesos ya lo lleva
              adentro, y usarlo separa lo que rindió la acción de lo que se movió
              el dólar. El símbolo de la acción es además con lo que se le pide el
              precio a la fuente — sin él, hay que cargarlo a mano.
            </p>
          {/if}

          <button class="btn-primary" type="submit" disabled={busy || !cSymbol.trim() || !cDesde}>
            Registrar la compra
          </button>
        {/if}

        <button type="button" class="link" onclick={() => (comprando = false)}>Cancelar</button>
      </form>
    {:else}
      <button class="btn-primary nueva" onclick={() => (comprando = true)}>+ Nueva inversión</button>
    {/if}
  {/if}
</div>

<style>
  .back { font-size: 1.5rem; text-decoration: none; }
  .rend { text-decoration: none; font-size: .86rem; font-weight: 600; white-space: nowrap; }
  .sm { font-size: .78rem; }

  .total .grande { font-size: 1.5rem; }
  .total .linea { margin-top: .45rem; font-size: .88rem; }
  .pct { font-size: .8rem; margin-left: .3rem; }
  .familias { display: grid; gap: .5rem; }
  .opcion {
    display: flex; flex-direction: column; align-items: flex-start; gap: .15rem;
    padding: .7rem .85rem; min-height: var(--tap); text-align: left;
    border: 1px solid var(--border); border-radius: var(--radius);
    background: var(--surface); color: inherit; text-decoration: none;
  }
  .opcion.on { border-color: var(--accent); background: color-mix(in srgb, var(--accent) 12%, var(--surface)); }
  fieldset { border: none; padding: 0; margin: 0; }
  legend { font-size: .85rem; margin-bottom: .35rem; }
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
  .resumen { margin: 0; padding: .65rem .8rem; border-radius: 10px; background: var(--surface-2); font-size: .86rem; }
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
  .link { border: none; background: none; color: var(--accent); min-height: 38px; }
  h2 { font-size: .95rem; }
</style>
