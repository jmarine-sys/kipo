<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { listAccounts, listCategories, createAccount, createCategory } from '$lib/ledger/api';
  import { tipoPorId } from '$lib/ledger/tipos';
  import type { Category } from '$lib/types';

  /**
   * La puesta en marcha — ADR-027.
   *
   * Existe porque la app se le dio a usar a alguien que no la había construido y
   * se perdió. El alta le dejaba 20 categorías elegidas por otro y una cuenta que
   * no pidió, y ninguna pantalla le decía por dónde empezar.
   *
   * Lo que se hace al principio es exactamente esto: decir dónde tenés la plata y
   * en qué se te va. Antes eso estaba implícito en un formulario de alta de
   * cuentas al que había que llegar sabiendo que existía.
   */

  /**
   * Las cuentas que se ofrecen, y por que cada una dice TIPO y no nombre.
   *
   * Antes decia «Efectivo», «Banco», «Mercado Pago», «Tarjeta», «Dolares». De
   * esas, solo dos eran tipos: «Banco» es el DONDE y «Mercado Pago» una
   * institucion. Una caja de ahorro sigue siendo una caja de ahorro este en el
   * banco que este, y mezclar las tres preguntas hacia que no se entendiera cual
   * se estaba contestando.
   *
   * Ahora cada fila trae su tipo real, un nombre sugerido que se puede cambiar y
   * un lugar para decir donde esta.
   */
  const SUGERIDAS = [
    { id: 'efectivo',  tipo: 'vista'     as const, name: 'Efectivo',       unit: 'ARS', banco: '',              pista: 'lo que tenés en la billetera' },
    { id: 'caja',      tipo: 'vista'     as const, name: 'Caja de ahorro', unit: 'ARS', banco: '',              pista: 'la del sueldo, en un banco' },
    { id: 'billetera', tipo: 'vista'     as const, name: 'Mercado Pago',   unit: 'ARS', banco: 'Mercado Pago',  pista: 'también es una cuenta a la vista' },
    { id: 'tarjeta',   tipo: 'tarjeta'   as const, name: 'Tarjeta',        unit: 'ARS', banco: '',              pista: 'gastás ahora, pagás después' },
    { id: 'dolares',   tipo: 'vista'     as const, name: 'Dólares',        unit: 'USD', banco: '',              pista: 'los que tenés guardados' },
    { id: 'broker',    tipo: 'comitente' as const, name: 'Balanz',         unit: 'ARS', banco: '',              pista: 'el efectivo que tenés en un broker' }
  ];

  // Sugerencias de categorías: se TILDAN, no vienen creadas. Lo que no elegís no
  // existe, que es justo lo que estaba mal antes.
  const GASTOS: Record<string, string[]> = {
    'Gastos fijos': ['Alquiler', 'Servicios', 'Internet y celular', 'Seguros', 'Impuestos', 'Suscripciones'],
    'Gastos variables': ['Supermercado', 'Transporte', 'Salidas', 'Salud', 'Ropa', 'Regalos']
  };

  let paso = $state<1 | 2>(1);
  let elegidas = $state<Set<string>>(new Set(['efectivo']));

  /** Nombre y banco de cada una, editables. La sugerencia es un punto de partida. */
  let detalle = $state<Record<string, { name: string; banco: string }>>(
    Object.fromEntries(SUGERIDAS.map((s) => [s.id, { name: s.name, banco: s.banco }]))
  );
  let otra = $state('');
  let propias = $state<string[]>([]);
  let cats = $state<Set<string>>(new Set());
  let madres = $state<Category[]>([]);
  let busy = $state(false);
  let error = $state<string | null>(null);

  const hayCuenta = $derived(elegidas.size > 0 || propias.length > 0);

  function alternar(conjunto: Set<string>, id: string) {
    const s = new Set(conjunto);
    s.has(id) ? s.delete(id) : s.add(id);
    return s;
  }

  function agregarPropia() {
    const n = otra.trim();
    if (!n || propias.includes(n)) return;
    propias = [...propias, n];
    otra = '';
  }

  async function crearCuentas() {
    if (!hayCuenta) return;
    busy = true; error = null;
    try {
      for (const s of SUGERIDAS) {
        if (!elegidas.has(s.id)) continue;
        const t = tipoPorId(s.tipo);
        const d = detalle[s.id];
        await createAccount({
          name: d.name.trim() || s.name,
          kind: t.kind,
          unit: s.unit,
          is_spendable: t.spendable,
          institution: d.banco.trim() || null,
          fx_source: null
        });
      }
      for (const n of propias) {
        await createAccount({
          name: n, kind: 'asset', unit: 'ARS',
          is_spendable: true, institution: null, fx_source: null
        });
      }
      madres = (await listCategories()).filter((c) => !c.parent_id && c.kind === 'expense');
      paso = 2;
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudieron crear las cuentas';
    } finally { busy = false; }
  }

  async function crearCategorias() {
    busy = true; error = null;
    try {
      for (const clave of cats) {
        const [grupo, nombre] = clave.split('::');
        const madre = madres.find((m) => m.name === grupo);
        if (!madre) continue;
        await createCategory({ name: nombre, kind: 'expense', parent_id: madre.id });
      }
      goto('/');
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudieron crear las categorías';
    } finally { busy = false; }
  }

  // Si ya tiene cuentas no hay nada que poner en marcha: es alguien que llegó acá
  // de vuelta, y dejarlo creando cuentas repetidas sería peor que sacarlo.
  onMount(async () => {
    try {
      if ((await listAccounts()).length) goto('/');
    } catch { /* si falla, que igual pueda configurar */ }
  });
