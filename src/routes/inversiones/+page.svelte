<script lang="ts">
  import { onMount } from 'svelte';
  import { listBalances } from '$lib/ledger/api';
  import {
    listPosiciones, comprarActivo, venderActivo, guardarPrecio,
    rendimiento, TIPOS_ACTIVO, FAMILIAS_INVERSION, etiquetaDeKind, familiaDe,
    crearPlazoFijo, tasaImplicita, diasEntre,
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

  type Familia = (typeof FAMILIAS_INVERSION)[number]['id'];

  let comprando = $state(false);
  let cSymbol = $state('');
  let cKind = $state('crypto');
  let familia = $state<Familia | null>(null);

  const familiaElegida = $derived(FAMILIAS_INVERSION.find((f) => f.id === familia) ?? null);

  /** Las posiciones separadas por familia, en el mismo orden que el alta. */
  const GRUPOS_POSICION = $derived([
    { id: 'bursatil', titulo: 'Bursátil',
      items: posiciones.filter((p) => familiaDe(p.kind) === 'bursatil') },
    { id: 'cripto', titulo: 'Cripto',
      items: posiciones.filter((p) => familiaDe(p.kind) === 'cripto') }
  ]);

  /** Elegir la familia fija lo que esa familia ya sabe: el tipo y en qué cotiza. */
  function elegirFamilia(id: Familia) {
    familia = id;
    error = null;
    const f = FAMILIAS_INVERSION.find((x) => x.id === id);
    cKind = f?.kinds?.[0] ?? 'crypto';
    cMoneda = f?.monedas?.[0] ?? 'ARS';
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

  /** La cuenta con la que se paga: es la que dice en qué moneda está el monto. */
  const cuentaOrigen = $derived(efectivo.find((c) => c.account_id === cDesde) ?? null);

  // --- Plazo fijo ---------------------------------------------------------
  // Vivía en /inversiones/plazo-fijo, una pantalla aparte. Los tres botones
  // prometían tres formularios y el tercero era una mudanza.
  let pfNombre = $state('');
  let pfCapital = $state('');
  let pfEsperado = $state('');
  let pfVence = $state('');
  let pfDonde = $state('');

  const pfOrigen = $derived(efectivo.find((c) => c.account_id === cDesde) ?? null);
  const pfDias = $derived(pfVence ? diasEntre(today(), pfVence) : 0);
  const pfInteres = $derived(num(pfEsperado) > num(pfCapital) ? num(pfEsperado) - num(pfCapital) : 0);
  const pfTna = $derived(tasaImplicita(num(pfCapital), num(pfEsperado), pfDias));
  const pfListo = $derived(
    !!pfNombre.trim() && !!cDesde && num(pfCapital) > 0 &&
    num(pfEsperado) > num(pfCapital) && pfDias > 0
  );

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
      cSymbol = ''; cMonto = ''; cUnidades = '';
      cerrar();
      await load();
    } catch (err) { error = err instanceof Error ? err.message : 'No se pudo comprar'; }
    finally { busy = false; }
  }

  /**
   * Constituir un plazo fijo, desde esta misma pantalla.
   *
   * Es otra función de base que la compra —crea la cuenta, mueve el capital y
   * agenda el vencimiento de una vez (ADR-014, ADR-016)— pero es el mismo acto:
   * poner plata a rendir. Por eso comparte el selector de familia y la cuenta de
   * origen, y no la pantalla entera.
   */
  async function crearPF(e: SubmitEvent) {
    e.preventDefault();
    if (!pfListo || !cDesde) return;
    busy = true; error = null;
    try {
      await crearPlazoFijo({
        nombre: pfNombre.trim(), desdeId: cDesde, capital: num(pfCapital),
        vence: pfVence, esperado: num(pfEsperado),
        institucion: pfDonde.trim() || null, fecha: today()
      });
      pfNombre = ''; pfCapital = ''; pfEsperado = ''; pfVence = '';
      cerrar();
      await load();
    } catch (err) {
      error = err instanceof Error ? err.message : 'No se pudo constituir';
    } finally { busy = false; }
  }

  /** Cerrar el alta vuelve a dejar los tres botones sin elegir. */
  function cerrar() {
    comprando = false;
    familia = null;
    error = null;
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
  {:else if !posiciones.length && !plazos.length && !comprando}
    <!-- Los plazos fijos cuentan. Se constituyen desde esta misma pantalla, así
         que sin ellos en la condición el primero que cargabas te dejaba mirando
         su tarjeta arriba y "todavía no registraste ninguna inversión" abajo. -->
    <Vacio titulo="Todavía no registraste ninguna inversión."
           detalle="Un plazo fijo, cripto, CEDEARs, acciones o fondos."
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

    {#if comprando}
      <section class="card stack">
        <h2>Registrar una inversión</h2>

        <!-- Las tres familias en un solo lugar Y con el mismo trato. El plazo
             fijo elegía acá y se iba a otra pantalla, así que de los tres
             botones dos abrían un formulario y el tercero mudaba. -->
        <div class="familias">
          {#each FAMILIAS_INVERSION as f}
            <button type="button" class="opcion" class:on={familia === f.id}
                    onclick={() => elegirFamilia(f.id)}>
              {f.label}<span class="dim sm">{f.pista}</span>
            </button>
          {/each}
        </div>

        {#if familia === 'plazo'}
          <form class="stack" onsubmit={crearPF}>
            <label class="campo"><span>Cómo lo llamás</span>
              <input bind:value={pfNombre} required maxlength="36" placeholder="Plazo fijo 90 días" />
            </label>

            <label class="campo"><span>Sale de</span>
              <select bind:value={cDesde} required>
                <option value={null} disabled>Elegí una cuenta</option>
                {#each efectivo as c}<option value={c.account_id}>{c.name} · {money(c.balance, c.unit)}</option>{/each}
              </select>
            </label>

            <div class="row campos">
              <label class="campo"><span>Cuánto ponés</span>
                <input class="monto" inputmode="decimal" bind:value={pfCapital} required placeholder="1000000" />
              </label>
              <label class="campo"><span>Vence el</span>
                <input type="date" bind:value={pfVence} required min={today()} />
              </label>
            </div>

            <label class="campo"><span>Cuánto vuelve al vencimiento</span>
              <input class="monto" inputmode="decimal" bind:value={pfEsperado} required placeholder="1090000" />
            </label>

            <label class="campo"><span>Dónde</span>
              <input bind:value={pfDonde} maxlength="24" placeholder="Santander" />
            </label>

            {#if pfInteres && pfDias > 0}
              <!-- La tasa no se guarda: se deduce de capital, monto final y plazo.
                   Es el número con el que se comparan las ofertas, así que
                   conviene verlo mientras se carga, no después. -->
              <p class="resumen">
                Ganás <b class="money pos">{money(pfInteres, pfOrigen?.unit ?? 'ARS')}</b> en {pfDias} días
                {#if pfTna}· equivale a una tasa anual de <b>{pfTna.toFixed(1)}%</b>{/if}
              </p>
            {/if}

            <button class="btn-primary" type="submit" disabled={busy || !pfListo}>
              {busy ? 'Constituyendo…' : 'Constituir'}
            </button>
            <p class="dim sm nota">
              La plata sale de tu cuenta y queda inmovilizada: tu patrimonio no cambia,
              pero baja lo disponible. El día del vencimiento aparece en la
              <a href="/recurrentes">Agenda</a> para registrar la vuelta.
            </p>
          </form>
        {:else if familiaElegida}
          <form class="stack" onsubmit={comprar}>
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

            <!-- Sin «Nombre»: para eso está el ticker. Pedir las dos cosas era
                 pedir dos veces lo mismo y dejar que discrepen. -->
            <label class="campo"><span>Símbolo</span>
              <input bind:value={cSymbol} required maxlength="12"
                     placeholder={familia === 'cripto' ? 'BTC' : 'AAPL'} />
            </label>

            <!-- EN QUÉ COTIZA, que no es con qué pagás. Era un campo de texto
                 libre llamado «Moneda» pegado al símbolo, y ahí se leía como la
                 moneda de la operación. Escribir «usdt» en minúscula o «dolares»
                 creaba un instrumento que ninguna fuente iba a cotizar nunca. -->
            {#if (familiaElegida.monedas?.length ?? 0) > 1}
              <fieldset>
                <legend class="dim">En qué cotiza</legend>
                <div class="wrap">
                  {#each familiaElegida.monedas ?? [] as m}
                    <button type="button" class="chip" class:on={cMoneda === m}
                            onclick={() => (cMoneda = m)}>{m}</button>
                  {/each}
                </div>
                <p class="dim sm nota">
                  La moneda del <b>precio</b>, no la de la cuenta con la que pagás:
                  un CEDEAR cotiza en pesos aunque lo pagues con dólares del broker.
                </p>
              </fieldset>
            {/if}

            <label class="campo"><span>Sale de</span>
              <select bind:value={cDesde} required>
                <option value={null} disabled>Elegí una cuenta</option>
                {#each efectivo as c}<option value={c.account_id}>{c.name} · {money(c.balance, c.unit)}</option>{/each}
              </select>
            </label>

            <div class="row campos">
              <label class="campo"><span>Cuánto pagaste{#if cuentaOrigen} ({cuentaOrigen.unit}){/if}</span>
                <input class="monto" inputmode="decimal" bind:value={cMonto} required />
              </label>
              <label class="campo"><span>Cuántas unidades</span>
                <input class="monto" inputmode="decimal" bind:value={cUnidades} required />
              </label>
            </div>

            {#if num(cMonto) && num(cUnidades)}
              <!-- ADR-010: el precio no se guarda, es el cociente. Se muestra para
                   que puedas comprobar que no te equivocaste de orden de magnitud.
                   Va en la moneda de la CUENTA, que es en la que está el monto:
                   decía `cMoneda` y eso etiquetaba pesos como dólares cada vez
                   que las dos monedas no coincidían. -->
              <p class="resumen">
                Te quedó a
                <b class="money">{money(num(cMonto) / num(cUnidades), cuentaOrigen?.unit ?? cMoneda)}</b>
                por unidad
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
          </form>
        {/if}

        <button type="button" class="link" onclick={cerrar}>Cancelar</button>
      </section>
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
    background: var(--surface); color: inherit;
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
