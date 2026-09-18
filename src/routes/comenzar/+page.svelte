<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { listAccounts, listCategories, createAccount, createCategory } from '$lib/ledger/api';
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

  // Las cuatro que tiene casi todo el mundo, ya armadas. Un toque, no un
  // formulario: el que quiere una cuenta rara la agrega abajo con su nombre.
  const SUGERIDAS = [
    { id: 'efectivo', name: 'Efectivo',   kind: 'asset'     as const, unit: 'ARS', spend: true,  pista: 'lo que tenés en la billetera' },
    { id: 'banco',    name: 'Banco',      kind: 'asset'     as const, unit: 'ARS', spend: true,  pista: 'caja de ahorro, cuenta sueldo' },
    { id: 'billetera',name: 'Mercado Pago', kind: 'asset'   as const, unit: 'ARS', spend: true,  pista: 'o cualquier billetera virtual' },
    { id: 'tarjeta',  name: 'Tarjeta',    kind: 'liability' as const, unit: 'ARS', spend: false, pista: 'lo que gastás y pagás después' },
    { id: 'dolares',  name: 'Dólares',    kind: 'asset'     as const, unit: 'USD', spend: true,  pista: 'los que tenés guardados' }
  ];

  // Sugerencias de categorías: se TILDAN, no vienen creadas. Lo que no elegís no
  // existe, que es justo lo que estaba mal antes.
  const GASTOS: Record<string, string[]> = {
    'Gastos fijos': ['Alquiler', 'Servicios', 'Internet y celular', 'Seguros', 'Impuestos', 'Suscripciones'],
    'Gastos variables': ['Supermercado', 'Transporte', 'Salidas', 'Salud', 'Ropa', 'Regalos']
  };

  let paso = $state<1 | 2>(1);
  let elegidas = $state<Set<string>>(new Set(['efectivo']));
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
        await createAccount({
          name: s.name, kind: s.kind, unit: s.unit,
          is_spendable: s.spend, institution: null, fx_source: null
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
            <b>{s.name}</b>
            <span class="dim sm">{s.pista}</span>
          </button>
        {/each}
      </div>

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