</script>

<div class="page stack">
  <header class="cab">
    <h1>Bienvenido a kipo</h1>
    <p class="dim">
      Dos preguntas y listo. Podés cambiar todo después.
    </p>
    <div class="pasos" aria-hidden="true">
      <span class="punto" class:on={true}></span>
      <span class="punto" class:on={paso === 2}></span>
    </div>
  </header>

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  {#if paso === 1}
    <section class="card stack">
      <h2>1. ¿Dónde tenés tu plata?</h2>
      <p class="dim sm">
        Cada gasto sale de algún lado y cada ingreso entra en algún lado. Eso es una
        <b>cuenta</b> — no la cuenta con la que entraste acá.
      </p>

      <div class="opciones">
        {#each SUGERIDAS as s}
          <button type="button" class="opcion" class:on={elegidas.has(s.id)}
                  onclick={() => (elegidas = alternar(elegidas, s.id))}>
            <b>{tipoPorId(s.tipo).label}</b>
            <span class="dim sm">{s.pista}</span>
          </button>
        {/each}
      </div>

      <!-- Tres preguntas separadas: qué tipo es (arriba), cómo la llamás y dónde
           está. Antes eran una sola y no se sabía cuál se estaba contestando. -->
      {#if elegidas.size}
        <ul class="detalles">
          {#each SUGERIDAS.filter((s) => elegidas.has(s.id)) as s (s.id)}
            <li>
              <span class="quees dim sm">{tipoPorId(s.tipo).label} · {s.unit}</span>
              <span class="row">
                <input bind:value={detalle[s.id].name} placeholder="Cómo la llamás" />
                <input bind:value={detalle[s.id].banco} list="bancos-nuevos"
                       placeholder="¿Dónde está?" />
              </span>
            </li>
          {/each}
        </ul>
        <datalist id="bancos-nuevos">
          {#each ['Mercado Pago', 'Balanz', 'Binance', 'Santander', 'Galicia', 'Macro', 'Nación', 'BBVA'] as b}
            <option value={b}></option>
          {/each}
        </datalist>
        <p class="dim sm">
          El <b>dónde</b> es opcional, y es lo que después te deja ver juntas todas
          las cuentas de un mismo banco.
        </p>
      {/if}

      {#if propias.length}
        <div class="propias">
          {#each propias as n}
            <button type="button" class="chip on"
                    onclick={() => (propias = propias.filter((x) => x !== n))}>
              {n} <span class="quitar" aria-hidden="true">×</span>
            </button>
          {/each}
        </div>
      {/if}

      <label class="campo">
        <span>¿Tenés otra? Ponele el nombre que usás vos</span>
        <span class="row">
          <input bind:value={otra} placeholder="Caja de ahorro Nación"
                 onkeydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); agregarPropia(); } }} />
          <button type="button" class="chico" onclick={agregarPropia} disabled={!otra.trim()}>Agregar</button>
        </span>
      </label>

      <button class="btn-primary grande" onclick={crearCuentas} disabled={busy || !hayCuenta}>
        {busy ? 'Creando…' : 'Continuar'}
      </button>
      {#if !hayCuenta}
        <p class="dim sm nota">Elegí al menos una para seguir.</p>
      {/if}
    </section>
  {:else}
    <section class="card stack">
      <h2>2. ¿En qué se te va?</h2>
      <p class="dim sm">
        Estas son sugerencias: <b>se crean solo las que marques</b>. kipo ya separa
        los gastos fijos de los variables, así que podés saltear esto y agregarlas
        sobre la marcha.
      </p>

      {#each Object.entries(GASTOS) as [grupo, hijas]}
        <div class="grupo">
          <h3>{grupo}</h3>
          <div class="wrap">
            {#each hijas as h}
              <button type="button" class="chip" class:on={cats.has(`${grupo}::${h}`)}
                      onclick={() => (cats = alternar(cats, `${grupo}::${h}`))}>{h}</button>
            {/each}
          </div>
        </div>
      {/each}

      <button class="btn-primary grande" onclick={crearCategorias} disabled={busy}>
        {busy ? 'Creando…' : cats.size ? `Crear ${cats.size} y empezar` : 'Empezar'}
      </button>
    </section>
  {/if}
</div>

<style>
  .cab { text-align: center; padding: .5rem 0 .2rem; }
  .cab h1 { font-size: 1.3rem; margin: 0 0 .3rem; }
  .cab p { margin: 0; font-size: .88rem; }
  .pasos { display: flex; gap: .4rem; justify-content: center; margin-top: .8rem; }
  .pasos .punto {
    width: 7px; height: 7px; border-radius: 50%; background: var(--border);
  }
  .pasos .punto.on { background: var(--accent); }

  h2 { font-size: 1.02rem; margin: 0; }
  h3 { font-size: .82rem; margin: 0 0 .4rem; color: var(--text-dim); }
  .grupo { margin-bottom: .2rem; }

  .opciones { display: grid; gap: .5rem; grid-template-columns: 1fr 1fr; }
  .opcion {
    display: flex; flex-direction: column; align-items: flex-start; gap: .1rem;
    padding: .7rem .8rem; min-height: var(--tap); text-align: left;
  }
  .opcion.on { border-color: var(--accent); background: color-mix(in srgb, var(--accent) 12%, var(--surface)); }

  .detalles { list-style: none; margin: 0; padding: 0; display: grid; gap: .55rem; }
  .detalles li { display: flex; flex-direction: column; gap: .2rem; }
  .detalles .quees { padding-left: .1rem; }
  .detalles .row { display: flex; gap: .4rem; }
  .detalles .row input { flex: 1; min-width: 0; }

  .wrap, .propias { display: flex; flex-wrap: wrap; gap: .4rem; }
  .chip {
    min-height: 40px; padding: 0 .8rem; border-radius: 999px; font-size: .86rem;
    display: inline-flex; align-items: center; gap: .35rem;
  }
  .chip.on { background: var(--accent); color: var(--accent-fg); border-color: transparent; font-weight: 600; }
  .quitar { opacity: .7; }

  .campo { display: flex; flex-direction: column; gap: .3rem; }
  .campo > span:first-child { font-size: .78rem; color: var(--text-dim); }
  .row { display: flex; gap: .4rem; }
  .row input { flex: 1; }

  .btn-primary.grande { padding: .85rem; border-radius: 12px; font-size: .95rem; }
  .sm { font-size: .78rem; }
  .nota { text-align: center; margin: 0; }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    padding: .6rem .8rem; border-radius: 10px; margin: 0;
  }
</style>
