<script lang="ts">
  import { onMount } from 'svelte';
  import { createAccount, listAccounts } from '$lib/ledger/api';
  import { TIPOS_CUENTA, tipoPorId } from '$lib/ledger/tipos';
  import { FUENTES_DOLAR, dolarSugerido } from '$lib/ledger/dolares';

  /**
   * El formulario de alta de una cuenta — uno solo, para las dos pantallas.
   *
   * La puesta en marcha tenía el suyo propio, con fichas que decían «Efectivo»,
   * «Banco», «Mercado Pago». Eran dos formularios para lo mismo, y el de la
   * puesta en marcha era el peor de los dos: mezclaba el tipo con el nombre y no
   * dejaba elegir la moneda ni la cotización.
   *
   * Es la quinta vez en este proyecto que algo definido dos veces deja de
   * coincidir. Ahora hay uno, y quien lo use decide qué pasa después.
   */
  let {
    accion = 'Crear cuenta',
    onlisto = null
  }: {
    accion?: string;
    /** Qué hacer cuando se creó. Si no se pasa nada, el formulario solo se limpia. */
    onlisto?: ((nombre: string) => void) | null;
  } = $props();

  let name = $state('');
  let tipoId = $state<'vista' | 'comitente' | 'tarjeta'>('vista');
  let unit = $state('ARS');
  let institution = $state('');
  let fxSource = $state('');
  let busy = $state(false);
  let error = $state<string | null>(null);
  let bancos = $state<string[]>([]);

  const tipo = $derived(tipoPorId(tipoId));

  // El nombre es LIBRE y el tipo no lo condiciona: una caja de ahorro se puede
  // llamar «Banco», «Macro» o «la del sueldo». Lo que no puede es que el nombre
  // decida cómo se la trata.
  $effect(() => { if (!tipo.monedas.includes(unit)) unit = tipo.monedas[0]; });

  /**
   * La sugerencia de dólar sigue al tipo y a la moneda hasta que la tocás.
   *
   * Sin `tocada` la sugerencia pisaría tu elección cada vez que cambiás de
   * moneda, que es el modo de falla clásico de un campo autocompletado: parece
   * que no responde.
   */
  let tocada = $state(false);
  $effect(() => {
    const s = dolarSugerido(tipoId, unit);
    if (!tocada) fxSource = s ?? '';
  });

  async function cargarBancos() {
    try {
      const cuentas = await listAccounts();
      bancos = [...new Set(cuentas.map((a) => a.institution?.trim()).filter(Boolean) as string[])].sort();
    } catch { /* la sugerencia es un lujo: si falla, se escribe a mano */ }
  }

  onMount(cargarBancos);

  async function save(e: SubmitEvent) {
    e.preventDefault();
    busy = true; error = null;
    try {
      const creada = name.trim();
      await createAccount({
        name: creada,
        kind: tipo.kind,
        unit,
        is_spendable: tipo.spendable,
        institution: institution.trim() || null,
        fx_source: fxSource || null
      });
      name = ''; institution = ''; fxSource = '';
      await cargarBancos();
      onlisto?.(creada);
    } catch (err) {
      error = err instanceof Error ? err.message : 'No se pudo crear';
    } finally {
      busy = false;
    }
  }
</script>

{#if error}<p class="err" role="alert">{error}</p>{/if}

<form class="stack" onsubmit={save}>
  <label><span class="dim">Nombre</span>
    <!-- Limitado en el ORIGEN además de recortado en pantalla: recortar evita que
         la fila se rompa, pero un nombre que nunca se ve entero tampoco sirve. -->
    <input bind:value={name} required maxlength="36"
           placeholder="Caja de ahorro Santander" />
    {#if name.length > 28}
      <span class="dim sm">{36 - name.length} caracteres. Los nombres cortos se leen mejor en la lista.</span>
    {/if}
  </label>

  <fieldset>
    <legend class="dim">Qué tipo de cuenta es</legend>
    <div class="opts">
      {#each TIPOS_CUENTA as t}
        <button type="button" class:on={tipoId === t.id} onclick={() => (tipoId = t.id)}>
          {t.label}
          <span class="dim sm">{t.pista}</span>
        </button>
      {/each}
    </div>
  </fieldset>

  <fieldset>
    <legend class="dim">Moneda</legend>
    <div class="opts row3">
      {#each tipo.monedas as u}
        <button type="button" class:on={unit === u} onclick={() => (unit = u)}>{u}</button>
      {/each}
    </div>
  </fieldset>

  <!-- ADR-011: la fuente es propiedad de la CUENTA. Se preguntaba SOLO si la
       moneda era USD, donde casi no decide nada —medido en dólares, un dólar es
       un dólar; la fuente ahí solo pesa al medir en UVAs— y NO se preguntaba en
       las cuentas en pesos, que es donde decide todo (OD-59).

       Es además lo que hace innecesario recuperar «efectivo» como tipo: un fajo
       de pesos y una caja de ahorro se valúan y se gastan igual, y en lo único
       que se distinguen es en qué dólar conseguís con ellos. Eso es este campo. -->
  <fieldset>
    <legend class="dim">
      {unit === 'ARS' ? 'Con qué dólar se miden estos pesos' : 'Con qué dólar se pasan a pesos'}
    </legend>
    <div class="opts">
      <button type="button" class:on={fxSource === ''}
              onclick={() => { tocada = true; fxSource = ''; }}>
        El del libro
        <span class="dim sm">se cambia una vez en Ajustes</span>
      </button>
      {#each FUENTES_DOLAR as f}
        <button type="button" class:on={fxSource === f.id}
                onclick={() => { tocada = true; fxSource = f.id; }}>
          {f.label}
          <span class="dim sm">{f.pista}</span>
        </button>
      {/each}
    </div>
    <p class="dim sm pie">
      {#if unit === 'ARS'}
        Es el dólar que <b>realmente conseguirías</b> con esta plata: los pesos del
        banco no se realizan igual que los de la mano.
      {:else}
        Un dólar es un dólar al medir en dólares. Esto pesa cuando kipo compara tu
        patrimonio contra la <b>inflación</b>, que se mide en pesos.
      {/if}
    </p>
  </fieldset>

  <!-- Sugiere los bancos que ya usaste: «Macro» y «macro» serían dos grupos
       distintos en la pantalla de cuentas, y nadie se daría cuenta. -->
  <label><span class="dim">Dónde está (opcional)</span>
    <input bind:value={institution} list="bancos-form"
           placeholder="Santander, Balanz, Binance…" />
    <datalist id="bancos-form">
      {#each bancos as b}<option value={b}></option>{/each}
    </datalist>
    {#if bancos.length}
      <span class="dim sm">
        Si es de un banco que ya cargaste, elegilo de la lista: así quedan agrupadas.
      </span>
    {/if}
  </label>

  <button class="btn-primary" type="submit" disabled={busy || !name.trim()}>
    {busy ? 'Creando…' : accion}
  </button>
</form>

<style>
  label:not(.casilla) { display: flex; flex-direction: column; gap: .3rem; }
  label > span:first-child { font-size: .78rem; color: var(--text-dim); }
  fieldset { border: none; padding: 0; margin: 0; }
  legend { font-size: .85rem; margin-bottom: .35rem; }
  .sm { font-size: .76rem; }
  .pie { margin: .45rem 0 0; }
</style>
