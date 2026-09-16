<script lang="ts">
  import { onMount } from 'svelte';
  import { listBalances } from '$lib/ledger/api';
  import {
    listPosiciones, comprarActivo, venderActivo, guardarPrecio,
    rendimiento, TIPOS_ACTIVO, type Posicion
  } from '$lib/ledger/inversiones';
  import { money, today, shortDate } from '$lib/format';
  import Vacio from '$lib/Vacio.svelte';
  import type { AccountBalance } from '$lib/types';

  let posiciones = $state<Posicion[]>([]);
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
  let cNombre = $state('');
  let cKind = $state('crypto');
  let cMoneda = $state('USDT');
  let cDecimals = $state(8);
  let cDesde = $state<string | null>(null);
  let cMonto = $state('');
  let cUnidades = $state('');
  let cBroker = $state('');

  const num = (s: string) => Number(s.replace(/\./g, '').replace(',', '.')) || 0;
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
    try { [posiciones, cuentas] = await Promise.all([listPosiciones(), listBalances()]); }
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
        symbol: cSymbol, nombre: cNombre, kind: cKind, moneda: cMoneda,
        decimals: cDecimals, desdeId: cDesde, monto: num(cMonto),
        unidades: num(cUnidades), broker: cBroker.trim() || null, fecha: today()
      });
      cSymbol = ''; cNombre = ''; cMonto = ''; cUnidades = ''; comprando = false;
      await load();
    } catch (err) { error = err instanceof Error ? err.message : 'No se pudo comprar'; }
    finally { busy = false; }
  }

  onMount(load);
</script>

<div class="page stack">
  <div class="spread">
    <a href="/cuentas" class="back" aria-label="Volver">←</a>
    <h1>Inversiones</h1>
    <span></span>
  </div>

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

    <ul class="list">
      {#each posiciones as p}
        <li class="card">
          <button class="fila" onclick={() => abrir(p)}>
            <span class="txt">
              <b>{p.symbol}</b>
              <span class="sub dim">
                {Number(p.unidades).toFixed(Math.min(p.decimals, 8))} unidades
                {#if p.institution}<span class="sep">·</span>{p.institution}{/if}
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

    {#if comprando}
      <form class="card stack" onsubmit={comprar}>
        <h2>Registrar una compra</h2>
        <div class="row campos">
          <label class="campo"><span>Símbolo</span>
            <input bind:value={cSymbol} required placeholder="BTC" />
          </label>
          <label class="campo"><span>Tipo</span>
            <select bind:value={cKind}>
              {#each TIPOS_ACTIVO as t}<option value={t.id}>{t.label}</option>{/each}
            </select>
          </label>
        </div>
        <label class="campo"><span>Nombre (opcional)</span>
          <input bind:value={cNombre} placeholder="Bitcoin" />
        </label>
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
          <!-- ADR-010: el precio no se guarda, es el cociente. Se muestra para que
               puedas comprobar que no te equivocaste de orden de magnitud. -->
          <p class="resumen">
            Te quedó a <b class="money">{money(num(cMonto) / num(cUnidades), cMoneda)}</b> por unidad
          </p>
        {/if}
        <div class="row campos">
          <label class="campo"><span>Moneda de cotización</span>
            <input bind:value={cMoneda} required />
          </label>
          <label class="campo"><span>Dónde</span>
            <input bind:value={cBroker} placeholder="Binance" />
          </label>
        </div>
        <button class="btn-primary" type="submit" disabled={busy || !cSymbol.trim() || !cDesde}>
          Registrar la compra
        </button>
        <button type="button" class="link" onclick={() => (comprando = false)}>Cancelar</button>
      </form>
    {:else if posiciones.length}
      <button class="btn-primary nueva" onclick={() => (comprando = true)}>+ Registrar una compra</button>
    {/if}
  {/if}
</div>

<style>
  .back { font-size: 1.5rem; text-decoration: none; }
  h1 { font-size: 1.15rem; }
  .sm { font-size: .78rem; }

  .total .grande { font-size: 1.5rem; }
  .total .linea { margin-top: .45rem; font-size: .88rem; }
  .pct { font-size: .8rem; margin-left: .3rem; }
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
  .nueva { width: 100%; }
  .link { border: none; background: none; color: var(--accent); min-height: 38px; }
  h2 { font-size: .95rem; }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius); font-size: .88rem;
  }
</style>
