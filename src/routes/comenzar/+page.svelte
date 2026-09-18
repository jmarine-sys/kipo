<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { listAccounts, listCategories, createCategory } from '$lib/ledger/api';
  import FormularioCuenta from '$lib/FormularioCuenta.svelte';
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

  // Sugerencias de categorías: se TILDAN, no vienen creadas. Lo que no elegís no
  // existe, que es justo lo que estaba mal antes.
  const GASTOS: Record<string, string[]> = {
    'Gastos fijos': ['Alquiler', 'Servicios', 'Internet y celular', 'Seguros', 'Impuestos', 'Suscripciones'],
    'Gastos variables': ['Supermercado', 'Transporte', 'Salidas', 'Salud', 'Ropa', 'Regalos']
  };

  let paso = $state<1 | 2>(1);
  let creadas = $state<string[]>([]);

  async function seguir() {
    busy = true; error = null;
    try {
      madres = (await listCategories()).filter((c) => !c.parent_id && c.kind === 'expense');
      paso = 2;
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudieron leer las categorías';
    } finally { busy = false; }
  }
  let cats = $state<Set<string>>(new Set());
  let madres = $state<Category[]>([]);
  let busy = $state(false);
  let error = $state<string | null>(null);

  function alternar(conjunto: Set<string>, id: string) {
    const s = new Set(conjunto);
    s.has(id) ? s.delete(id) : s.add(id);
    return s;
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

      {#if creadas.length}
        <ul class="creadas">
          {#each creadas as c}<li>✓ {c}</li>{/each}
        </ul>
      {/if}

      <!-- El MISMO formulario que /cuentas/nueva. Antes la puesta en marcha
           tenía el suyo, con fichas que decían «Banco» y «Mercado Pago» —el
           nombre y la institución disfrazados de tipo— y sin dejar elegir moneda
           ni cotización. Dos formularios para lo mismo, y este era el peor. -->
      <FormularioCuenta
        accion={creadas.length ? 'Agregar otra' : 'Agregar'}
        onlisto={(n) => (creadas = [...creadas, n])} />
    </section>

    <button class="btn-primary grande" onclick={seguir} disabled={!creadas.length}>
      {creadas.length ? 'Listo, seguir' : 'Agregá al menos una'}
    </button>
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

  .creadas { list-style: none; margin: 0; padding: 0; display: grid; gap: .2rem; font-size: .86rem; }
  .creadas li { color: var(--pos); }


  .wrap { display: flex; flex-wrap: wrap; gap: .4rem; }
  .chip {
    min-height: 40px; padding: 0 .8rem; border-radius: 999px; font-size: .86rem;
    display: inline-flex; align-items: center; gap: .35rem;
  }
  .chip.on { background: var(--accent); color: var(--accent-fg); border-color: transparent; font-weight: 600; }


  .btn-primary.grande { padding: .85rem; border-radius: 12px; font-size: .95rem; }
  .sm { font-size: .78rem; }
</style>
