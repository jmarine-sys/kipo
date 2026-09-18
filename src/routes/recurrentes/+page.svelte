<script lang="ts">
  import { onMount } from 'svelte';
  import { listAccounts, listCategories } from '$lib/ledger/api';
  import {
    listUpcoming, createScheduled, archiveScheduled, registerScheduled,
    skipScheduled, updateScheduled, nombreFrecuencia, cuandoFalta,
    FRECUENCIAS, type Upcoming, type Frecuencia
  } from '$lib/ledger/recurrentes';
  import { colorCategoria } from '$lib/categorias';
  import { registrarVencimiento } from '$lib/ledger/inversiones';
  import { money, today, shortDate, num, esDeEsteMes } from '$lib/format';
  import Vacio from '$lib/Vacio.svelte';
  import type { Account, Category } from '$lib/types';

  let items = $state<Upcoming[]>([]);
  let cuentas = $state<Account[]>([]);
  let categorias = $state<Category[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);
  let busy = $state(false);

  let abierto = $state<string | null>(null);
  let montoRaw = $state('');
  let cuentaElegida = $state<string | null>(null);

  let nCat = $state<string | null>(null);
  let nCuenta = $state<string | null>(null);
  let nFrec = $state<Frecuencia>('monthly');


  const pagables = $derived(cuentas.filter((a) => a.valuation === 'balance'));
  const hojas = $derived(
    categorias.filter((c) => c.kind === 'expense' && !categorias.some((x) => x.parent_id === c.id))
  );
  const vencidos = $derived(items.filter((i) => i.vencido));

  /**
   * Este mes y el resto, en tarjetas distintas — OD-45.
   *
   * Estaban todos juntos bajo «Próximos», así que un seguro que se paga en tres
   * meses ocupaba el mismo lugar que el alquiler de pasado mañana. Lo que hay
   * que hacer AHORA tiene que poder leerse sin filtrar con la vista.
   */
  const esteMes = $derived(items.filter((i) => !i.vencido && esDeEsteMes(i.next_on)));
  const masAdelante = $derived(items.filter((i) => !i.vencido && !esDeEsteMes(i.next_on)));

  /** Lo de más adelante arranca cerrado: verlo siempre es ruido. */
  let verMasAdelante = $state(false);

  let nuevaFecha = $state('');
  let nuevoMonto = $state('');

  async function guardarRegla(i: Upcoming) {
    busy = true; error = null;
    try {
      await updateScheduled(i.id, {
        next_on: nuevaFecha || i.next_on,
        amount: nuevoMonto ? num(nuevoMonto) : null
      });
      abierto = null;
      await load();
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo cambiar la regla';
    } finally { busy = false; }
  }

  /**
   * Lo de ESTE mes, y separado por sentido — OD-45.
   *
   * Decía «en los próximos 30 días», que a fin de mes mete cosas del que viene,
   * y sumaba TODO junto: un plazo fijo que vence es plata que ENTRA y estaba
   * contado como si fuera un gasto más. El número decía que te iban a sacar
   * justo lo que te iban a dar.
   */
  const delMes = $derived(
    items.filter((i) => (i.vencido || esDeEsteMes(i.next_on)) &&
                        i.currency === 'ARS' && i.amount !== null)
  );
  const aPagar  = $derived(delMes.filter((i) => i.kind === 'recurring')
                                 .reduce((t, i) => t + Number(i.amount), 0));
  const aCobrar = $derived(delMes.filter((i) => i.kind === 'maturity')
                                 .reduce((t, i) => t + Number(i.amount), 0));
  const variables = $derived(
    items.filter((i) => (i.vencido || esDeEsteMes(i.next_on)) && i.amount === null).length
  );

  function abrir(i: Upcoming) {
    if (abierto === i.id) { abierto = null; return; }
    abierto = i.id;
    montoRaw = i.amount ? String(Math.round(Number(i.amount))) : '';
    // en un vencimiento la cuenta es a DÓNDE vuelve, no de dónde sale
    cuentaElegida = i.kind === 'maturity' ? i.counter_account_id : i.account_id;
    error = null;
  }

  /** En un vencimiento, el interés es lo que vuelve menos lo que hay puesto. */
  const interesDelVencimiento = $derived.by(() => {
    const i = items.find((x) => x.id === abierto);
    if (!i || i.kind !== 'maturity' || !i.capital) return null;
    const total = montoRaw ? num(montoRaw) : Number(i.amount ?? 0);
    return total - Number(i.capital);
  });

  async function load() {
    loading = true;
    try {
      [items, cuentas, categorias] = await Promise.all([
        listUpcoming(), listAccounts(), listCategories()
      ]);
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo cargar';
    } finally { loading = false; }
  }

  /**
   * Un vencimiento no es un gasto recurrente: vuelve capital MÁS interés, y el
   * interés no se pide, se calcula. Por eso tiene su propio camino.
   */
  async function vencer(i: Upcoming) {
    busy = true; error = null;
    try {
      await registrarVencimiento(i.id, {
        total: montoRaw ? num(montoRaw) : null,
        haciaId: cuentaElegida
      });
      abierto = null;
      await load();
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo registrar';
    } finally { busy = false; }
  }

  async function registrar(i: Upcoming) {
    busy = true; error = null;
    try {
      await registerScheduled(i.id, {
        amount: montoRaw ? num(montoRaw) : null,
        accountId: cuentaElegida
      });
      abierto = null;
      await load();
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo registrar';
    } finally { busy = false; }
  }

  async function saltear(i: Upcoming) {
    if (!confirm(`¿Saltear este período de "${i.description}"? No se registra ningún movimiento.`)) return;
    busy = true; error = null;
    try { await skipScheduled(i.id); abierto = null; await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo saltear'; }
    finally { busy = false; }
  }

  async function archivar(i: Upcoming) {
    if (!confirm(`¿Archivar "${i.description}"? Los movimientos ya registrados quedan intactos.`)) return;
    busy = true;
    try { await archiveScheduled(i.id); abierto = null; await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo archivar'; }
    finally { busy = false; }
  }




  onMount(load);
</script>

<div class="page stack">
  <!-- Sin flecha de volver: es un destino de la barra, no una subpantalla. -->
  <h1>Lo que se viene</h1>

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  {#if loading}
    <p class="dim">Cargando…</p>
  {:else}
    {#if aPagar > 0 || aCobrar > 0}
      <p class="proyeccion">
        Este mes
        {#if aPagar > 0}
          pagás <b class="money neg">{money(aPagar)}</b>
        {/if}
        {#if aPagar > 0 && aCobrar > 0}<span class="sep">·</span>{/if}
        {#if aCobrar > 0}
          cobrás <b class="money pos">{money(aCobrar)}</b>
        {/if}
        {#if variables}
          <span class="dim sm">
            · más {variables} de importe variable, que no se puede anticipar
          </span>
        {/if}
      </p>
    {/if}

    {#each [{ t: 'Vencidos', l: vencidos }, { t: 'Este mes', l: esteMes }] as grupo}
      {#if grupo.l.length}
        <h2 class="lbl">{grupo.t}</h2>
        <ul class="list">
          {#each grupo.l as i}
            <li class="card" class:alerta={i.vencido}>
              <button class="fila" onclick={() => abrir(i)}>
                <span class="txt">
                  <b>{i.description}</b>
                  <span class="sub dim">
                    {#if i.category_parent}
                      <i class="punto" style="background:{colorCategoria(i.category_parent)}"></i>
                    {/if}
                    {#if i.kind === 'maturity'}
                      inversión<span class="sep">·</span>{i.account_name ?? '—'}
                    {:else}
                      {i.category_name ?? '—'}
                      <span class="sep">·</span>{nombreFrecuencia(i.frequency)}
                      {#if i.account_name}<span class="sep">·</span>{i.account_name}{/if}
                    {/if}
                  </span>
                </span>
                <span class="der">
                  <b class="money">{i.amount ? money(i.amount, i.currency) : 'variable'}</b>
                  <span class="cuando" class:venc={i.vencido}>{cuandoFalta(i.dias)}</span>
                </span>
              </button>

              {#if abierto === i.id && i.kind === 'maturity'}
                <div class="panel stack">
                  <p class="dim sm nota">
                    Hay <b class="money">{money(i.capital ?? 0, i.currency)}</b> puestos.
                    Al registrarlo, el capital vuelve y el interés se anota como ingreso.
                  </p>
                  <div class="row campos">
                    <label class="campo">
                      <span>Cuánto volvió</span>
                      <input class="monto" inputmode="decimal" bind:value={montoRaw} />
                    </label>
                    <label class="campo">
                      <span>Vuelve a</span>
                      <select bind:value={cuentaElegida}>
                        {#each pagables as a}<option value={a.id}>{a.name}</option>{/each}
                      </select>
                    </label>
                  </div>
                  {#if interesDelVencimiento !== null}
                    <p class="sm">
                      Interés:
                      <b class="money" class:pos={interesDelVencimiento > 0}
                                       class:neg={interesDelVencimiento < 0}>
                        {money(interesDelVencimiento, i.currency)}
                      </b>
                    </p>
                  {/if}
                  <button class="btn-primary" onclick={() => vencer(i)}
                          disabled={busy || !montoRaw || !cuentaElegida}>
                    {busy ? 'Registrando…' : 'Registrar el vencimiento'}
                  </button>
                </div>
              {:else if abierto === i.id}
                <div class="panel stack">
                  <div class="row campos">
                    <label class="campo">
                      <span>Importe</span>
                      <input class="monto" inputmode="decimal" bind:value={montoRaw}
                             placeholder={i.amount ? '' : 'cuánto vino'} />
                    </label>
                    <label class="campo">
                      <span>Se paga con</span>
                      <select bind:value={cuentaElegida}>
                        {#each pagables as a}<option value={a.id}>{a.name}</option>{/each}
                      </select>
                    </label>
                  </div>
                  <p class="dim sm nota">
                    Se registra con fecha {shortDate(i.next_on)} y la regla pasa al período siguiente.
                  </p>
                  <button class="btn-primary" onclick={() => registrar(i)} disabled={busy || !montoRaw || !cuentaElegida}>
                    {busy ? 'Registrando…' : 'Registrar el pago'}
                  </button>
                  <!-- Cambiar la regla, que hasta ahora no se podía: el alta de
                       un gasto fijo decía «lo podés cambiar en Agenda» y acá solo
                       se podía registrar, saltear o archivar. Una promesa que la
                       pantalla no cumplía. -->
                  <details class="cambiar">
                    <summary>Cambiar la regla</summary>
                    <div class="row campos">
                      <label class="campo">
                        <span>Próxima vez</span>
                        <input type="date" bind:value={nuevaFecha} />
                      </label>
                      <label class="campo">
                        <span>Importe fijo</span>
                        <input class="monto" inputmode="decimal" bind:value={nuevoMonto}
                               placeholder="dejalo vacío si cambia" />
                      </label>
                    </div>
                    <button class="btn-primary chico" disabled={busy}
                            onclick={() => guardarRegla(i)}>Guardar los cambios</button>
                  </details>

                  <div class="finales">
                    <button onclick={() => saltear(i)} disabled={busy}>Saltear este período</button>
                    <button class="peligro" onclick={() => archivar(i)} disabled={busy}>Archivar</button>
                  </div>
                </div>
              {/if}
            </li>
          {/each}
        </ul>
      {/if}
    {/each}

    {#if masAdelante.length}
      <section class="card adelante">
        <button class="cabecera" onclick={() => (verMasAdelante = !verMasAdelante)}>
          <span>Más adelante</span>
          <span class="dim sm">
            {masAdelante.length} {masAdelante.length === 1 ? 'pendiente' : 'pendientes'}
            <span class="flecha" class:abierta={verMasAdelante}>▾</span>
          </span>
        </button>
        {#if verMasAdelante}
          <ul class="lejos">
            {#each masAdelante as i}
              <li class="spread">
                <span class="txt">
                  <b>{i.description}</b>
                  <span class="dim sm">{shortDate(i.next_on)} · {nombreFrecuencia(i.frequency)}</span>
                </span>
                {#if i.amount}<b class="money">{money(i.amount, i.currency)}</b>{/if}
              </li>
            {/each}
          </ul>
          <p class="dim sm">
            Se registran cuando llegue el mes. Acá están solo para que sepas que existen.
          </p>
        {/if}
      </section>
    {/if}

    {#if !items.length}
      <Vacio titulo="Todavía no cargaste nada que se repita."
             detalle="Sirve para que la app te anticipe el alquiler, los impuestos, los seguros y las suscripciones."
             href="/nuevo?repite=1" accion="Cargar el primero" />
    {/if}

    <a class="btn-primary nueva" href="/nuevo?repite=1">+ Nuevo gasto fijo</a>
  {/if}
</div>

<style>

  .sm { font-size: .78rem; }
  .lbl { font-size: .72rem; text-transform: uppercase; letter-spacing: .06em; color: var(--text-dim); margin: .4rem 0 -.1rem; }

  .proyeccion { margin: 0; font-size: .9rem; }

  .list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .4rem; }
  /* Solo los renglones de la lista van sin relleno, para que el panel llegue al
     borde. Sin acotarlo, alcanzaba también al <form class="card"> y el
     formulario quedaba pegado a los bordes de su tarjeta. */
  .list > li.card { padding: 0; overflow: hidden; }
  /* Lo vencido se marca con el borde, no con el fondo: el fondo rojo sobre una
     lista entera grita, y esto puede ser rutina. */
  .card.alerta { border-color: color-mix(in srgb, var(--neg) 55%, transparent); }

  .fila {
    display: flex; align-items: center; justify-content: space-between; gap: .7rem;
    width: 100%; border: none; background: none; text-align: left;
    padding: .7rem .85rem; min-height: 58px;
  }
  .txt { display: flex; flex-direction: column; min-width: 0; gap: .12rem; }
  .txt b { font-size: .95rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sub { font-size: .74rem; display: flex; align-items: center; gap: .3rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sep { opacity: .5; }
  .punto { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; }

  .der { display: flex; flex-direction: column; align-items: flex-end; gap: .12rem; flex-shrink: 0; }
  .der b { font-size: .95rem; white-space: nowrap; }
  .cuando { font-size: .72rem; color: var(--text-dim); white-space: nowrap; }
  .cuando.venc { color: var(--neg); font-weight: 600; }

  .panel { padding: .8rem; background: var(--surface-2); }
  .panel p { margin: 0; }
  .nota { margin-top: -.2rem; }
  .campos { gap: .5rem; align-items: flex-end; }
  .campos > .campo { flex: 1; }
  .finales { display: flex; gap: .5rem; }
  .finales button { flex: 1; min-height: 42px; font-size: .85rem; }
  .peligro { color: var(--neg); background: none; border-color: color-mix(in srgb, var(--neg) 35%, transparent); }

  .monto { text-align: right; }
  /* el botón de cancelar no es un campo: que no pretenda serlo */

  .nueva { width: 100%; }
  h2 { font-size: .95rem; }
  .adelante { padding: 0; }
  .adelante .cabecera {
    width: 100%; display: flex; justify-content: space-between; align-items: center;
    background: none; border: none; padding: .8rem .85rem; color: inherit;
    font-size: .9rem; font-weight: 600; min-height: var(--tap);
  }
  .adelante .flecha { display: inline-block; transition: transform .15s; margin-left: .3rem; }
  .adelante .flecha.abierta { transform: rotate(180deg); }
  .adelante .lejos { list-style: none; margin: 0; padding: 0 .85rem; display: grid; gap: .45rem; }
  .adelante > p { padding: .5rem .85rem .8rem; margin: 0; }
  /* Su propia caja, con su propio espaciado.
     Estaba suelto dentro del panel: `details` no hereda el `gap` del `.stack`,
     asi que los campos quedaban pegados al resumen y al boton, y se leia como
     si la tarjeta no tuviera padding. */
  .cambiar {
    border: 1px solid var(--border); border-radius: 10px;
    padding: .55rem .7rem; background: var(--surface);
  }
  .cambiar summary {
    font-size: .82rem; cursor: pointer; font-weight: 600;
    list-style: none; display: flex; align-items: center; gap: .35rem;
  }
  .cambiar summary::after { content: '▾'; opacity: .5; font-size: .8em; }
  .cambiar[open] summary::after { content: '▴'; }
  .cambiar[open] summary { margin-bottom: .6rem; }
  .cambiar .campos { margin-bottom: .6rem; }
</style>
