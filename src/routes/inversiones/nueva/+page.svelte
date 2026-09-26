<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { listBalances } from '$lib/ledger/api';
  import {
    comprarActivo, crearPlazoFijo, tasaImplicita, diasEntre,
    FAMILIAS_INVERSION, etiquetaDeKind
  } from '$lib/ledger/inversiones';
  import { money, today, num } from '$lib/format';
  import type { AccountBalance } from '$lib/types';

  /**
   * Registrar una inversión — pantalla propia, como `/cuentas/nueva`.
   *
   * Estuvo un rato desplegándose dentro de «Lo que tenés», y ahí competía con lo
   * que esa pantalla tiene que contestar: cuánto tengo y cuánto rinde. Un alta y
   * una lista son dos momentos distintos, y mezclarlos hacía que la lista se
   * empujara media pantalla para abajo cada vez que tocabas el botón.
   *
   * Lo que SÍ se conserva de esa vuelta es que las tres familias se eligen en el
   * mismo lugar y con el mismo trato. El problema nunca fue que el alta tuviera
   * pantalla: fue que el plazo fijo tenía una distinta de las otras dos.
   */
  type Familia = (typeof FAMILIAS_INVERSION)[number]['id'];

  let cuentas = $state<AccountBalance[]>([]);
  let error = $state<string | null>(null);
  let busy = $state(false);
  let familia = $state<Familia | null>(null);

  const familiaElegida = $derived(FAMILIAS_INVERSION.find((f) => f.id === familia) ?? null);

  // De dónde sale la plata: lo compartido entre las tres familias.
  let desde = $state<string | null>(null);
  const efectivo = $derived(cuentas.filter((c) => c.valuation === 'balance' && c.kind === 'asset'));
  /** La cuenta con la que se paga es la que dice en qué moneda está el monto. */
  const origen = $derived(efectivo.find((c) => c.account_id === desde) ?? null);

  // --- Compra de un activo que cotiza ---------------------------------------
  let cSymbol = $state('');
  let cKind = $state('crypto');
  let cMoneda = $state('USDT');
  let cDecimals = $state(8);
  let cMonto = $state('');
  let cUnidades = $state('');
  let cBroker = $state('');
  let cRatio = $state('');
  let cSubyacente = $state('');

  // --- Plazo fijo -----------------------------------------------------------
  let pfNombre = $state('');
  let pfCapital = $state('');
  let pfEsperado = $state('');
  let pfVence = $state('');
  let pfDonde = $state('');

  const pfDias = $derived(pfVence ? diasEntre(today(), pfVence) : 0);
  const pfInteres = $derived(num(pfEsperado) > num(pfCapital) ? num(pfEsperado) - num(pfCapital) : 0);
  const pfTna = $derived(tasaImplicita(num(pfCapital), num(pfEsperado), pfDias));
  const pfListo = $derived(
    !!pfNombre.trim() && !!desde && num(pfCapital) > 0 &&
    num(pfEsperado) > num(pfCapital) && pfDias > 0
  );

  /** Elegir la familia fija lo que esa familia ya sabe: el tipo y en qué cotiza. */
  function elegirFamilia(id: Familia) {
    familia = id;
    error = null;
    const f = FAMILIAS_INVERSION.find((x) => x.id === id);
    cKind = f?.kinds?.[0] ?? 'crypto';
    cMoneda = f?.monedas?.[0] ?? 'ARS';
  }

  async function comprar(e: SubmitEvent) {
    e.preventDefault();
    if (!desde) return;
    busy = true; error = null;
    try {
      await comprarActivo({
        // El nombre ya no se pide: el ticker lo es. Se manda igual porque la
        // función lo exige, y duplicarlo acá no puede discrepar.
        symbol: cSymbol, nombre: cSymbol.trim().toUpperCase(), kind: cKind, moneda: cMoneda,
        decimals: cDecimals, desdeId: desde, monto: num(cMonto),
        unidades: num(cUnidades), broker: cBroker.trim() || null, fecha: today(),
        ratio: cKind === 'cedear' && cRatio ? num(cRatio) : null,
        subyacente: cKind === 'cedear' ? (cSubyacente.trim() || null) : null
      });
      goto('/inversiones');
    } catch (err) {
      error = err instanceof Error ? err.message : 'No se pudo comprar';
      busy = false;
    }
  }

  /**
   * Constituir un plazo fijo.
   *
   * Es otra función de base que la compra —crea la cuenta, mueve el capital y
   * agenda el vencimiento de una vez (ADR-014, ADR-016)— pero es el mismo acto:
   * poner plata a rendir. Por eso comparte el selector de familia y la cuenta de
   * origen, y no la pantalla entera.
   */
  async function crearPF(e: SubmitEvent) {
    e.preventDefault();
    if (!pfListo || !desde) return;
    busy = true; error = null;
    try {
      await crearPlazoFijo({
        nombre: pfNombre.trim(), desdeId: desde, capital: num(pfCapital),
        vence: pfVence, esperado: num(pfEsperado),
        institucion: pfDonde.trim() || null, fecha: today()
      });
      goto('/inversiones');
    } catch (err) {
      error = err instanceof Error ? err.message : 'No se pudo constituir';
      busy = false;
    }
  }

  onMount(async () => {
    try { cuentas = await listBalances(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo cargar'; }
  });
</script>

<div class="page stack">
  <div class="spread">
    <a href="/inversiones" class="back" aria-label="Volver">←</a>
    <h1>Nueva inversión</h1>
    <span></span>
  </div>

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  <!-- Las tres familias con el mismo trato, como los tres tipos de cuenta. -->
  <div class="opts">
    {#each FAMILIAS_INVERSION as f}
      <button type="button" class:on={familia === f.id}
              onclick={() => elegirFamilia(f.id)}>
        {f.label}<span class="dim sm">{f.pista}</span>
      </button>
    {/each}
  </div>

  {#if familia === 'plazo'}
    <form class="card stack" onsubmit={crearPF}>
      <label class="campo"><span>Cómo lo llamás</span>
        <input bind:value={pfNombre} required maxlength="36" placeholder="Plazo fijo 90 días" />
      </label>

      <label class="campo"><span>Sale de</span>
        <select bind:value={desde} required>
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
        <!-- La tasa no se guarda: se deduce de capital, monto final y plazo. Es
             el número con el que se comparan las ofertas, así que conviene verlo
             mientras se carga, no después. -->
        <p class="resumen">
          Ganás <b class="money pos">{money(pfInteres, origen?.unit ?? 'ARS')}</b> en {pfDias} días
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
    <form class="card stack" onsubmit={comprar}>
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

      <!-- Sin «Nombre»: para eso está el ticker. Pedir las dos cosas era pedir
           dos veces lo mismo y dejar que discrepen. -->
      <label class="campo"><span>Símbolo</span>
        <input bind:value={cSymbol} required maxlength="12"
               placeholder={familia === 'cripto' ? 'BTC' : 'AAPL'} />
      </label>

      <!-- EN QUÉ COTIZA, que no es con qué pagás. Era un campo de texto libre
           llamado «Moneda» pegado al símbolo, y ahí se leía como la moneda de la
           operación. Escribir «usdt» en minúscula o «dolares» creaba un
           instrumento que ninguna fuente iba a cotizar nunca. -->
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
        <select bind:value={desde} required>
          <option value={null} disabled>Elegí una cuenta</option>
          {#each efectivo as c}<option value={c.account_id}>{c.name} · {money(c.balance, c.unit)}</option>{/each}
        </select>
      </label>

      <div class="row campos">
        <label class="campo"><span>Cuánto pagaste{#if origen} ({origen.unit}){/if}</span>
          <input class="monto" inputmode="decimal" bind:value={cMonto} required />
        </label>
        <label class="campo"><span>Cuántas unidades</span>
          <input class="monto" inputmode="decimal" bind:value={cUnidades} required />
        </label>
      </div>

      {#if num(cMonto) && num(cUnidades)}
        <!-- ADR-010: el precio no se guarda, es el cociente. Se muestra para que
             puedas comprobar que no te equivocaste de orden de magnitud. Va en la
             moneda de la CUENTA, que es en la que está el monto. -->
        <p class="resumen">
          Te quedó a
          <b class="money">{money(num(cMonto) / num(cUnidades), origen?.unit ?? cMoneda)}</b>
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
          adentro, y usarlo separa lo que rindió la acción de lo que se movió el
          dólar. El símbolo de la acción es además con lo que se le pide el precio
          a la fuente — sin él, hay que cargarlo a mano.
        </p>
      {/if}

      <button class="btn-primary" type="submit" disabled={busy || !cSymbol.trim() || !desde}>
        {busy ? 'Registrando…' : 'Registrar la compra'}
      </button>
    </form>
  {:else}
    <p class="dim sm">Elegí qué estás registrando.</p>
  {/if}
</div>

<style>
  .back { font-size: 1.5rem; text-decoration: none; }
  .sm { font-size: .78rem; }
  fieldset { border: none; padding: 0; margin: 0; }
  legend { font-size: .85rem; margin-bottom: .35rem; }
  .campo { display: flex; flex-direction: column; gap: .3rem; }
  .campo > span:first-child { font-size: .78rem; color: var(--text-dim); }
  .campos { gap: .5rem; align-items: flex-end; }
  .campos > .campo { flex: 1; }
  .monto { text-align: right; }
  .resumen { margin: 0; padding: .65rem .8rem; border-radius: 10px; background: var(--surface-2); font-size: .86rem; }
  .aviso { margin: 0; font-size: .78rem; padding-top: .6rem; border-top: 1px solid var(--border); }
  .nota { margin: 0; }
</style>
