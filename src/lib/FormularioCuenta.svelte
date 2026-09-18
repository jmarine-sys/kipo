<script lang="ts">
  import { onMount } from 'svelte';
  import { createAccount, listAccounts } from '$lib/ledger/api';
  import { TIPOS_CUENTA, tipoPorId } from '$lib/ledger/tipos';

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

  {#if unit === 'USD'}
    <!-- ADR-011: la fuente de cotización es propiedad de la CUENTA.
         Los dólares comprados en blue se valúan con blue; los del broker con MEP. -->
    <fieldset>
      <legend class="dim">Con qué cotización se valúa</legend>
      <div class="opts row3">
        {#each [['', 'La de siempre'], ['blue', 'Blue'], ['mep', 'MEP'], ['ccl', 'CCL'], ['oficial', 'Oficial']] as [v, l]}
          <button type="button" class:on={fxSource === v} onclick={() => (fxSource = v)}>{l}</button>
        {/each}
      </div>
    </fieldset>
  {/if}

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
  .opts { display: grid; gap: .5rem; }
  .opts.row3 { grid-template-columns: repeat(auto-fit, minmax(90px, 1fr)); }
  .opts button {
    display: flex; flex-direction: column; align-items: flex-start; gap: .15rem;
    padding: .7rem .85rem; min-height: var(--tap); text-align: left;
  }
  .opts.row3 button { align-items: center; justify-content: center; }
  .opts button.on { border-color: var(--accent); background: color-mix(in srgb, var(--accent) 12%, var(--surface)); }
  .sm { font-size: .76rem; }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius);
  }
</style>
